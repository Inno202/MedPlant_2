import cv2
import numpy as np
import os

from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics import accuracy_score
from sklearn.model_selection import train_test_split
from sklearn.metrics.pairwise import cosine_similarity

from skimage.feature import local_binary_pattern

class PlantIdentifier:

    def __init__(self):

        self.categories = [
            "Lessertia frutescens",
            "Other"
        ]

        self.model = None
        self.feature_size = 512

        self.dataset_features = {}
        self.dataset_images = {}

    def segment_plant(self, image):
        """
        Attempt to isolate green plant regions.
        """

        hsv = cv2.cvtColor(image, cv2.COLOR_BGR2HSV)

        lower_green = np.array([25, 20, 20])
        upper_green = np.array([95, 255, 255])

        mask = cv2.inRange(hsv, lower_green, upper_green)

        kernel = np.ones((5, 5), np.uint8)

        mask = cv2.morphologyEx(mask, cv2.MORPH_OPEN, kernel)
        mask = cv2.morphologyEx(mask, cv2.MORPH_CLOSE, kernel)

        segmented = cv2.bitwise_and(image, image, mask=mask)

        return segmented

    def augment_image(self, image):

        augmented = []

        augmented.append(image)

        flipped = cv2.flip(image, 1)
        augmented.append(flipped)

        rotated = cv2.rotate(image, cv2.ROTATE_90_CLOCKWISE)
        augmented.append(rotated)

        brighter = cv2.convertScaleAbs(image, alpha=1.1, beta=20)
        augmented.append(brighter)

        return augmented

    def extract_features(self, image):

        try:

            image = self.segment_plant(image)

            img = cv2.resize(image, (224, 224))

            features = []

            hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)

            hist_h = cv2.calcHist([hsv], [0], None, [64], [0, 180]).flatten()
            hist_s = cv2.calcHist([hsv], [1], None, [64], [0, 256]).flatten()
            hist_v = cv2.calcHist([hsv], [2], None, [64], [0, 256]).flatten()

            features.extend(hist_h)
            features.extend(hist_s)
            features.extend(hist_v)

            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)

            lbp = local_binary_pattern(gray, 24, 3, method="uniform")

            hist_lbp = cv2.calcHist(
                [lbp.astype(np.uint8)],
                [0],
                None,
                [64],
                [0, 256]
            ).flatten()

            features.extend(hist_lbp)

            edges = cv2.Canny(gray, 50, 150)

            hist_edges = cv2.calcHist(
                [edges],
                [0],
                None,
                [64],
                [0, 256]
            ).flatten()

            features.extend(hist_edges)

            features = np.array(features)

            if len(features) < self.feature_size:

                padding = np.zeros(self.feature_size - len(features))

                features = np.concatenate([features, padding])

            else:
                features = features[:self.feature_size]

            features = features.astype(np.float32)

            features /= (np.linalg.norm(features) + 1e-8)

            return features

        except Exception as e:

            print(f"Feature extraction error: {e}")

            return np.zeros(self.feature_size)

    def load_dataset(self, dataset_path):

        features = []
        labels = []

        self.dataset_features = {}
        self.dataset_images = {}

        print("Loading dataset...")

        for category_idx, category in enumerate(self.categories):

            category_path = os.path.join(dataset_path, category)

            self.dataset_features[category] = []
            self.dataset_images[category] = []

            if not os.path.exists(category_path):

                print(f"Missing folder: {category_path}")

                continue

            image_files = [

                f for f in os.listdir(category_path)

                if f.lower().endswith((".jpg", ".jpeg", ".png"))
            ]

            for image_file in image_files:

                image_path = os.path.join(category_path, image_file)

                image = cv2.imread(image_path)

                if image is None:
                    continue

                augmented_images = self.augment_image(image)

                for aug_img in augmented_images:

                    feature = self.extract_features(aug_img)

                    features.append(feature)

                    labels.append(category_idx)

                    self.dataset_features[category].append(feature)

                    self.dataset_images[category].append(image_path)

        return np.array(features), np.array(labels)

    def train_model(self, dataset_path, test_size=0.2):

        features, labels = self.load_dataset(dataset_path)

        if len(features) == 0:

            print("No dataset loaded.")

            return False

        X_train, X_test, y_train, y_test = train_test_split(
            features,
            labels,
            test_size=test_size,
            random_state=42,
            stratify=labels
        )

        self.model = RandomForestClassifier(
            n_estimators=300,
            max_depth=25,
            min_samples_split=4,
            class_weight="balanced",
            random_state=42,
            n_jobs=-1
        )

        self.model.fit(X_train, y_train)

        y_pred = self.model.predict(X_test)

        acc = accuracy_score(y_test, y_pred)

        print(f"Accuracy: {acc:.4f}")

        return True

    def predict_plant(self, image, confidence_threshold=0.70):

        try:

            if self.model is None:

                return "Model not trained"

            feature = self.extract_features(image)

            feature = feature.reshape(1, -1)

            probabilities = self.model.predict_proba(feature)[0]

            prediction = np.argmax(probabilities)

            confidence = probabilities[prediction]

            category = self.categories[prediction]

            if category == "Other":

                return "Plant not identified"

            if confidence < confidence_threshold:

                return "Plant not identified"

            return f"{category} (Confidence: {confidence:.2f})"

        except Exception as e:

            print(f"Prediction error: {e}")

            return "Prediction failed"

    def find_most_similar_images(self, query_features, category, top_k=3):

        if category not in self.dataset_features:
            return []

        similarities = []

        for i, feature in enumerate(self.dataset_features[category]):

            similarity = cosine_similarity(
                [query_features],
                [feature]
            )[0][0]

            similarities.append(
                (similarity, self.dataset_images[category][i])
            )

        similarities.sort(reverse=True, key=lambda x: x[0])

        return similarities[:top_k]