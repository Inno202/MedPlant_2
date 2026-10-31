"""
Two extra experiments for the paper. Put this file in ml_server/ (next to
train_health.py and plant_identifier.py) and run:

    python extra_experiments.py --health-root "C:\\Users\\innoc\\Downloads\\Lessertia" --f1-dataset ./dataset

Paste the printed output back to Claude.

1. F2 ablation: effect of class weights and threshold on Stressed precision/recall
   (same grouped 5-fold CV as train_health.py; the test set is not touched).
2. F1 leak-free accuracy: the same Random Forest, but all four augmented copies of a
   photograph are kept on the same side of the split (5-fold grouped CV).
"""
import argparse
from pathlib import Path

import numpy as np
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score, confusion_matrix, precision_score, recall_score
from sklearn.model_selection import StratifiedGroupKFold

SEED = 42


def f2_ablation(root):
    import train_health as th
    df = th.build_manifest(Path(root))
    X = th.featurise(df)
    dev = df.split.isin(["train", "validation"]).values
    X, y, g = X[dev], df.y.values[dev], df.group.values[dev]
    cv = StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=SEED)
    print("\n=== F2 ABLATION (out-of-fold, n = %d, Stressed = %d) ===" % (len(y), y.sum()))
    for weights in (None, "balanced_subsample"):
        oof = np.zeros(len(y))
        for tr, va in cv.split(X, y, g):
            m = RandomForestClassifier(n_estimators=400, min_samples_leaf=2, class_weight=weights,
                                       n_jobs=-1, random_state=SEED).fit(X[tr], y[tr])
            oof[va] = m.predict_proba(X[va])[:, 1]
        for t in (0.50, 0.27):
            p = (oof >= t).astype(int)
            tn, fp, fn, tp = confusion_matrix(y, p).ravel()
            print(f"weights={str(weights):18s} threshold={t:.2f}  recall={recall_score(y, p):.2f}  "
                  f"precision={precision_score(y, p, zero_division=0):.2f}  TP={tp} FP={fp} FN={fn} TN={tn}")


def f1_grouped(dataset):
    from plant_identifier import PlantIdentifier
    pi = PlantIdentifier()
    X, y = pi.load_dataset(dataset)
    groups = np.array([p for c in pi.categories for p in pi.dataset_images[c]])
    cv = StratifiedGroupKFold(n_splits=5, shuffle=True, random_state=SEED)
    prob_les = np.zeros(len(y))
    for tr, va in cv.split(X, y, groups):
        m = RandomForestClassifier(n_estimators=300, max_depth=25, min_samples_split=4,
                                   class_weight="balanced", n_jobs=-1, random_state=SEED).fit(X[tr], y[tr])
        prob_les[va] = m.predict_proba(X[va])[:, 0]
    orig = np.arange(len(y)) % 4 == 0          # score the original photographs only
    yo, po = y[orig], prob_les[orig]
    print("\n=== F1 LEAK-FREE (grouped 5-fold CV, %d photographs) ===" % orig.sum())
    print(f"accuracy at argmax: {accuracy_score(yo, (po < 0.5).astype(int)):.3f}")
    les, oth = yo == 0, yo == 1
    for t in (0.5, 0.7, 0.8):
        print(f"confirm if P(Lessertia) >= {t:.2f}: Lessertia confirmed {np.mean(po[les] >= t):.3f}, "
              f"Other wrongly confirmed {np.mean(po[oth] >= t):.3f}")


if __name__ == "__main__":
    ap = argparse.ArgumentParser()
    ap.add_argument("--health-root", required=True)
    ap.add_argument("--f1-dataset", default="./dataset")
    a = ap.parse_args()
    f2_ablation(a.health_root)
    f1_grouped(a.f1_dataset)
