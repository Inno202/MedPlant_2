# ml_server/main.py
# FastAPI server — three RF ML functions (FINAL ARCHITECTURE).
#
# ─────────────────────────────────────────────────────────────────────────
# FINAL ML FUNCTIONS (do not drift from this without an explicit decision)
# ─────────────────────────────────────────────────────────────────────────
#   F1 — Species Identification (unchanged): Random Forest confirms/rejects
#        the submitted image against the registered species list.
#
#   F2 — Leaf Health (BINARY): Healthy / Stressed. Specific visual cues
#        (leaf discolouration, browning, wilting, lesions, stem
#        irregularity) are surfaced as SUPPORTING EVIDENCE for a Stressed
#        call — they are not a separate output class or a separate ML
#        function. They only appear when F2 returns Stressed.
#
#   F3 — Trend & Monitoring: takes the F2 health_score for this submission
#        plus prior scores for the same species, fits a slope (linear
#        regression) → Improving / Stable / Declining. This replaces the
#        old "damage detection" function — trend, not damage labels, is F3.
#
# There is no "Degraded" class anywhere in this pipeline. Population-level
# concern is expressed through the trend (F3) and the researcher's
# degradation-alert threshold (3+ consecutive Stressed + Declining reports),
# not through a third health class.
#
# ─────────────────────────────────────────────────────────────────────────
# Endpoints
# ─────────────────────────────────────────────────────────────────────────
# POST /predict/full            F1 + F2 + F3, image bytes   → AddReportScreen
# POST /predict/contextual_url  F2 + F3, image URL          → PredictionsScreen
# POST /predict/species         F1 only
# POST /predict/health          F2 only (binary + evidence)
# POST /predict/trend           F3 only (given a score + prior scores)
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
from plant_health_classifier import (
    PlantHealthClassifier,
    HEALTHY, STRESSED,
    IMPROVING, STABLE, DECLINING,
)

