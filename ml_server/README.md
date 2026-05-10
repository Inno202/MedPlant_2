# MedPlant ML Server — Setup Guide

## Folder structure

```
ml_server/
├── main.py                  ← FastAPI server (provided)
├── plant_identifier.py      ← Your File 1 (copy here, rename)
├── plant_monitor.py         ← Your File 2 (copy here, rename)
├── requirements.txt
├── models/                  ← Trained model saved here automatically
├── history/                 ← Per-species submission scores (future)
└── dataset/                 ← Your plant image dataset
    ├── Agapanthus africanus/
    │   ├── img001.jpg
    │   ├── img002.jpg
    │   └── ...
    ├── Knowltonia Capensis/
    │   └── ...
    └── Lessertia frutescens/
        └── ...
```

## Setup steps

### 1. Copy your Python files
Copy your two Python files into ml_server/ and rename them:
- Your first file  → `plant_identifier.py`
- Your second file → `plant_monitor.py`

### 2. Copy your dataset
Create the `dataset/` folder and copy your plant images:
```
ml_server/dataset/Agapanthus africanus/   ← put your Agapanthus images here
```
The folder name must match exactly what is in `PlantIdentifier.categories`.

### 3. Install dependencies
```bash
cd ml_server
pip install -r requirements.txt
```

### 4. Start the server
```bash
uvicorn main:app --host 0.0.0.0 --port 8000 --reload
```
The server will automatically train the model on first startup if the dataset folder exists.

### 5. Test the server
Open your browser at:  http://localhost:8000/docs
You will see the interactive API documentation where you can test each endpoint.

### 6. Connect Flutter (physical device)
Install ngrok: https://ngrok.com/download
```bash
ngrok http 8000
```
Copy the https URL (e.g. https://abc123.ngrok.io) and paste it into:
`lib/services/ml_service.dart` → `_baseUrl`

## API endpoints

| Method | Path | ML Function | Called from |
|--------|------|-------------|-------------|
| POST | /predict/full | F1 + F2 + F3 | AddReportScreen (main call) |
| POST | /predict/species | F1 only | Optional standalone |
| POST | /predict/health | F2 only | Optional standalone |
| POST | /predict/damage | F3 only | Optional standalone |
| POST | /train | Retrain | After adding new images |
| GET  | /health | Status check | App startup |

## pubspec.yaml additions needed in Flutter

```yaml
dependencies:
  http: ^1.1.0
  image_picker: ^1.0.7
```

## Adding more species later

1. Create a new folder: `dataset/New Species Name/`
2. Add images to that folder
3. Add the species name to `PlantIdentifier.categories` in plant_identifier.py
4. Call POST /train to retrain
5. Add the species to `PlantMonitor.categories` in plant_monitor.py
