"""
Lessertia frutescens F2 health classifier (Healthy vs Stressed) - Random Forest.

Run 1 (cross-validation only, test set stays locked):
    python train_health.py

Run 2 (after you are happy with the CV results; scores test/ ONCE):
    python train_health.py --final

Folder layout expected:
    ROOT/train/{Healthy,Stressed}, ROOT/validation/{Healthy,Stressed}, ROOT/test/{Healthy,Stressed}

Install:
    pip install opencv-python scikit-learn scikit-image pandas joblib matplotlib
"""
import argparse
import json
import re
import warnings
from pathlib import Path

import cv2
import joblib
import matplotlib
matplotlib.use("Agg")
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from skimage.feature import graycomatrix, graycoprops, local_binary_pattern
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import (average_precision_score, classification_report,
                             confusion_matrix, precision_score, recall_score,
                             roc_auc_score, f1_score)
from sklearn.model_selection import StratifiedGroupKFold

warnings.filterwarnings("ignore")

DEFAULT_ROOT = r"C:\Users\innoc\Downloads\Lessertia"
SPLITS = ["train", "validation", "test"]
LABELS = {"Healthy": 0, "Stressed": 1}
EXTS = {".jpg", ".jpeg", ".png", ".bmp", ".webp"}
SEED = 42
FEATURE_VERSION = "v1"


# ----------------------------------------------------------------------------
# 1. Manifest + grouping + leakage audit
# ----------------------------------------------------------------------------
def read_image(path):
    data = np.fromfile(str(path), dtype=np.uint8)          # safe for Windows paths
    return cv2.imdecode(data, cv2.IMREAD_COLOR)


def dhash(img, size=8):
    g = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    g = cv2.resize(g, (size + 1, size))
    return (g[:, 1:] > g[:, :-1]).flatten()


def build_manifest(root, group_regex=None, online_names=frozenset()):
    rows = []
    for split in SPLITS:
        for label in LABELS:
            folder = root / split / label
            if not folder.exists():
                print(f"[warn] missing folder: {folder}")
                continue
            for p in sorted(folder.iterdir()):
                if p.suffix.lower() in EXTS:
                    rows.append(dict(path=str(p), filename=p.name, split=split,
                                     label=label, y=LABELS[label],
                                     source="online" if ("online" in p.name.lower() or p.name in online_names) else "field",
                                     size_kb=p.stat().st_size / 1024))
    df = pd.DataFrame(rows)
    if df.empty:
        raise SystemExit(f"No images found under {root}. Check the path and folder names.")

    hashes, dead, hw = [], [], []
    for i, p in enumerate(df.path):
        img = read_image(p)
        if img is None:
            dead.append(i)
            hashes.append(np.zeros(64, dtype=bool))
            hw.append((0, 0))
        else:
            hashes.append(dhash(img))
            hw.append(img.shape[:2])
    if dead:
        print(f"[warn] {len(dead)} unreadable images will be dropped.")
    H = np.array(hashes)

    # union-find: near-duplicates (dHash) and optional filename-derived group
    parent = list(range(len(df)))
    def find(a):
        while parent[a] != a:
            parent[a] = parent[parent[a]]
            a = parent[a]
        return a
    def union(a, b):
        ra, rb = find(a), find(b)
        if ra != rb:
            parent[rb] = ra

    for i in range(len(df)):
        d = (H[i] != H[i + 1:]).sum(axis=1)
        for j in np.where(d <= 6)[0]:
            union(i, i + 1 + j)

    if group_regex:
        key = {}
        for i, name in enumerate(df.filename):
            m = re.search(group_regex, name)
            if m:
                k = m.group(1) if m.groups() else m.group(0)
                if k in key:
                    union(i, key[k])
                else:
                    key[k] = i

    df["group"] = [find(i) for i in range(len(df))]
    df["height"] = [a for a, _ in hw]
    df["width"] = [b for _, b in hw]
    df = df.drop(index=dead).reset_index(drop=True)
    return df


def leakage_audit(df, out_dir):
    g = df.groupby("group")["split"].nunique()
    leaky = g[g > 1].index
    print("\n=== LEAKAGE AUDIT ===")
    print(f"Images: {len(df)} | groups (near-duplicate clusters): {df.group.nunique()}")
    if len(leaky) == 0:
        print("No group spans more than one split.")
        return
    print(f"WARNING: {len(leaky)} groups span more than one split. "
          f"Move these images so each group sits in one split:")
    bad = df[df.group.isin(leaky)].sort_values(["group", "split"])
    bad[["group", "split", "label", "filename"]].to_csv(out_dir / "leakage_report.csv", index=False)
    print(bad[["group", "split", "label", "filename"]].head(30).to_string(index=False))
    print(f"(full list: {out_dir / 'leakage_report.csv'})")