app = FastAPI(
    title="MedPlant ML API",
    description="F1 species ID + F2 binary leaf health + F3 trend/monitoring "
                "for Thaba-Nchu medicinal plant monitoring",
    version="3.0.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

identifier = PlantIdentifier()
health_classifier = PlantHealthClassifier()  # F2 + F3

DATASET_PATH = os.environ.get("DATASET_PATH", "./dataset")
MODEL_PATH = os.environ.get("MODEL_PATH", "./models")

os.makedirs(MODEL_PATH, exist_ok=True)


@app.on_event("startup")
async def startup_event():
    # ── F1: species identifier ──────────────────────────────────────────
    model_file = os.path.join(MODEL_PATH, "identifier_model.pkl")
    if os.path.exists(model_file):
        with open(model_file, "rb") as f:
            saved = pickle.load(f)
            identifier.model = saved["model"]
            identifier.dataset_features = saved["features"]
            identifier.dataset_images = saved["images"]
        print("✅ F1 identifier model loaded from disk")
    elif os.path.exists(DATASET_PATH):
        print("🔄 Training F1 identifier model from dataset…")
        identifier.train_model(DATASET_PATH)
        with open(model_file, "wb") as f:
            pickle.dump({
                "model": identifier.model,
                "features": identifier.dataset_features,
                "images": identifier.dataset_images,
            }, f)
        print("✅ F1 identifier model trained and saved")
    else:
        print("⚠️  No dataset found — F1 model not trained. POST /train to train.")

    # ── F2: binary leaf-health classifier ───────────────────────────────
    health_classifier.train()
    print("✅ F2 leaf-health classifier (binary RF) trained")


# ── Shared helpers ──────────────────────────────────────────────────────
def decode_image(file_bytes: bytes) -> np.ndarray:
    nparr = np.frombuffer(file_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail="Could not decode image")
    return img


async def fetch_image_from_url(url: str) -> np.ndarray:
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


def _leaf_stress_evidence(img: np.ndarray, hsv: np.ndarray) -> list:
    """
    Supporting visual evidence for an F2 Stressed call — leaf
    discolouration, browning, wilting, lesions, stem irregularity.
    This is NOT a separate ML function or output class; main.py only
    calls this when health_status == Stressed.
    """
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    total_px = img.shape[0] * img.shape[1]
    evidence = []

    if np.sum(cv2.inRange(hsv, (15, 40, 40), (35, 255, 255)) > 0) / total_px > 0.08:
        evidence.append("Leaf discolouration")
    if np.sum(cv2.inRange(hsv, (8, 30, 30), (18, 200, 150)) > 0) / total_px > 0.06:
        evidence.append("Browning")

    edges = cv2.Canny(gray, 50, 150)
    edge_density = np.sum(edges > 0) / total_px
    blur_score = cv2.Laplacian(gray, cv2.CV_64F).var()
    if edge_density < 0.04 and blur_score < 50:
        evidence.append("Wilting")

    _, dark_mask = cv2.threshold(gray, 40, 255, cv2.THRESH_BINARY_INV)
    kernel = np.ones((5, 5), np.uint8)
    dark_spots = cv2.morphologyEx(dark_mask, cv2.MORPH_OPEN, kernel)
    if 0.02 < np.sum(dark_spots > 0) / total_px < 0.30:
        evidence.append("Lesions")

    sobelx = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
    sobely = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
    if np.mean(np.abs(sobely)) > 0:
        if np.mean(np.abs(sobelx)) / (np.mean(np.abs(sobely)) + 1e-6) > 1.8:
            evidence.append("Stem irregularity")

    return evidence


def _build_contextual_result(
    img: np.ndarray,
    prior_scores_str: str,
    environmental_condition: str,
    degradation_indicator: str,
    observer_notes: str,
    reported_severity: str,
    location: str,
) -> dict:
    """F2 (binary health + evidence) + F3 (trend) — shared by endpoints."""
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    total_px = img.shape[0] * img.shape[1]

    try:
        sev_int = max(1, min(5, int(reported_severity)))
    except ValueError:
        sev_int = 1

    # ── F2 ────────────────────────────────────────────────────────────
    f2 = health_classifier.classify_leaf_health(
        img,
        reported_severity=sev_int,
        environmental_condition=environmental_condition,
    )
    health_status = f2["health_status"]        # Healthy | Stressed
    health_score = f2["health_score"]           # 0.0..1.0
    confidence = f2["confidence"]

    # ── F3 ────────────────────────────────────────────────────────────
    f3 = health_classifier.compute_trend(health_score, prior_scores_str)
    trend = f3["trend_direction"]               # Improving | Stable | Declining
    prior_count = f3["prior_report_count"]

    # ── Supporting evidence for F2 (only surfaced when Stressed) ───────
    evidence = _leaf_stress_evidence(img, hsv) if health_status == STRESSED else []

    indicator_map = {
        "Over-harvesting": "Over-harvesting signs reported",
        "Pollution": "Pollution stress reported",
        "Flooding": "Water stress reported",
        "Fire damage": "Fire damage reported",
        "Invasive species nearby": "Competition stress reported",
        "Drought stress": "Drought stress reported",
        "Land use change": "Habitat disturbance reported",
    }
    if health_status == STRESSED and degradation_indicator in indicator_map:
        extra = indicator_map[degradation_indicator]
        if extra not in evidence:
            evidence.append(extra)

    severity_score = len(evidence) / 6.0

    # ── Factor breakdown (descriptive context) ──────────────────────────
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
        "F2 classification": (
            f"{health_status} · {confidence:.0%} confidence · health score {health_score:.2f}/1.0."
        ),
        "F3 trend": (
            f"{trend} — based on {prior_count} prior submission(s) plus the current score."
        ),
        "Environmental condition": (
            f"{environmental_condition} — " + {
                "Hot": "High temperature stress likely. Heat accelerates desiccation.",
                "Dry": "Drought conditions. Water deficit is a primary stressor.",
                "Frost": "Frost exposure can cause tissue stress and wilting.",
                "Cold": "Cold stress may slow growth and increase disease susceptibility.",
                "Wet / After rain": "Recent rainfall beneficial but may increase fungal risk.",
                "Windy": "Wind stress can cause physical damage and increase transpiration losses.",
            }.get(environmental_condition, "Conditions within normal range.")
        ),
        "Reported context": (
            f"{degradation_indicator} — "
            + ("No external stressor reported." if degradation_indicator == "None observed"
               else f"Community-reported: {degradation_indicator}. Recognised pressure on "
               "Lessertia frutescens in the Free State (Vukeya et al., 2024).")
        ),
        "Reported severity": (
            f"Level {sev_int}/5 — "
            + [
                "No visible damage reported.",
                "Minor stress reported by observer.",
                "Moderate stress reported by observer.",
                "Severe stress reported — verification recommended.",
                "Very severe — priority monitoring recommended.",
              ][sev_int - 1]
        ),
        "F2 supporting evidence": (
            f"{', '.join(evidence)} — evidence supporting the {health_status} classification."
            if evidence else "No visual stress evidence present."
        ),
    }
    if observer_notes.strip():
        factor_breakdown["Observer notes"] = (
            f"'{observer_notes[:120]}{'…' if len(observer_notes) > 120 else ''}' — "
            "IK holder observation recorded and factored into the assessment."
        )

    # ── Monitoring priority score (researcher follow-up urgency only —
    #    never overrides the F2 Healthy/Stressed call) ───────────────────
    alert_score = 0
    alert_score += min(3, int(health_score * 4))
    alert_score += min(3, len(evidence))
    alert_score += min(2, sev_int - 1)
    if trend == DECLINING:
        alert_score += 1
    if environmental_condition in ("Hot", "Dry", "Frost"):
        alert_score += 1
    if health_status == STRESSED:
        alert_score += 1
    alert_score = min(alert_score, 10)

    risk_level = (
        "Critical" if alert_score > 7 else
        "High" if alert_score > 4 else
        "Moderate" if alert_score > 2 else
        "Low"
    )

    # ── Comprehensive report ─────────────────────────────────────────────
    loc_str = f" in {location}" if location.strip() else " in Thaba-Nchu"
    parts = [
        f"Leaf health assessment of Lessertia frutescens (Cancer Bush){loc_str} "
        f"(F2 binary classification + F3 trend · {prior_count} prior submission(s)).",
        "",
        f"F2: {health_status.upper()} ({confidence:.0%} confidence, health score "
        f"{health_score:.2f}/1.0, reported severity {sev_int}/5). F3 trend: {trend}.",
    ]
    if environmental_condition not in ("Normal",):
        parts.append(
            f"The {environmental_condition} environmental conditions at time of observation "
            "are a known stressor for this species and were factored into F2's assessment."
        )
    if evidence:
        parts.append(f"Supporting evidence for the Stressed call: {', '.join(evidence)}.")
    elif health_status == STRESSED:
        parts.append("Classified Stressed primarily on colour/texture signal; no discrete visual evidence flagged.")
    else:
        parts.append("No visual stress evidence — consistent with a Healthy classification.")
    if observer_notes.strip():
        parts.append(
            f"Observer noted: \"{observer_notes[:200]}\". "
            "This IK contribution has been recorded in alignment with the study methodology."
        )
    parts.append(
        f"Monitoring priority: {risk_level.upper()} (score {alert_score}/10). "
        "This reflects follow-up urgency for this submission — it does not itself "
        "constitute a species-level degradation finding; that determination is made "
        "separately once a species accumulates repeated Stressed + Declining reports "
        "(see researcher degradation alerts)."
    )
    comprehensive_report = " ".join(parts)

    # ── Recommendations ──────────────────────────────────────────────────
    recs: list[str] = []
    if health_status == STRESSED and (trend == DECLINING or alert_score >= 7):
        recs.append(
            "Flag for researcher follow-up — high monitoring priority based on the F2 "
            "classification and F3 declining trend, combined with environmental and "
            "observer-reported signals."
        )
    if "Over-harvesting signs reported" in evidence or degradation_indicator == "Over-harvesting":
        recs.append(
            "Note possible harvesting pressure at this site. Coordinate with traditional "
            "healers to assess whether the local population needs a recovery period."
        )
    if environmental_condition in ("Hot", "Dry"):
        recs.append(
            "Consider supplementary watering or shade protection within managed "
            "conservation areas. Record soil moisture at next visit."
        )
    if environmental_condition == "Frost":
        recs.append(
            "Document frost-related stress across the monitored population. "
            "Check for new growth at root base within 2–3 weeks."
        )
    if "Lesions" in evidence or "Browning" in evidence:
        recs.append(
            "Consider a follow-up sample to determine whether lesions indicate "
            "fungal, bacterial, or abiotic stress origin."
        )
    if trend == DECLINING:
        recs.append(
            "Increase monitoring frequency for this species/location until the "
            "trend returns to Stable or Improving."
        )
    if not recs:
        recs.append("Maintain routine monitoring schedule. No immediate follow-up required.")

    return dict(
        health_status=health_status,
        trend_direction=trend,
        prior_report_count=prior_count,
        trend_score=health_score,
        prediction_note=f2["prediction_note"] + f" Trend: {trend}.",
        damage_labels=evidence,          # field name kept for Flutter compatibility
        damage_detected=len(evidence) > 0,
        severity_score=round(severity_score, 4),
        comprehensive_report=comprehensive_report,
        recommendations=recs,
        factor_breakdown=factor_breakdown,
        risk_level=risk_level,
        alert_score=alert_score,
    )


