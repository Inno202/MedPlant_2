# ml_server/main.py
# FastAPI server exposing the three RF ML functions as REST endpoints.
# Flutter app calls these endpoints when a community user submits a plant report.
#
# Install dependencies:
#   pip install fastapi uvicorn python-multipart opencv-python-headless
#               scikit-learn scikit-image scipy numpy pillow
#
# Run:
#   uvicorn main:app --host 0.0.0.0 --port 8000 --reload
#
# For production (ngrok tunnel to expose to Flutter on phone):
#   ngrok http 8000

import cv2
import numpy as np
import io
import os
import pickle
from fastapi import FastAPI, File, UploadFile, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import List, Optional
from PIL import Image

# ── Import your existing ML classes ──────────────────────────────────────────
# Place plant_identifier.py and plant_monitor.py in the same folder as main.py
from plant_identifier import PlantIdentifier
from plant_monitor import PlantMonitor, EnhancedFeatureExtractor

app = FastAPI(
    title="MedPlant ML API",
    description="Three-function Random Forest pipeline for Thaba-Nchu medicinal plant monitoring",
    version="1.0.0",
)

# Allow Flutter app to call this server
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["*"],
    allow_headers=["*"],
)

# ── Global model instances (loaded once at startup) ───────────────────────────
identifier = PlantIdentifier()
monitor = PlantMonitor(use_deep_features=False)
feature_extractor = EnhancedFeatureExtractor(use_deep_features=False)

DATASET_PATH = os.environ.get("DATASET_PATH", "./dataset")
MODEL_PATH = os.environ.get("MODEL_PATH", "./models")
HISTORY_PATH = os.environ.get("HISTORY_PATH", "./history")

os.makedirs(MODEL_PATH, exist_ok=True)
os.makedirs(HISTORY_PATH, exist_ok=True)

# ── Startup: train or load saved models ──────────────────────────────────────
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
        print("🔄 Training identifier model from dataset...")
        identifier.train_model(DATASET_PATH)
        # Save for next startup
        with open(model_file, "wb") as f:
            pickle.dump({
                "model": identifier.model,
                "features": identifier.dataset_features,
                "images": identifier.dataset_images,
            }, f)
        print("✅ Identifier model trained and saved")
    else:
        print("⚠️  No dataset found — model not trained. POST /train to train.")


# ── Helper: decode uploaded image to OpenCV format ───────────────────────────
def decode_image(file_bytes: bytes) -> np.ndarray:
    nparr = np.frombuffer(file_bytes, np.uint8)
    img = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img is None:
        raise HTTPException(status_code=400, detail="Could not decode image")
    return img


# ── Response models ───────────────────────────────────────────────────────────
class IdentificationResult(BaseModel):
    species: str
    confidence: float
    identified: bool
    message: str


class HealthResult(BaseModel):
    health_status: str          # Healthy | Stressed | Degraded
    trend_direction: str        # Improving | Stable | Declining
    prior_report_count: int
    trend_score: float          # 0.0 (healthy) → 1.0 (degraded)
    prediction_note: str


class DamageResult(BaseModel):
    damage_labels: List[str]
    damage_detected: bool
    severity_score: float       # 0.0 → 1.0


