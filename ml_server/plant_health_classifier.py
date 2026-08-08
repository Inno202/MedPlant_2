# ml_server/plant_health_classifier.py
#
# F2 — Leaf Health Classifier (BINARY): Healthy / Stressed
#      Visual cues (discolouration, browning, wilting, lesions, stem
#      irregularity) are supporting EVIDENCE for a Stressed call — they are
#      surfaced by main.py only when health_status == Stressed, and are not
#      a separate ML function or output class.
#
# F3 — Trend & Monitoring: takes the F2 health_score for the current
#      submission plus prior scores for the same species, fits a simple
#      linear regression (slope), and classifies the trend as
#      Improving / Stable / Declining.
#
# These two functions live in the same module because F3 consumes F2's
# output directly, but they are two distinct pipeline stages:
#   F2 = single-image classification
#   F3 = longitudinal trend across a species' submission history

import cv2
import numpy as np
from sklearn.ensemble import RandomForestClassifier

# ── F2 classes ────────────────────────────────────────────────────────────
HEALTHY = "Healthy"
STRESSED = "Stressed"

# ── F3 classes ────────────────────────────────────────────────────────────
IMPROVING = "Improving"
STABLE = "Stable"
DECLINING = "Declining"

# Environmental conditions known (from literature — Vukeya et al., 2024;
# general plant-stress physiology) to elevate stress likelihood for
# Lessertia frutescens.
ENV_MULTIPLIERS = {
    "Hot": 1.15,
    "Dry": 1.20,
    "Frost": 1.20,
    "Cold": 1.05,
    "Wet / After rain": 0.95,
    "Windy": 1.05,
    "Normal": 1.0,
}