# ── Response models ──────────────────────────────────────────────────────
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
    health_score: float
    confidence: float
    prediction_note: str
    evidence: List[str]


class TrendResult(BaseModel):
    trend_direction: str
    prior_report_count: int


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


# ─────────────────────────────────────────────────────────────────────────
# /predict/contextual_url — PredictionsScreen (F2 + F3 from a stored URL)
# ─────────────────────────────────────────────────────────────────────────
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


# ─────────────────────────────────────────────────────────────────────────
@app.post("/predict/species", response_model=IdentificationResult)
async def identify_species(file: UploadFile = File(...)):
    """F1 only."""
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
    reported_severity: str = Form(default="1"),
    environmental_condition: str = Form(default="Normal"),
):
    """F2 only — binary Healthy/Stressed classification + supporting evidence."""
    img_bytes = await file.read()
    img = decode_image(img_bytes)
    try:
        sev_int = max(1, min(5, int(reported_severity)))
    except ValueError:
        sev_int = 1

    f2 = health_classifier.classify_leaf_health(
        img, reported_severity=sev_int, environmental_condition=environmental_condition,
    )
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    evidence = _leaf_stress_evidence(img, hsv) if f2["health_status"] == STRESSED else []

    return HealthResult(
        health_status=f2["health_status"],
        health_score=f2["health_score"],
        confidence=f2["confidence"],
        prediction_note=f2["prediction_note"],
        evidence=evidence,
    )