# ----------------------------------------------------------------------------
# 2. Features (no red/flower features; lighting normalised with CLAHE)
# ----------------------------------------------------------------------------
_clahe = cv2.createCLAHE(clipLimit=2.0, tileGridSize=(8, 8))
FEATURE_NAMES = (
    ["mask_frac", "green_ratio", "yellow_ratio", "brown_ratio",
     "H_mean", "H_std", "S_mean", "S_std", "V_mean", "V_std", "edge_density"]
    + [f"hue_bin_{i}" for i in range(18)]
    + [f"sat_bin_{i}" for i in range(8)]
    + [f"val_bin_{i}" for i in range(8)]
    + [f"lbp_{i}" for i in range(10)]
    + ["glcm_contrast", "glcm_homogeneity", "glcm_energy", "glcm_correlation"]
)


def extract_features(img):
    img = cv2.resize(img, (224, 224))
    hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
    hsv[:, :, 2] = _clahe.apply(hsv[:, :, 2])
    H, S, V = hsv[:, :, 0], hsv[:, :, 1], hsv[:, :, 2]
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

    # plant-ish mask: hue 10-100 (excludes red flowers and blue sky), reasonably saturated
    mask = (H >= 10) & (H < 100) & (S > 40) & (V > 40)
    n = int(mask.sum())
    total = H.size
    if n < 50:
        stats = [0.0] * 4 + [0.0] * 6
        hist_h = np.zeros(18); hist_s = np.zeros(8); hist_v = np.zeros(8)
    else:
        h, s, v = H[mask], S[mask], V[mask]
        green = ((h >= 35) & (h < 85)).mean()
        yellow = ((h >= 20) & (h < 35)).mean()
        brown = ((h >= 10) & (h < 20)).mean()
        stats = [n / total, green, yellow, brown,
                 h.mean() / 180, h.std() / 180, s.mean() / 255, s.std() / 255,
                 v.mean() / 255, v.std() / 255]
        hist_h = np.histogram(h, bins=18, range=(10, 100))[0] / n
        hist_s = np.histogram(s, bins=8, range=(0, 256))[0] / n
        hist_v = np.histogram(v, bins=8, range=(0, 256))[0] / n

    edges = cv2.Canny(gray, 50, 150)
    edge_density = float((edges > 0).mean())

    lbp = local_binary_pattern(gray, 8, 1, method="uniform")
    lbp_hist = np.histogram(lbp, bins=10, range=(0, 10))[0].astype(float)
    lbp_hist /= lbp_hist.sum() + 1e-8

    q = (gray // 8).astype(np.uint8)                        # 32 grey levels
    glcm = graycomatrix(q, [1], [0], levels=32, symmetric=True, normed=True)
    g = [graycoprops(glcm, p)[0, 0] for p in ("contrast", "homogeneity", "energy", "correlation")]

    feats = np.concatenate([stats[:4], stats[4:], [edge_density], hist_h, hist_s, hist_v, lbp_hist, g])
    assert len(feats) == len(FEATURE_NAMES), (len(feats), len(FEATURE_NAMES))
    return feats.astype(np.float32)


def featurise(df):
    X = []
    for i, p in enumerate(df.path):
        X.append(extract_features(read_image(p)))
        if (i + 1) % 100 == 0:
            print(f"  features: {i + 1}/{len(df)}")
    return np.array(X)


# ----------------------------------------------------------------------------
# 3. Model, CV, threshold, baselines
# ----------------------------------------------------------------------------
def make_rf():
    return RandomForestClassifier(n_estimators=400, max_depth=None, min_samples_leaf=2,
                                  class_weight="balanced_subsample", n_jobs=-1,
                                  random_state=SEED)


def grouped_cv(X, y, groups, n_splits=5):
    cv = StratifiedGroupKFold(n_splits=n_splits, shuffle=True, random_state=SEED)
    oof = np.zeros(len(y))
    folds = []
    for k, (tr, va) in enumerate(cv.split(X, y, groups), 1):
        m = make_rf().fit(X[tr], y[tr])
        p = m.predict_proba(X[va])[:, 1]
        oof[va] = p
        pred = (p >= 0.5).astype(int)
        folds.append(dict(fold=k, n_val=len(va), stressed_val=int(y[va].sum()),
                          stressed_recall=recall_score(y[va], pred, zero_division=0),
                          stressed_precision=precision_score(y[va], pred, zero_division=0),
                          pr_auc=average_precision_score(y[va], p) if y[va].sum() else np.nan))
    return oof, pd.DataFrame(folds)


def pick_threshold(y, p, target_recall=0.80):
    best = None
    for t in np.arange(0.05, 0.96, 0.01):
        pred = (p >= t).astype(int)
        r = recall_score(y, pred, zero_division=0)
        pr = precision_score(y, pred, zero_division=0)
        if r >= target_recall and (best is None or pr > best[2]):
            best = (t, r, pr)
    if best is None:                                       # fall back to best F2
        scores = []
        for t in np.arange(0.05, 0.96, 0.01):
            pred = (p >= t).astype(int)
            r = recall_score(y, pred, zero_division=0)
            pr = precision_score(y, pred, zero_division=0)
            f2 = 5 * pr * r / (4 * pr + r) if (4 * pr + r) else 0
            scores.append((f2, t, r, pr))
        _, t, r, pr = max(scores)
        best = (t, r, pr)
    return float(best[0])


def report(y, p, thr, title):
    pred = (p >= thr).astype(int)
    print(f"\n--- {title} (threshold {thr:.2f}) ---")
    print(classification_report(y, pred, target_names=["Healthy", "Stressed"], zero_division=0))
    cm = confusion_matrix(y, pred)
    print("Confusion matrix [rows=true, cols=pred] (Healthy, Stressed):\n", cm)
    out = dict(threshold=thr,
               stressed_recall=recall_score(y, pred, zero_division=0),
               stressed_precision=precision_score(y, pred, zero_division=0),
               stressed_f1=f1_score(y, pred, zero_division=0),
               pr_auc=average_precision_score(y, p),
               roc_auc=roc_auc_score(y, p) if len(set(y)) > 1 else float("nan"),
               confusion_matrix=cm.tolist())
    return out, cm


def save_cm(cm, path, title):
    fig, ax = plt.subplots(figsize=(4, 4))
    ax.imshow(cm, cmap="Greens")
    ax.set_xticks([0, 1]); ax.set_yticks([0, 1])
    ax.set_xticklabels(["Healthy", "Stressed"]); ax.set_yticklabels(["Healthy", "Stressed"])
    ax.set_xlabel("Predicted"); ax.set_ylabel("True"); ax.set_title(title)
    for i in range(2):
        for j in range(2):
            ax.text(j, i, int(cm[i, j]), ha="center", va="center", fontsize=14)
    fig.tight_layout(); fig.savefig(path, dpi=150); plt.close(fig)


def bootstrap_recall_ci(y, pred, n=2000):
    rng = np.random.default_rng(SEED)
    idx_pos = np.where(y == 1)[0]
    vals = [pred[rng.choice(idx_pos, len(idx_pos))].mean() for _ in range(n)]
    return np.percentile(vals, [2.5, 97.5])


# ----------------------------------------------------------------------------
def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--root", default=DEFAULT_ROOT)
    ap.add_argument("--final", action="store_true", help="score the locked test set (do this ONCE)")
    ap.add_argument("--group-regex", default=None,
                    help=r'optional regex to group by plant/site from filename, e.g. "(loc\d+)"')
    ap.add_argument("--features", choices=["all", "colour"], default="all",
                    help="colour = drop texture/edge features (guards against sharpness/camera shortcuts)")
    ap.add_argument("--online-file", default=None,
                    help="optional text file: one filename per line for images that came from online sources")
    ap.add_argument("--target-recall", type=float, default=0.80)
    args = ap.parse_args()

    root = Path(args.root)
    out_dir = Path(__file__).resolve().parent / "results"
    out_dir.mkdir(exist_ok=True)

    print("Scanning images and building manifest ...")
    online = set()
    if args.online_file:
        online = {l.strip() for l in open(args.online_file, encoding='utf-8') if l.strip()}
    df = build_manifest(root, args.group_regex, online)
    df.drop(columns=["path"]).to_csv(out_dir / "manifest.csv", index=False)
    print("\n=== DATASET COUNTS ===")
    print(pd.crosstab(df.split, df.label, margins=True))
    print("\nLabel x source (confounding check):")
    print(pd.crosstab(df.label, df.source, margins=True))
    leakage_audit(df, out_dir)
    print("\nImage properties by class (a big gap = possible shortcut):")
    print(df.groupby("label")[["height", "width", "size_kb"]].median().round(0).to_string())

    print("\nExtracting features ...")
    X = featurise(df)
    y = df.y.values
    names = list(FEATURE_NAMES)
    if args.features == "colour":
        keep = [i for i, n in enumerate(names)
                if not (n == "edge_density" or n.startswith("lbp_") or n.startswith("glcm_"))]
        X = X[:, keep]
        names = [names[i] for i in keep]
    print(f"\nFeature set: {args.features} ({len(names)} features)")

    dev = df.split.isin(["train", "validation"]).values
    Xd, yd, gd = X[dev], y[dev], df.group.values[dev]
    print(f"\nDevelopment set (train+validation): {len(yd)} images, {int(yd.sum())} Stressed")

    # ---- baselines -------------------------------------------------------
    maj_acc = 1 - yd.mean()
    print("\n=== BASELINES ===")
    print(f"Majority-class (always Healthy): accuracy {maj_acc:.3f}, Stressed recall 0.000")

    # ---- grouped CV ------------------------------------------------------
    print("\n=== 5-FOLD STRATIFIED GROUP CV (train + validation) ===")
    oof, folds = grouped_cv(Xd, yd, gd)
    print(folds.round(3).to_string(index=False))
    print(f"\nStressed recall @0.5: {folds.stressed_recall.mean():.3f} +/- {folds.stressed_recall.std():.3f}")
    print(f"Stressed precision @0.5: {folds.stressed_precision.mean():.3f} +/- {folds.stressed_precision.std():.3f}")
    print(f"PR-AUC: {folds.pr_auc.mean():.3f} +/- {folds.pr_auc.std():.3f}  (chance = {yd.mean():.3f})")

    cv_default, cm0 = report(yd, oof, 0.5, "Out-of-fold, default threshold")
    thr = pick_threshold(yd, oof, args.target_recall)
    cv_tuned, cm1 = report(yd, oof, thr, f"Out-of-fold, tuned for Stressed recall >= {args.target_recall:.0%}")
    save_cm(cm1, out_dir / "cv_confusion_matrix.png", "CV (tuned threshold)")

    # ---- shuffled-label sanity check ----------------------------------------
    rng = np.random.default_rng(SEED)
    y_shuf = rng.permutation(yd)
    oof_s, _ = grouped_cv(Xd, y_shuf, gd)
    print(f"\n=== SHUFFLED-LABEL TEST ===\nPR-AUC with random labels: {average_precision_score(y_shuf, oof_s):.3f} "
          f"(should be near {y_shuf.mean():.3f}; clearly higher means leakage)")

    # ---- final fit + feature importance --------------------------------------
    model = make_rf().fit(Xd, yd)
    imp = pd.Series(model.feature_importances_, index=names).sort_values(ascending=False)
    print("\n=== TOP 12 FEATURES ===")
    print(imp.head(12).round(4).to_string())
    imp.to_csv(out_dir / "feature_importance.csv")

    results = dict(counts=df.groupby(["split", "label"]).size().unstack().to_dict(),
                   majority_baseline_accuracy=maj_acc,
                   cv_folds=folds.to_dict(orient="records"),
                   cv_default=cv_default, cv_tuned=cv_tuned, chosen_threshold=thr)

    joblib.dump(dict(model=model, threshold=thr, feature_names=names, feature_set=args.features,
                     feature_version=FEATURE_VERSION, labels=["Healthy", "Stressed"]),
                out_dir / "lessertia_health_rf.joblib")

    # ---- locked test set -------------------------------------------------------
    if args.final:
        print("\n=== FINAL: LOCKED TEST SET (use this result once) ===")
        te = (df.split == "test").values
        Xt, yt = X[te], y[te]
        pt = model.predict_proba(Xt)[:, 1]
        test_res, cmt = report(yt, pt, thr, "TEST")
        lo, hi = bootstrap_recall_ci(yt, (pt >= thr).astype(int))
        print(f"Stressed recall 95% bootstrap CI: [{lo:.2f}, {hi:.2f}]  (n Stressed = {int(yt.sum())})")
        test_res["stressed_recall_ci95"] = [float(lo), float(hi)]
        save_cm(cmt, out_dir / "test_confusion_matrix.png", "Test set")
        results["test"] = test_res

        field = (df.source[te] == "field").values
        if field.sum() and (~field).sum():
            fres, _ = report(yt[field], pt[field], thr, "TEST, field images only")
            results["test_field_only"] = fres
    else:
        print("\nTest set not touched. When you are happy with the CV results, run:  python train_health.py --final")

    with open(out_dir / "metrics.json", "w") as f:
        json.dump(results, f, indent=2, default=float)
    print(f"\nSaved to {out_dir}: manifest.csv, metrics.json, feature_importance.csv, "
          f"cv_confusion_matrix.png, lessertia_health_rf.joblib")


if __name__ == "__main__":
    main()