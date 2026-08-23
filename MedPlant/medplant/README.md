# MedPlant — Alpha Version

**Development of an Intelligent Mobile-Based Biodiversity Monitoring System for Medicinal Plants: A Case of Thaba-Nchu**

IPJ527C — Advanced Research Project B | Assignment 1: Alpha Version Demonstration
Thembile Poti | Student No: 222001234 | Supervisor: Dr Phoobane
Central University of Technology, Free State | 2026

---

## 1. Overview

MedPlant is a three-tier mobile-based biodiversity monitoring system for *Lessertia frutescens* (Cancer Bush) in Thaba-Nchu community, integrating indigenous knowledge (IK) from the Barolong community with a machine learning pipeline.

- **Presentation layer:** Flutter (mobile + web)
- **ML processing layer:** Python / FastAPI / scikit-learn Random Forest pipeline
- **Data layer:** Firebase (Firestore + Firebase Auth) with Cloudinary for image storage

Two roles only: `communityUser` (traditional healers / IK holders) and `researcher`.

---

## 2. Repository / Submission Artefacts

This alpha submission includes:

- **Source code / repository:** (https://github.com/Inno202/MedPlant_2.git) 
- **Executable:** an Android APK (`app-release.apk`) is included for UI and code inspection.
  **The APK alone will not run the ML features.** The ML server is hosted locally only for this alpha (see Section 5, "On the Horizon"), so the APK's `_baseUrl` points at `http://localhost:8000`, which is unreachable from an installed device off the presenter's machine. The **live demonstration** (run from source) is what shows the full working ML pipeline. 

- **Presentation slides:** 222001234_T_Poti_MedPlant_Alpha_Demo.pptx

---

## 3. How to Run the System Locally

The project has two parts that must both be running: the Flutter app and the Python ML server. **Start the ML server first**, then the Flutter app — the app checks server reachability on the Add Report and Monitoring screens and will show an "offline" banner if the server isn't up yet.

### 3.1 Start the ML server

```
cd medplant_project\ml_server
venv\Scripts\activate
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```

Confirm it's running before demoing: open `http://localhost:8000/health` in a browser. You should see a JSON response including `f1_model_trained`, `f2_health_classifier_trained`, and the registered species list.

### 3.2 Run the Flutter app

```
cd medplant_project\medplant\medplant
flutter pub get
flutter run

```

`flutter run` will prompt you to pick a target device (Chrome / emulator / physical device / Windows desktop). To target a specific device:


**Important:** `_baseUrl` in `lib/services/ml_service.dart` is set to `http://localhost:8000` for this alpha (local-only hosting). This only resolves correctly when the Flutter target and the ML server are running **on the same machine** — e.g. Chrome, an Android emulator, or the Windows desktop build on the presenter's laptop. It will **not** resolve on a separate physical phone. Do not demo on a physical device unless the ML server has been re-pointed to a reachable network address for that session.

---

## 4. Dependencies (fresh machine setup)

### 4.1 Flutter / mobile app

- Flutter SDK `^3.8.1` (Dart is bundled) — lockfile requires `flutter: >=3.32.0`
- Android Studio (Android SDK + emulator) and/or Chrome (web target) and/or a physical device with USB debugging enabled
- Run `flutter pub get` inside `medplant_project\medplant\medplant` — this installs all packages declared in `pubspec.yaml`:
  `firebase_core`, `firebase_auth`, `cloud_firestore`, `firebase_storage`, `http`, `image_picker`, `geolocator`, `go_router`, `provider`, `google_fonts`, `font_awesome_flutter`, `dotted_border`
- No manual Firebase CLI step is required to run the app — `firebase_options.dart` and `google-services.json` are already committed and configured against the `medplant-1` Firebase project.

### 4.2 ML server

- Python 3.x
- A virtual environment at `medplant_project\ml_server\venv` (create with `python -m venv venv` if not already present)
- Always confirm `(venv)` appears in the terminal prompt before installing or running anything
- Install dependencies inside the venv:

  ```
  pip install -r requirements.txt
  ```

  This installs: `fastapi==0.111.0`, `uvicorn[standard]==0.29.0`, `python-multipart==0.0.9`, `opencv-python-headless==4.9.0.80`, `scikit-learn` (developed and tested against 1.8.0; `requirements.txt` pins 1.4.2 — the newer installed version is confirmed working), `scikit-image==0.22.0`, `scipy==1.13.0`, `numpy==1.26.4`, `pillow==10.3.0`, `httpx==0.27.0`

No Node.js, Docker, or ngrok is required for this local-only alpha demonstration.

---

## 5. Feature Status

**Implemented Features**
 User authentication (Firebase Auth, two-role) 
 F1 — Species Identification (Random Forest) 
 F2 — Leaf Health Classification (binary: Healthy / Stressed)  
 F3 — Trend & Monitoring (linear regression on prior scores)  
 Add Report flow (image capture, GPS, environmental context, Cloudinary upload)  
 View Reports feed — community user (own/public approved reports only, via `reviewStatus` visibility filter)  
 View Reports feed — researcher (all reports, filtered/reviewed, with access to the approval queue)  
 Predictions screen (Firestore → ML → `ml_predictions` cache loop)  (Implemented and confirmed working end-to-end)
 Researcher Analytics Dashboard (live species/report/alert/user stats)  
 Degradation alerts (3+ Stressed + Declining reports triggers an alert)  
 Researcher: Approve flagged/unidentified reports (assign confirmed species name)  
 Researcher: Decline flagged reports (permanently hidden from feed) 

 **Partially Implemented Features**
 F2/F3 confidence calibrated on real labelled images
 
 **Deferred Features** 
 Hosted / always-on ML server (local-only for this alpha)


**Note on report visibility by role:** the `plant_reports` feed is filtered client-side by `reviewStatus`. Community users see approved reports (their own submissions plus the public feed); legacy documents with no `reviewStatus` field are treated as visible by default. Researchers see the same feed but with an additional **"Manage Reports"** action on the View Reports screen that opens the approval queue (`/approvereports`) — a swipeable card view of all `reviewStatus == pending` submissions (i.e. reports the ML pipeline could not confidently identify), where the researcher must confirm species before **Approve** will proceed, or can **Decline** to permanently hide the submission. Approving flips the report to visible in the shared feed and re-triggers the degradation-alert check for that species.

---

## 6. Documented Proposal Deviations

**F2/F3 redefinition.** The original proposal described F2 as a three-class Healthy/Stressed/Degraded classifier and F3 as a separate "damage detection" function. In the implemented system, F2 is a **binary** Healthy/Stressed classifier — a single image cannot defensibly establish a third "Degraded" state — and specific visual cues (discolouration, browning, wilting, lesions, stem irregularity) are surfaced only as **supporting evidence** for a Stressed call, not a separate output class. F3 was redefined as a trend function: a linear-regression slope over a species' prior F2 health scores plus the current score, producing Improving / Stable / Declining. Population-level degradation concern is expressed through F3's trend plus the researcher's alert threshold (3+ Stressed + Declining reports), not through a third health class.

---

## 7. Known Limitations & Next Steps

- **ML server hosting is local-only for this alpha.** Hugging Face Spaces (Docker, free tier) has been identified as the target hosting platform for the next stage. Known caveat: the free tier sleeps after 48 hours of inactivity and cold-start delays (30–60s+) can exceed the Flutter client's current 30-second request timeout — mitigation planned is a pre-demo wake-up step and/or an increased client timeout.
- **F2 classifier is calibrated on synthetic feature vectors**, not real labelled diseased-leaf images, due to the absence of a large labelled dataset for *Lessertia frutescens* stress conditions at this stage. This is disclosed as a known limitation rather than concealed.
- **Physical-device demonstration** requires the ML server to be reachable over the network (not `localhost`) — deferred to the hosted-server stage.

---

## 8. Ethics, Privacy & Security

- Community-submitted images, GPS coordinates, and observation notes are stored in Firebase (Firestore + Cloudinary), a security- and access-controlled cloud platform.
- Role-based access separates community-submitted data from researcher-only analytics and administrative functions.
- Indigenous knowledge inputs (damage-evidence vocabulary, observational indicators) collected via the prior survey are treated as intellectual property of the Thaba-Nchu Barolong community, per the approved research proposal's ethical considerations.
- No personally identifying information beyond registration details (username, email, contact) is collected from community contributors; submissions are tied to a user ID, not published with personal identifiers.

---

## 9. Test Login Details

| Role | Email | Password |
|---|---|---|
| Community User | tp@med.co.za | @Medplant1 |
| Researcher | admin@med.co.za | @Medplant1 |

---