@app.post("/predict/trend", response_model=TrendResult)
async def predict_trend(
    current_score: float = Form(...),
    prior_scores: str = Form(default=""),
):
    """F3 only — trend classification from a health score + prior scores."""
    f3 = health_classifier.compute_trend(current_score, prior_scores)
    return TrendResult(**f3)


@app.post("/predict/full", response_model=FullPipelineResult)
async def full_pipeline(
    file: UploadFile = File(...),
    prior_scores: str = Form(default=""),
    reported_severity: str = Form(default="1"),
    environmental_condition: str = Form(default="Normal"),
):
    """F1 + F2 + F3 in one call."""
    img_bytes = await file.read()
    img = decode_image(img_bytes)
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

    # F1
    result_str = identifier.predict_plant(img, confidence_threshold=0.80)
    if "not identified" in result_str.lower() or "error" in result_str.lower():
        species, confidence, identified = "Unknown", 0.0, False
    else:
        parts = result_str.split("(Confidence:")
        species = parts[0].strip()
        confidence = float(parts[1].replace(")", "").strip()) if len(parts) > 1 else 0.0
        identified = True

    try:
        sev_int = max(1, min(5, int(reported_severity)))
    except ValueError:
        sev_int = 1

    # F2
    f2 = health_classifier.classify_leaf_health(
        img, reported_severity=sev_int, environmental_condition=environmental_condition,
    )
    health_status = f2["health_status"]

    # F3
    f3 = health_classifier.compute_trend(f2["health_score"], prior_scores)
    trend = f3["trend_direction"]
    prior_count = f3["prior_report_count"]

    # F2 supporting evidence (only when Stressed)
    evidence = _leaf_stress_evidence(img, hsv) if health_status == STRESSED else []

    overall = (
        "Species not confirmed — flagged for researcher review." if not identified else
        f"⚠ {species} is Stressed with {len(evidence)} supporting indicator(s) detected — trend {trend}."
        if health_status == STRESSED else
        f"{species} appears healthy. Continue monitoring."
    )
    return FullPipelineResult(
        species=species, confidence=round(confidence, 4), identified=identified,
        health_status=health_status, trend_direction=trend,
        prior_report_count=prior_count,
        prediction_note=f2["prediction_note"] + f" Trend: {trend}.",
        damage_labels=evidence, damage_detected=len(evidence) > 0,
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
        "f1_model_trained": identifier.model is not None,
        "f2_health_classifier_trained": health_classifier._is_trained,
        "species_registered": identifier.categories,
    }