class PlantHealthClassifier:
    """F2 (binary leaf health) + F3 (trend) — see module docstring."""

    def __init__(self):
        self.model: RandomForestClassifier | None = None
        self._is_trained = False

    # ── Feature extraction (shared by training + inference) ────────────
    def _extract_features(self, img: np.ndarray) -> np.ndarray:
        img = cv2.resize(img, (224, 224))
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        total_px = img.shape[0] * img.shape[1]

        green_r  = np.sum(cv2.inRange(hsv, (35, 40, 40), (85, 255, 255)) > 0) / total_px
        yellow_r = np.sum(cv2.inRange(hsv, (20, 40, 40), (35, 255, 255)) > 0) / total_px
        brown_r  = np.sum(cv2.inRange(hsv, (10, 30, 30), (20, 200, 150)) > 0) / total_px
        dark_r   = np.sum(gray < 40) / total_px

        edges = cv2.Canny(gray, 50, 150)
        edge_density = np.sum(edges > 0) / total_px
        blur_score = cv2.Laplacian(gray, cv2.CV_64F).var()

        h_mean, h_std = float(np.mean(hsv[:, :, 0])), float(np.std(hsv[:, :, 0]))
        s_mean, s_std = float(np.mean(hsv[:, :, 1])), float(np.std(hsv[:, :, 1]))
        v_mean, v_std = float(np.mean(hsv[:, :, 2])), float(np.std(hsv[:, :, 2]))

        return np.array([
            green_r, yellow_r, brown_r, dark_r,
            edge_density, min(blur_score / 1000.0, 1.0),
            h_mean / 180.0, h_std / 180.0,
            s_mean / 255.0, s_std / 255.0,
            v_mean / 255.0, v_std / 255.0,
        ], dtype=np.float32)

    # ── Training (synthetic, calibrated to the binary boundary) ─────────
    def train(self, n_samples: int = 600, random_state: int = 42) -> None:
        rng = np.random.default_rng(random_state)
        X, y = [], []
        for _ in range(n_samples):
            is_stressed = rng.random() > 0.5
            base = rng.uniform(0.45, 1.0) if is_stressed else rng.uniform(0.0, 0.40)
            synthetic = np.array([
                max(0.0, 1 - base + rng.normal(0, 0.05)),  # green_r
                base * rng.uniform(0.3, 0.7),                 # yellow_r
                base * rng.uniform(0.2, 0.6),                 # brown_r
                base * rng.uniform(0.1, 0.4),                 # dark_r
                rng.uniform(0.02, 0.15),                      # edge_density
                rng.uniform(0.0, 0.3),                        # blur/1000
                rng.uniform(0.15, 0.35),                      # h_mean
                rng.uniform(0.05, 0.25),                      # h_std
                rng.uniform(0.2, 0.7),                        # s_mean
                rng.uniform(0.05, 0.25),                      # s_std
                rng.uniform(0.3, 0.8),                        # v_mean
                rng.uniform(0.05, 0.25),                      # v_std
            ], dtype=np.float32)
            X.append(synthetic)
            y.append(1 if is_stressed else 0)

        self.model = RandomForestClassifier(
            n_estimators=200, max_depth=8, min_samples_split=4,
            class_weight="balanced", random_state=random_state, n_jobs=-1,
        )
        self.model.fit(np.array(X), np.array(y))
        self._is_trained = True

    # ── F2: Leaf Health (BINARY) ─────────────────────────────────────────
    def classify_leaf_health(
        self,
        img: np.ndarray,
        reported_severity: int = 1,
        environmental_condition: str = "Normal",
    ) -> dict:
        """
        Returns a binary Healthy/Stressed call.
        health_score is a continuous 0.0 (healthy) .. 1.0 (stressed) value
        used both for the classification threshold and as the raw input to
        F3's trend calculation.
        """
        if not self._is_trained:
            self.train()

        feats = self._extract_features(img).reshape(1, -1)
        proba = self.model.predict_proba(feats)[0]
        stressed_proba = float(proba[1]) if len(proba) > 1 else float(proba[0])

        env_mult = ENV_MULTIPLIERS.get(environmental_condition, 1.0)
        sev_int = max(1, min(5, int(reported_severity)))
        reported_component = (sev_int - 1) / 4.0

        # 60% RF probability, 40% observer-reported severity, scaled by
        # environmental multiplier (bounded to [0, 1]).
        blended = min(1.0, (stressed_proba * 0.6 + reported_component * 0.4) * env_mult)

        health_status = STRESSED if blended >= 0.45 else HEALTHY
        confidence = stressed_proba if health_status == STRESSED else (1 - stressed_proba)

        note = (
            f"Leaf health classified as {health_status.upper()} "
            f"({confidence:.0%} confidence, blended score {blended:.2f}/1.0)."
        )

        return {
            "health_status": health_status,
            "health_score": round(blended, 4),
            "confidence": round(confidence, 4),
            "prediction_note": note,
        }

    # ── F3: Trend & Monitoring ───────────────────────────────────────────
    def compute_trend(self, current_score: float, prior_scores_str: str = "") -> dict:
        """
        Linear-regression slope over [prior_scores..., current_score]
        (all in the same 0.0=healthy .. 1.0=stressed scale as F2's
        health_score) → Improving / Stable / Declining.
        Needs at least 3 data points to compute a slope; otherwise Stable.
        """
        prior_list: list[float] = []
        if prior_scores_str.strip():
            try:
                prior_list = [float(x) for x in prior_scores_str.split(",") if x.strip()]
            except ValueError:
                prior_list = []

        all_scores = prior_list + [current_score]
        prior_count = len(prior_list)

        if len(all_scores) >= 3:
            x = np.arange(len(all_scores))
            slope = float(np.polyfit(x, all_scores, 1)[0])
            if slope < -0.03:
                trend = IMPROVING
            elif slope > 0.03:
                trend = DECLINING
            else:
                trend = STABLE
        else:
            trend = STABLE

        return {
            "trend_direction": trend,
            "prior_report_count": prior_count,
        }