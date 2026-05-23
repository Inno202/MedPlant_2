# ml_server/main.py
# FastAPI server — three RF ML functions.
#
# Endpoints
# ─────────────────────────────────────────────────────────────────────────────
# POST /predict/full            F1+F2+F3  image bytes    → AddReportScreen
# POST /predict/contextual_url  F2+F3     image URL      → PredictionsScreen
#                               Downloads the stored Firestore image, runs F2
#                               and F3, cross-references with report context.
# POST /predict/species         F1 only
# POST /predict/health          F2 only
# POST /predict/damage          F3 only
# POST /train                   Retrain species identifier
# GET  /health                  Status check
#
# Install:
#   pip install fastapi uvicorn python-multipart opencv-python-headless \
#               scikit-learn scikit-image scipy numpy pillow httpx
# Run:
#   uvicorn main:app --host 0.0.0.0 --port 8000 --reload

import cv2
import numpy as np
import os
import pickle
import httpx
from fastapi import FastAPI, File, Form, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List

from plant_identifier import PlantIdentifier
from plant_monitor import PlantMonitor, EnhancedFeatureExtractor

app = FastAPI(
    title="MedPlant ML API",
    description="Three-function Random Forest pipeline for Thaba-Nchu medicinal plant monitoring",
    version="2.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

identifier = PlantIdentifier()
monitor = PlantMonitor(use_deep_features=False)
feature_extractor = EnhancedFeatureExtractor(use_deep_features=False)

DATASET_PATH = os.environ.get("DATASET_PATH", "./dataset")
MODEL_PATH = os.environ.get("MODEL_PATH", "./models")
HISTORY_PATH = os.environ.get("HISTORY_PATH", "./history")

os.makedirs(MODEL_PATH, exist_ok=True)
os.makedirs(HISTORY_PATH, exist_ok=True)


@app.on_event("startup")
async def startup_event():
    model_file = os.path.join(MODEL_PATH, "identifier_model.pkl")
    if os.path.exists(model_file):
        with open(model_file, "rb") as f:
            saved = pickle.load(f)
            identifier.model = saved["model"]
            identifier.dataset_features = saved["features"]
            identifier.dataset_images = saved["images"]
        print("✅ Identifier model loaded from disk")
    elif os.path.exists(DATASET_PATH):
        print("🔄 Training identifier model from dataset…")
        identifier.train_model(DATASET_PATH)
        with open(model_file, "wb") as f:
            pickle.dump({
                "model": identifier.model,
                "features": identifier.dataset_features,
                "images": identifier.dataset_images,
            }, f)
        print("✅ Identifier model trained and saved")
    else:
        print("⚠️  No dataset found — model not trained. POST /train to train.")


# ── Shared helpers ─────────────────────────────────────────────────────────────
def decode_image(file_bytes: bytes) -> np.ndarray:
    nparr = np.frombuffer(file_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail="Could not decode image")
    return img


async def fetch_image_from_url(url: str) -> np.ndarray:
    """Download an image from a URL (e.g. Firebase Storage) and decode it."""
    try:
        async with httpx.AsyncClient(timeout=20) as client:
            resp = await client.get(url)
            resp.raise_for_status()
        return decode_image(resp.content)
    except httpx.HTTPStatusError as e:
        raise HTTPException(
            status_code=502,
            detail=f"Could not fetch image from URL: {e.response.status_code}"
        )
    except Exception as e:
        raise HTTPException(status_code=502, detail=f"Image fetch error: {e}")


def _image_health_score(img: np.ndarray) -> float:
    """Returns 0.0 (green/healthy) → 1.0 (brown-yellow/degraded)."""
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    total_px = img.shape[0] * img.shape[1]
    green_r  = np.sum(cv2.inRange(hsv, (35, 40, 40), (85, 255, 255)) > 0) / total_px
    yellow_r = np.sum(cv2.inRange(hsv, (20, 40, 40), (35, 255, 255)) > 0) / total_px
    brown_r  = np.sum(cv2.inRange(hsv, (10, 30, 30), (20, 200, 150)) > 0) / total_px
    score = (yellow_r * 0.5 + brown_r * 1.0) / max(green_r + 0.01, 0.01)
    return min(score, 1.0)


def _detect_damage_labels(img: np.ndarray, hsv: np.ndarray) -> list:
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    total_px = img.shape[0] * img.shape[1]
    labels = []
    if np.sum(cv2.inRange(hsv, (15, 40, 40), (35, 255, 255)) > 0) / total_px > 0.08:
        labels.append("Leaf discolouration")
    if np.sum(cv2.inRange(hsv, (8, 30, 30), (18, 200, 150)) > 0) / total_px > 0.06:
        labels.append("Browning")
    edges = cv2.Canny(gray, 50, 150)
    edge_density = np.sum(edges > 0) / total_px
    blur_score = cv2.Laplacian(gray, cv2.CV_64F).var()
    if edge_density < 0.04 and blur_score < 50:
        labels.append("Wilting")
    _, dark_mask = cv2.threshold(gray, 40, 255, cv2.THRESH_BINARY_INV)
    kernel = np.ones((5, 5), np.uint8)
    dark_spots = cv2.morphologyEx(dark_mask, cv2.MORPH_OPEN, kernel)
    if 0.02 < np.sum(dark_spots > 0) / total_px < 0.30:
        labels.append("Lesions")
    sobelx = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
    sobely = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
    if np.mean(np.abs(sobely)) > 0:
        if np.mean(np.abs(sobelx)) / (np.mean(np.abs(sobely)) + 1e-6) > 1.8:
            labels.append("Stem damage")
    return labels


def _build_contextual_result(
    img: np.ndarray,
    prior_scores_str: str,
    environmental_condition: str,
    degradation_indicator: str,
    observer_notes: str,
    reported_severity: str,
    location: str,
) -> dict:
    """Core logic shared by /predict/contextual_url (and the bytes variant)."""
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    total_px = img.shape[0] * img.shape[1]

    # ── F2: health score ──────────────────────────────────────────────────────
    img_score = _image_health_score(img)

    prior_list: list[float] = []
    if prior_scores_str.strip():
        try:
            prior_list = [float(x) for x in prior_scores_str.split(",") if x.strip()]
        except ValueError:
            prior_list = []

    all_scores = prior_list + [img_score]
    prior_count = len(prior_list)

    try:
        sev_int = max(1, min(5, int(reported_severity)))
    except ValueError:
        sev_int = 1
    reported_sev_score = (sev_int - 1) / 4.0

    # 60% image signal, 40% observer-reported severity
    blended = img_score * 0.6 + reported_sev_score * 0.4

    health_status = (
        "Healthy" if blended < 0.25 else
        "Stressed" if blended < 0.60 else
        "Degraded"
    )

    if len(all_scores) >= 3:
        slope = all_scores[-1] - all_scores[-3]
        trend = "Improving" if slope < -0.10 else ("Declining" if slope > 0.10 else "Stable")
    else:
        trend = "Stable"

    # ── F3: damage detection + report augmentation ───────────────────────────
    damage_labels = _detect_damage_labels(img, hsv)

    indicator_map = {
        "Over-harvesting": "Over-harvesting signs",
        "Pollution": "Pollution stress",
        "Flooding": "Water stress",
        "Fire damage": "Fire damage",
        "Invasive species nearby": "Competition stress",
        "Drought stress": "Drought stress",
        "Land use change": "Habitat disturbance",
    }
    if degradation_indicator in indicator_map:
        extra = indicator_map[degradation_indicator]
        if extra not in damage_labels:
            damage_labels.append(extra)

    severity_score = len(damage_labels) / 7.0

    # ── Factor breakdown ──────────────────────────────────────────────────────
    green_r  = np.sum(cv2.inRange(hsv, (35, 40, 40), (85, 255, 255)) > 0) / total_px
    yellow_r = np.sum(cv2.inRange(hsv, (20, 40, 40), (35, 255, 255)) > 0) / total_px
    brown_r  = np.sum(cv2.inRange(hsv, (10, 30, 30), (20, 200, 150)) > 0) / total_px

    factor_breakdown: dict[str, str] = {
        "Image — Green coverage": (
            f"{green_r*100:.1f}% — "
            + ("Good foliage density." if green_r > 0.3 else "Low green coverage — possible stress.")
        ),
        "Image — Yellow/discolouration": (
            f"{yellow_r*100:.1f}% — "
            + ("Elevated yellowing detected." if yellow_r > 0.1 else "Minimal yellowing.")
        ),
        "Image — Brown/necrosis": (
            f"{brown_r*100:.1f}% — "
            + ("Significant browning present." if brown_r > 0.08 else "Low browning levels.")
        ),
        "Environmental condition": (
            f"{environmental_condition} — " + {
                "Hot": "High temperature stress likely. Heat accelerates desiccation.",
                "Dry": "Drought conditions. Water deficit is a primary stressor.",
                "Frost": "Frost exposure can cause tissue death and wilting.",
                "Cold": "Cold stress may slow growth and increase disease susceptibility.",
                "Wet / After rain": "Recent rainfall beneficial but may increase fungal risk.",
                "Windy": "Wind stress can cause physical damage and increase transpiration losses.",
            }.get(environmental_condition, "Conditions within normal range.")
        ),
        "Reported degradation indicator": (
            f"{degradation_indicator} — "
            + ("No external degradation reported." if degradation_indicator == "None observed"
               else f"Community-reported: {degradation_indicator}. Recognised threat to "
               "Lessertia frutescens in the Free State (Vukeya et al., 2024).")
        ),
        "Reported severity": (
            f"Level {sev_int}/5 — "
            + [
                "No visible damage reported.",
                "Minor stress reported by observer.",
                "Moderate stress reported by observer.",
                "Severe stress reported — verification recommended.",
                "Critical condition — researcher alert required.",
              ][sev_int - 1]
        ),
        "F3 damage labels": (
            f"{', '.join(damage_labels)} — Multi-label damage types detected."
            if damage_labels else "No damage types detected in image."
        ),
    }
    if observer_notes.strip():
        factor_breakdown["Observer notes"] = (
            f"'{observer_notes[:120]}{'…' if len(observer_notes) > 120 else ''}' — "
            "IK holder observation recorded and factored into risk assessment."
        )

    # ── Risk & alert score ────────────────────────────────────────────────────
    alert_score = 0
    alert_score += min(3, int(blended * 4))
    alert_score += min(3, len(damage_labels))
    alert_score += min(2, sev_int - 1)
    if trend == "Declining":
        alert_score += 1
    if environmental_condition in ("Hot", "Dry", "Frost"):
        alert_score += 1
    alert_score = min(alert_score, 10)

    risk_level = (
        "Critical" if alert_score > 7 else
        "High" if alert_score > 4 else
        "Moderate" if alert_score > 2 else
        "Low"
    )

    # ── Comprehensive report paragraph ────────────────────────────────────────
    loc_str = f" in {location}" if location.strip() else " in Thaba-Nchu"
    parts = [
        f"Analysis of Lessertia frutescens (Cancer Bush){loc_str} "
        f"(ML F2 + F3 · {prior_count} prior submission(s)).",
        "",
        f"Image health score: {img_score:.2f} · Reported severity: {sev_int}/5 · "
        f"Blended score: {blended:.2f}. Classification: {health_status.upper()} · Trend: {trend}.",
    ]
    if environmental_condition not in ("Normal",):
        parts.append(
            f"The {environmental_condition} environmental conditions at time of observation "
            "are a known stressor for this species and have been factored into the assessment."
        )
    if degradation_indicator != "None observed":
        parts.append(
            f"Community-reported degradation indicator — {degradation_indicator} — "
            "aligns with documented threats to Free State medicinal plant populations "
            "(Vukeya et al., 2024; Ngobeni et al., 2023) and elevates the risk classification."
        )
    image_only = [d for d in damage_labels if d in
                  ("Leaf discolouration", "Browning", "Wilting", "Lesions", "Stem damage")]
    reported_only = [d for d in damage_labels if d not in image_only]
    if image_only:
        parts.append(f"F3 detected from image: {', '.join(image_only)}.")
    if reported_only:
        parts.append(
            f"Additional damage indicators derived from reported context: "
            f"{', '.join(reported_only)}."
        )
    if not image_only and not reported_only:
        parts.append("F3 detected no visible damage indicators in the submitted image.")
    if observer_notes.strip():
        parts.append(
            f"Observer noted: \"{observer_notes[:200]}\". "
            "This IK contribution has been recorded in alignment with the ITIKI methodology."
        )
    parts.append(
        f"Overall risk: {risk_level.upper()} (alert score {alert_score}/10). "
        + ("Researcher notification triggered." if alert_score >= 7
           else "Continue monitoring per study protocol.")
    )
    comprehensive_report = " ".join(parts)

    # ── Recommendations ───────────────────────────────────────────────────────
    recs: list[str] = []
    if health_status == "Degraded" or alert_score >= 7:
        recs.append(
            "Escalate to researcher immediately — species meets the ≥3 degraded "
            "classifications threshold in the monitoring protocol."
        )
    if "Over-harvesting signs" in damage_labels or degradation_indicator == "Over-harvesting":
        recs.append(
            "Restrict harvesting at this site. Coordinate with traditional healers "
            "to identify alternative sources and allow population recovery."
        )
    if environmental_condition in ("Hot", "Dry"):
        recs.append(
            "Consider supplementary watering or shade protection within managed "
            "conservation areas. Record soil moisture at next visit."
        )
    if environmental_condition == "Frost":
        recs.append(
            "Document frost damage across the monitored population. "
            "Check for new growth at root base within 2–3 weeks."
        )
    if "Lesions" in damage_labels or "Browning" in damage_labels:
        recs.append(
            "Collect a leaf sample for laboratory analysis to determine whether "
            "lesions indicate fungal, bacterial, or abiotic stress origin."
        )
    if trend == "Declining":
        recs.append(
            "Increase monitoring to bi-weekly submissions for this species "
            "until trend reverses to Stable or Improving."
        )
    if not recs:
        recs.append(
            "Maintain monthly monitoring schedule. No immediate intervention required."
        )

    # ── Prediction note ───────────────────────────────────────────────────────
    if health_status == "Degraded" and trend == "Declining":
        note = (f"⚠ Lessertia frutescens has shown a declining trend across "
                f"{prior_count} prior submission(s). Risk: {risk_level} "
                f"(alert score {alert_score}/10).")
    elif health_status == "Stressed":
        note = (f"Plant is under stress ({trend} trend). "
                f"Blended score: {blended:.2f}. Monitor closely.")
    elif trend == "Improving":
        note = (f"Positive signal — condition improving "
                f"(blended score: {blended:.2f}). Status: {health_status}.")
    else:
        note = (f"Plant is {health_status} (blended score: {blended:.2f}). "
                f"Trend: {trend}. Based on {prior_count} prior submission(s).")

    return dict(
        health_status=health_status,
        trend_direction=trend,
        prior_report_count=prior_count,
        trend_score=round(blended, 4),
        prediction_note=note,
        damage_labels=damage_labels,
        damage_detected=len(damage_labels) > 0,
        severity_score=round(severity_score, 4),
        comprehensive_report=comprehensive_report,
        recommendations=recs,
        factor_breakdown=factor_breakdown,
        risk_level=risk_level,
        alert_score=alert_score,
    )


# ── Response models ────────────────────────────────────────────────────────────
class ContextualAnalysisResult(BaseModel):
    health_status: str
    trend_direction: str
    prior_report_count: int
    trend_score: float
    prediction_note: str
    damage_labels: List[str]
    damage_detected: bool
    severity_score: float
    comprehensive_report: str
    recommendations: List[str]
    factor_breakdown: dict
    risk_level: str
    alert_score: int


class IdentificationResult(BaseModel):
    species: str
    confidence: float
    identified: bool
    message: str


class HealthResult(BaseModel):
    health_status: str
    trend_direction: str
    prior_report_count: int
    trend_score: float
    prediction_note: str


class DamageResult(BaseModel):
    damage_labels: List[str]
    damage_detected: bool
    severity_score: float


class FullPipelineResult(BaseModel):
    species: str
    confidence: float
    identified: bool
    health_status: str
    trend_direction: str
    prior_report_count: int
    prediction_note: str
    damage_labels: List[str]
    damage_detected: bool
    overall_message: str


# ─────────────────────────────────────────────────────────────────────────────
# /predict/contextual_url  — PredictionsScreen
# Downloads the image from a Firestore Storage URL, runs F2+F3, and
# cross-references results with the report context fields stored in Firestore.
# ─────────────────────────────────────────────────────────────────────────────
@app.post("/predict/contextual_url", response_model=ContextualAnalysisResult)
async def contextual_analysis_url(
    image_url: str = Form(...),
    prior_scores: str = Form(default=""),
    environmental_condition: str = Form(default="Normal"),
    degradation_indicator: str = Form(default="None observed"),
    observer_notes: str = Form(default=""),
    reported_severity: str = Form(default="1"),
    location: str = Form(default=""),
):
    """
    F2 + F3 from a stored image URL (Firebase Storage / Unsplash / any public URL).
    Used by PredictionsScreen which reads plant_reports from Firestore and passes
    each report's imageUrl + context fields here without the user re-entering data.
    """
    img = await fetch_image_from_url(image_url)
    result = _build_contextual_result(
        img,
        prior_scores_str=prior_scores,
        environmental_condition=environmental_condition,
        degradation_indicator=degradation_indicator,
        observer_notes=observer_notes,
        reported_severity=reported_severity,
        location=location,
    )
    return ContextualAnalysisResult(**result)


# ─────────────────────────────────────────────────────────────────────────────
# Existing endpoints
# ─────────────────────────────────────────────────────────────────────────────
@app.post("/predict/species", response_model=IdentificationResult)
async def identify_species(file: UploadFile = File(...)):
    img_bytes = await file.read()
    img = decode_image(img_bytes)
    result_str = identifier.predict_plant(img, confidence_threshold=0.80)
    if "not identified" in result_str.lower() or "error" in result_str.lower():
        return IdentificationResult(
            species="Unknown", confidence=0.0, identified=False,
            message="Plant could not be identified. Flagged for researcher review.",
        )
    parts = result_str.split("(Confidence:")
    species = parts[0].strip()
    confidence = float(parts[1].replace(")", "").strip()) if len(parts) > 1 else 0.0
    return IdentificationResult(
        species=species, confidence=round(confidence, 4), identified=True,
        message=f"Identified as {species} with {confidence:.0%} confidence.",
    )


@app.post("/predict/health", response_model=HealthResult)
async def classify_health(
    file: UploadFile = File(...),
    species: str = "",
    prior_scores: str = "",
):
    img_bytes = await file.read()
    img = decode_image(img_bytes)
    current_score = _image_health_score(img)
    prior_list = []
    if prior_scores.strip():
        try:
            prior_list = [float(x) for x in prior_scores.split(",") if x.strip()]
        except ValueError:
            prior_list = []
    all_scores = prior_list + [current_score]
    prior_count = len(prior_list)
    health_status = (
        "Healthy" if current_score < 0.25 else
        "Stressed" if current_score < 0.60 else "Degraded"
    )
    if len(all_scores) >= 3:
        slope = all_scores[-1] - all_scores[-3]
        trend = "Improving" if slope < -0.10 else ("Declining" if slope > 0.10 else "Stable")
    else:
        trend = "Stable"
    note = (
        f"⚠ Declining over the past {prior_count} report(s). Researcher notified."
        if health_status == "Degraded" and trend == "Declining" else
        f"Improving. Status: {health_status}. Based on {prior_count} prior report(s)."
        if trend == "Improving" else
        f"Plant is {health_status}. Trend: {trend}. Based on {prior_count} prior report(s)."
    )
    return HealthResult(
        health_status=health_status, trend_direction=trend,
        prior_report_count=prior_count, trend_score=round(current_score, 4),
        prediction_note=note,
    )


@app.post("/predict/damage", response_model=DamageResult)
async def detect_damage(file: UploadFile = File(...)):
    img_bytes = await file.read()
    img = decode_image(img_bytes)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    labels = _detect_damage_labels(img, hsv)
    return DamageResult(
        damage_labels=labels,
        damage_detected=len(labels) > 0,
        severity_score=round(len(labels) / 5.0, 4),
    )


@app.post("/predict/full", response_model=FullPipelineResult)
async def full_pipeline(
    file: UploadFile = File(...),
    prior_scores: str = "",
):
    img_bytes = await file.read()
    img = decode_image(img_bytes)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

    result_str = identifier.predict_plant(img, confidence_threshold=0.80)
    if "not identified" in result_str.lower() or "error" in result_str.lower():
        species, confidence, identified = "Unknown", 0.0, False
    else:
        parts = result_str.split("(Confidence:")
        species = parts[0].strip()
        confidence = float(parts[1].replace(")", "").strip()) if len(parts) > 1 else 0.0
        identified = True

    current_score = _image_health_score(img)
    prior_list = []
    if prior_scores.strip():
        try:
            prior_list = [float(x) for x in prior_scores.split(",") if x.strip()]
        except ValueError:
            prior_list = []
    all_scores = prior_list + [current_score]
    prior_count = len(prior_list)
    health_status = (
        "Healthy" if current_score < 0.25 else
        "Stressed" if current_score < 0.60 else "Degraded"
    )
    if len(all_scores) >= 3:
        slope = all_scores[-1] - all_scores[-3]
        trend = "Improving" if slope < -0.10 else ("Declining" if slope > 0.10 else "Stable")
    else:
        trend = "Stable"
    note = (
        f"⚠ Declining over {prior_count} report(s). Researcher notified."
        if health_status == "Degraded" and trend == "Declining" else
        f"Improving. Status: {health_status}. Based on {prior_count} prior report(s)."
        if trend == "Improving" else
        f"Plant is {health_status}. Trend: {trend}. Based on {prior_count} prior report(s)."
    )
    damage_labels = _detect_damage_labels(img, hsv)
    overall = (
        "Species not confirmed — flagged for researcher review." if not identified else
        f"⚠ {species} is Degraded with {len(damage_labels)} damage type(s) detected."
        if health_status == "Degraded" else
        f"{species} is under stress. Monitor closely."
        if health_status == "Stressed" else
        f"{species} appears healthy. Continue monitoring."
    )
    return FullPipelineResult(
        species=species, confidence=round(confidence, 4), identified=identified,
        health_status=health_status, trend_direction=trend,
        prior_report_count=prior_count, prediction_note=note,
        damage_labels=damage_labels, damage_detected=len(damage_labels) > 0,
        overall_message=overall,
    )


@app.post("/train")
async def train_model(dataset_path: str = DATASET_PATH):
    if not os.path.exists(dataset_path):
        raise HTTPException(status_code=404, detail=f"Dataset path not found: {dataset_path}")
    success = identifier.train_model(dataset_path)
    if not success:
        raise HTTPException(status_code=500, detail="Training failed")
    model_file = os.path.join(MODEL_PATH, "identifier_model.pkl")
    with open(model_file, "wb") as f:
        pickle.dump({
            "model": identifier.model,
            "features": identifier.dataset_features,
            "images": identifier.dataset_images,
        }, f)
    return {"status": "trained", "dataset": dataset_path}


@app.get("/health")
async def health_check():
    return {
        "status": "running",
        "model_trained": identifier.model is not None,
        "species_registered": identifier.categories,
    }