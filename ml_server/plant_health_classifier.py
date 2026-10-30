# ml_server/plant_health_classifier.py
#
# F2 - Leaf health (BINARY Healthy / Stressed): now uses the Random Forest trained
#      on real, manually labelled Lessertia frutescens images (see train_health.py),
#      loaded from results/lessertia_health_rf.joblib. Replaces the earlier model
#      that was trained on synthetic data.
#
# F3 - Trend: linear-regression slope over prior F2 scores + the current score
#      -> Improving / Stable / Declining. Unchanged.
#
# Design note: the validated model alone decides Healthy/Stressed (using the
# decision threshold tuned in cross-validation). The observer-reported severity
# and the environmental condition are NOT blended into the score, because that
# blend was never validated; they are still used elsewhere in main.py as context.

from pathlib import Path

import joblib
import numpy as np

from train_health import FEATURE_NAMES, extract_features

HEALTHY = "Healthy"
STRESSED = "Stressed"
IMPROVING = "Improving"
STABLE = "Stable"
DECLINING = "Declining"

MODEL_PATH = Path(__file__).resolve().parent / "results" / "lessertia_health_rf.joblib"


class PlantHealthClassifier:
    """F2 (binary leaf health, trained RF) + F3 (trend)."""

    def __init__(self):
        self.model = None
        self.threshold = 0.5
        self._idx = None
        self._is_trained = False

    def train(self, *args, **kwargs):
        """Kept so main.py's startup call still works: loads the trained model."""
        bundle = joblib.load(MODEL_PATH)
        self.model = bundle["model"]
        self.threshold = float(bundle["threshold"])
        self._idx = [FEATURE_NAMES.index(n) for n in bundle["feature_names"]]
        self._is_trained = True
        print(f"F2 model loaded: {len(self._idx)} features, threshold {self.threshold:.2f}")

    # -- F2 ----------------------------------------------------------------
    def classify_leaf_health(self, img: np.ndarray, reported_severity: int = 1,
                             environmental_condition: str = "Normal") -> dict:
        if not self._is_trained:
            self.train()

        feats = extract_features(img)[self._idx].reshape(1, -1)
        p_stressed = float(self.model.predict_proba(feats)[0][1])

        health_status = STRESSED if p_stressed >= self.threshold else HEALTHY
        confidence = p_stressed if health_status == STRESSED else 1 - p_stressed

        note = (f"Leaf health classified as {health_status.upper()} "
                f"(stress probability {p_stressed:.2f}, decision threshold {self.threshold:.2f}).")
        return {
            "health_status": health_status,
            "health_score": round(p_stressed, 4),     # 0 = healthy .. 1 = stressed; feeds F3
            "confidence": round(confidence, 4),
            "prediction_note": note,
        }

    # -- F3 ----------------------------------------------------------------
    def compute_trend(self, current_score: float, prior_scores_str: str = "") -> dict:
        prior_list = []
        if prior_scores_str.strip():
            try:
                prior_list = [float(x) for x in prior_scores_str.split(",") if x.strip()]
            except ValueError:
                prior_list = []

        all_scores = prior_list + [current_score]
        if len(all_scores) >= 3:
            slope = float(np.polyfit(np.arange(len(all_scores)), all_scores, 1)[0])
            trend = IMPROVING if slope < -0.03 else DECLINING if slope > 0.03 else STABLE
        else:
            trend = STABLE
        return {"trend_direction": trend, "prior_report_count": len(prior_list)}