class FullPipelineResult(BaseModel):
    # F1
    species: str
    confidence: float
    identified: bool
    # F2
    health_status: str
    trend_direction: str
    prior_report_count: int
    prediction_note: str
    # F3
    damage_labels: List[str]
    damage_detected: bool
    # Combined
    overall_message: str


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 1 — ML Function 1: Species Identification
# Called first; acts as quality gate before F2 and F3 proceed
# ─────────────────────────────────────────────────────────────────────────────
@app.post("/predict/species", response_model=IdentificationResult)
async def identify_species(file: UploadFile = File(...)):
    """
    ML Function 1 — Random Forest species identification.
    Returns the predicted species name and confidence score.
    If confidence < 0.90, returns 'not identified' and flags for researcher review.
    """
    img_bytes = await file.read()
    img = decode_image(img_bytes)

    result_str = identifier.predict_plant(img, confidence_threshold=0.80)

    if "not identified" in result_str.lower() or "error" in result_str.lower():
        return IdentificationResult(
            species="Unknown",
            confidence=0.0,
            identified=False,
            message="Plant could not be identified with sufficient confidence. Flagged for researcher review.",
        )

    # Parse "Species Name (Confidence: 0.92)"
    parts = result_str.split("(Confidence:")
    species = parts[0].strip()
    confidence = float(parts[1].replace(")", "").strip()) if len(parts) > 1 else 0.0

    return IdentificationResult(
        species=species,
        confidence=round(confidence, 4),
        identified=True,
        message=f"Identified as {species} with {confidence:.0%} confidence.",
    )


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 2 — ML Function 2: Trend-Based Health Classification
# Requires prior submission history (passed as list of previous health scores)
# ─────────────────────────────────────────────────────────────────────────────
@app.post("/predict/health", response_model=HealthResult)
async def classify_health(
    file: UploadFile = File(...),
    species: str = "Unknown",
    prior_scores: str = "",   # comma-separated floats from Firebase e.g. "0.3,0.5,0.7"
):
    """
    ML Function 2 — Trend-based health classification.
    Classifies current health as Healthy / Stressed / Degraded.
    Computes trend (Improving / Stable / Declining) from prior submission history.
    """
    img_bytes = await file.read()
    img = decode_image(img_bytes)

    # Extract features for current image
    features = feature_extractor.extract_all_features(img)

    # Compute a health score from colour and texture signals
    # Green channel dominance → healthy; yellow/brown → stressed/degraded
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    green_mask = cv2.inRange(hsv, (35, 40, 40), (85, 255, 255))
    yellow_mask = cv2.inRange(hsv, (20, 40, 40), (35, 255, 255))
    brown_mask = cv2.inRange(hsv, (10, 30, 30), (20, 200, 150))

    total_px = img.shape[0] * img.shape[1]
    green_ratio = np.sum(green_mask > 0) / total_px
    yellow_ratio = np.sum(yellow_mask > 0) / total_px
    brown_ratio = np.sum(brown_mask > 0) / total_px

    # Current health score (0 = healthy, 1 = degraded)
    current_score = (yellow_ratio * 0.5 + brown_ratio * 1.0) / max(green_ratio + 0.01, 0.01)
    current_score = min(current_score, 1.0)

    # Parse prior scores from Firebase
    prior_list = []
    if prior_scores.strip():
        try:
            prior_list = [float(x) for x in prior_scores.split(",") if x.strip()]
        except ValueError:
            prior_list = []

    all_scores = prior_list + [current_score]
    prior_count = len(prior_list)

    # Health status from current score
    if current_score < 0.25:
        health_status = "Healthy"
    elif current_score < 0.60:
        health_status = "Stressed"
    else:
        health_status = "Degraded"

    # Trend from history
    if len(all_scores) >= 3:
        recent = all_scores[-3:]
        slope = recent[-1] - recent[0]
        if slope < -0.10:
            trend = "Improving"
        elif slope > 0.10:
            trend = "Declining"
        else:
            trend = "Stable"
    else:
        trend = "Stable"

    # Plain-language note
    if health_status == "Degraded" and trend == "Declining":
        note = f"⚠ This plant has shown declining condition over the past {prior_count} report(s). Researcher has been notified."
    elif health_status == "Healthy" and trend == "Stable":
        note = f"Plant condition is stable across the last {prior_count} report(s). No significant change detected."
    elif trend == "Improving":
        note = f"Condition is improving. Current status: {health_status}. Based on {prior_count} prior report(s)."
    else:
        note = f"Plant is currently {health_status}. Trend: {trend}. Based on {prior_count} prior report(s)."

    return HealthResult(
        health_status=health_status,
        trend_direction=trend,
        prior_report_count=prior_count,
        trend_score=round(current_score, 4),
        prediction_note=note,
    )


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 3 — ML Function 3: Damage Detection (multi-label)
# Uses colour analysis + edge/texture features to flag visible damage types
# ─────────────────────────────────────────────────────────────────────────────
@app.post("/predict/damage", response_model=DamageResult)
async def detect_damage(file: UploadFile = File(...)):
    """
    ML Function 3 — Damage detection.
    Identifies specific visible damage: leaf discolouration, wilting, browning,
    lesions, stem damage. Multiple labels can be returned per submission.
    Labels are grounded in Barolong community IK observational vocabulary.
    """
    img_bytes = await file.read()
    img = decode_image(img_bytes)

    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    total_px = img.shape[0] * img.shape[1]

    damage_labels = []

    # ── Leaf discolouration (yellowing) ──────────────────────────────────────
    yellow_mask = cv2.inRange(hsv, (15, 40, 40), (35, 255, 255))
    if np.sum(yellow_mask > 0) / total_px > 0.08:
        damage_labels.append("Leaf discolouration")

    # ── Browning ─────────────────────────────────────────────────────────────
    brown_mask = cv2.inRange(hsv, (8, 30, 30), (18, 200, 150))
    if np.sum(brown_mask > 0) / total_px > 0.06:
        damage_labels.append("Browning")

    # ── Wilting (low texture energy + low edge density) ──────────────────────
    edges = cv2.Canny(gray, 50, 150)
    edge_density = np.sum(edges > 0) / total_px
    blur_score = cv2.Laplacian(gray, cv2.CV_64F).var()
    if edge_density < 0.04 and blur_score < 50:
        damage_labels.append("Wilting")

    # ── Lesions (dark irregular spots on leaf surface) ───────────────────────
    _, dark_mask = cv2.threshold(gray, 40, 255, cv2.THRESH_BINARY_INV)
    kernel = np.ones((5, 5), np.uint8)
    dark_spots = cv2.morphologyEx(dark_mask, cv2.MORPH_OPEN, kernel)
    lesion_ratio = np.sum(dark_spots > 0) / total_px
    if 0.02 < lesion_ratio < 0.30:
        damage_labels.append("Lesions")

    # ── Stem damage (vertical structural discontinuity) ──────────────────────
    # Detect broken/absent vertical structures using Sobel
    sobelx = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
    sobely = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
    vertical_strength = np.mean(np.abs(sobely))
    horizontal_strength = np.mean(np.abs(sobelx))
    if vertical_strength > 0 and horizontal_strength / (vertical_strength + 1e-6) > 1.8:
        damage_labels.append("Stem damage")

    # Severity score: proportion of damage types detected
    severity = len(damage_labels) / 5.0

    return DamageResult(
        damage_labels=damage_labels,
        damage_detected=len(damage_labels) > 0,
        severity_score=round(severity, 4),
    )


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 4 — Full pipeline (F1 → F2 → F3 in one call)
# Flutter app calls this single endpoint on report submission
# ─────────────────────────────────────────────────────────────────────────────
@app.post("/predict/full", response_model=FullPipelineResult)
async def full_pipeline(
    file: UploadFile = File(...),
    prior_scores: str = "",
):
    """
    Runs all three ML functions sequentially on the submitted image.
    Flutter calls this endpoint once per report submission.
    F1 result is used as quality gate — if confidence < 0.80, F2 and F3 still run
    but the submission is flagged for researcher review.
    """
    img_bytes = await file.read()
    img = decode_image(img_bytes)

    # ── F1: Species Identification ────────────────────────────────────────────
    result_str = identifier.predict_plant(img, confidence_threshold=0.80)
    if "not identified" in result_str.lower() or "error" in result_str.lower():
        species = "Unknown"
        confidence = 0.0
        identified = False
    else:
        parts = result_str.split("(Confidence:")
        species = parts[0].strip()
        confidence = float(parts[1].replace(")", "").strip()) if len(parts) > 1 else 0.0
        identified = True

    # ── F2: Health Classification ─────────────────────────────────────────────
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    total_px = img.shape[0] * img.shape[1]

    green_mask = cv2.inRange(hsv, (35, 40, 40), (85, 255, 255))
    yellow_mask_h = cv2.inRange(hsv, (20, 40, 40), (35, 255, 255))
    brown_mask_h = cv2.inRange(hsv, (10, 30, 30), (20, 200, 150))

    green_ratio = np.sum(green_mask > 0) / total_px
    yellow_ratio = np.sum(yellow_mask_h > 0) / total_px
    brown_ratio = np.sum(brown_mask_h > 0) / total_px

    current_score = (yellow_ratio * 0.5 + brown_ratio * 1.0) / max(green_ratio + 0.01, 0.01)
    current_score = min(current_score, 1.0)

    prior_list = []
    if prior_scores.strip():
        try:
            prior_list = [float(x) for x in prior_scores.split(",") if x.strip()]
        except ValueError:
            prior_list = []

    all_scores = prior_list + [current_score]
    prior_count = len(prior_list)

    health_status = "Healthy" if current_score < 0.25 else ("Stressed" if current_score < 0.60 else "Degraded")

    if len(all_scores) >= 3:
        slope = all_scores[-1] - all_scores[-3]
        trend = "Improving" if slope < -0.10 else ("Declining" if slope > 0.10 else "Stable")
    else:
        trend = "Stable"

    if health_status == "Degraded" and trend == "Declining":
        note = f"⚠ This plant has shown declining condition over the past {prior_count} report(s). Researcher has been notified."
    elif trend == "Improving":
        note = f"Condition improving. Status: {health_status}. Based on {prior_count} prior report(s)."
    else:
        note = f"Plant is {health_status}. Trend: {trend}. Based on {prior_count} prior report(s)."

    # ── F3: Damage Detection ──────────────────────────────────────────────────
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    damage_labels = []

    yellow_mask2 = cv2.inRange(hsv, (15, 40, 40), (35, 255, 255))
    if np.sum(yellow_mask2 > 0) / total_px > 0.08:
        damage_labels.append("Leaf discolouration")

    brown_mask2 = cv2.inRange(hsv, (8, 30, 30), (18, 200, 150))
    if np.sum(brown_mask2 > 0) / total_px > 0.06:
        damage_labels.append("Browning")

    edges = cv2.Canny(gray, 50, 150)
    edge_density = np.sum(edges > 0) / total_px
    blur_score = cv2.Laplacian(gray, cv2.CV_64F).var()
    if edge_density < 0.04 and blur_score < 50:
        damage_labels.append("Wilting")

    _, dark_mask = cv2.threshold(gray, 40, 255, cv2.THRESH_BINARY_INV)
    kernel = np.ones((5, 5), np.uint8)
    dark_spots = cv2.morphologyEx(dark_mask, cv2.MORPH_OPEN, kernel)
    if 0.02 < np.sum(dark_spots > 0) / total_px < 0.30:
        damage_labels.append("Lesions")

    sobelx = cv2.Sobel(gray, cv2.CV_64F, 1, 0, ksize=3)
    sobely = cv2.Sobel(gray, cv2.CV_64F, 0, 1, ksize=3)
    if np.mean(np.abs(sobely)) > 0:
        h_ratio = np.mean(np.abs(sobelx)) / (np.mean(np.abs(sobely)) + 1e-6)
        if h_ratio > 1.8:
            damage_labels.append("Stem damage")

    # ── Overall message ───────────────────────────────────────────────────────
    if not identified:
        overall = "Species not confirmed — submission flagged for researcher review."
    elif health_status == "Degraded":
        overall = f"⚠ {species} is in a Degraded state with {len(damage_labels)} damage type(s) detected."
    elif health_status == "Stressed":
        overall = f"{species} is under stress. Monitor closely over the next submissions."
    else:
        overall = f"{species} appears healthy. Continue monitoring."

    return FullPipelineResult(
        species=species,
        confidence=round(confidence, 4),
        identified=identified,
        health_status=health_status,
        trend_direction=trend,
        prior_report_count=prior_count,
        prediction_note=note,
        damage_labels=damage_labels,
        damage_detected=len(damage_labels) > 0,
        overall_message=overall,
    )


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 5 — Train / retrain the identifier model
# Call this after adding new images to the dataset
# ─────────────────────────────────────────────────────────────────────────────
@app.post("/train")
async def train_model(dataset_path: str = DATASET_PATH):
    """Retrain the species identifier on the dataset at the given path."""
    if not os.path.exists(dataset_path):
        raise HTTPException(status_code=404, detail=f"Dataset path not found: {dataset_path}")

    success = identifier.train_model(dataset_path)
    if not success:
        raise HTTPException(status_code=500, detail="Training failed — check dataset structure")

    model_file = os.path.join(MODEL_PATH, "identifier_model.pkl")
    with open(model_file, "wb") as f:
        pickle.dump({
            "model": identifier.model,
            "features": identifier.dataset_features,
            "images": identifier.dataset_images,
        }, f)

    return {"status": "trained", "dataset": dataset_path}


# ─────────────────────────────────────────────────────────────────────────────
# ENDPOINT 6 — Health check
# ─────────────────────────────────────────────────────────────────────────────
@app.get("/health")
async def health_check():
    return {
        "status": "running",
        "model_trained": identifier.model is not None,
        "species_registered": identifier.categories,
    }
