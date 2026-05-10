import cv2
import numpy as np
import os
from sklearn.ensemble import RandomForestClassifier
from sklearn.metrics.pairwise import cosine_similarity
from sklearn.model_selection import train_test_split
from sklearn.metrics import accuracy_score

class PlantIdentifier:
    def __init__(self):
        self.categories = [
    "Lessertia frutescens"
]
        self.model = None
        self.feature_size = 512
        self.dataset_features = {}  # Store features for similarity comparison
        self.dataset_images = {}    # Store image paths for display
        
    def extract_features(self, image):
        """Extract features from plant image"""
        try:
            # Resize image to standard size
            img = cv2.resize(image, (224, 224))
            features = []
            
            # Color histogram features
            hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
            hist_hue = cv2.calcHist([hsv], [0], None, [50], [0, 180]).flatten()
            hist_sat = cv2.calcHist([hsv], [1], None, [50], [0, 256]).flatten()
            hist_val = cv2.calcHist([hsv], [2], None, [50], [0, 256]).flatten()
            features.extend(hist_hue)
            features.extend(hist_sat)
            features.extend(hist_val)
            
            # Texture features
            gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
            lbp = self.local_binary_pattern(gray)
            hist_lbp = cv2.calcHist([lbp.astype(np.uint8)], [0], None, [50], [0, 256]).flatten()
            features.extend(hist_lbp)
            
            # Shape features using edges
            edges = cv2.Canny(gray, 100, 200)
            hist_edges = cv2.calcHist([edges], [0], None, [50], [0, 256]).flatten()
            features.extend(hist_edges)
            
            # Convert to numpy array and normalize
            features = np.array(features)
            
            # Pad or truncate to exactly 512 features
            if len(features) < self.feature_size:
                padding = np.zeros(self.feature_size - len(features))
                features = np.concatenate([features, padding])
            elif len(features) > self.feature_size:
                features = features[:self.feature_size]
            
            features = features / (np.linalg.norm(features) + 1e-8)
            return features
            
        except Exception as e:
            print(f"Feature extraction error: {e}")
            return np.zeros(self.feature_size)
    
    def local_binary_pattern(self, image, points=8, radius=1):
        """Compute Local Binary Pattern for texture analysis"""
        lbp = np.zeros_like(image)
        for i in range(radius, image.shape[0]-radius):
            for j in range(radius, image.shape[1]-radius):
                center = image[i, j]
                binary = 0
                for p in range(points):
                    x = i + radius * np.cos(2 * np.pi * p / points)
                    y = j - radius * np.sin(2 * np.pi * p / points)
                    x, y = int(x), int(y)
                    if image[x, y] >= center:
                        binary |= (1 << p)
                lbp[i, j] = binary
        return lbp
    
    def load_dataset(self, dataset_path):
        """Load and prepare dataset for training and store features for similarity"""
        features = []
        labels = []
        
        print("Loading dataset...")
        self.dataset_features = {}
        self.dataset_images = {}
        
        for category_idx, category in enumerate(self.categories):
            category_path = os.path.join(dataset_path, category)
            self.dataset_features[category] = []
            self.dataset_images[category] = []
            
            if not os.path.exists(category_path):
                print(f"Warning: Directory {category_path} not found. Creating dummy data.")
                # Create dummy data for demo
                for _ in range(10):
                    dummy_features = np.random.randn(self.feature_size)
                    features.append(dummy_features)
                    labels.append(category_idx)
                    self.dataset_features[category].append(dummy_features)
                continue
                
            image_files = [f for f in os.listdir(category_path) 
                          if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
            
            for image_file in image_files:
                image_path = os.path.join(category_path, image_file)
                image = cv2.imread(image_path)
                if image is not None:
                    feature = self.extract_features(image)
                    features.append(feature)
                    labels.append(category_idx)
                    self.dataset_features[category].append(feature)
                    self.dataset_images[category].append(image_path)
        
        return np.array(features), np.array(labels)
    
    def evaluate_split(self, dataset_path, test_size=0.2):
        """Load dataset, split 80/20, train and evaluate without storing full dataset."""
        features, labels = self.load_dataset(dataset_path)
        X_train, X_test, y_train, y_test = train_test_split(
            features, labels, test_size=test_size, random_state=42, stratify=labels
            )
        model = RandomForestClassifier(n_estimators=100, random_state=42)
        model.fit(X_train, y_train)
        y_pred = model.predict(X_test)
        
        accuracy = accuracy_score(y_test, y_pred)
        print(f"Accuracy: {accuracy:.4f}")
        return accuracy
    
    def train_model(self, dataset_path, test_size=0.2):
        features, labels = self.load_dataset(dataset_path)
        if len(features) == 0:
            return False
    
        X_train, X_test, y_train, y_test = train_test_split(
            features, labels, test_size=test_size, random_state=42
        )
    
        self.model = RandomForestClassifier(n_estimators=100, random_state=42)
        self.model.fit(X_train, y_train)
    
        y_pred = self.model.predict(X_test)
        acc = accuracy_score(y_test, y_pred)
        print(f"Test accuracy (80/20 split): {acc:.4f}")
    
        # (Optional) Retrain on full dataset if you want the model to see all data
        #self.model.fit(features, labels)
    
        return True

    def find_most_similar_images(self, query_features, category, top_k=3):
        """Find the most similar images from the dataset"""
        if category not in self.dataset_features or not self.dataset_features[category]:
            return []
        
        similarities = []
        category_features = self.dataset_features[category]
        category_images = self.dataset_images[category]
        
        for i, feature in enumerate(category_features):
            # Calculate cosine similarity
            similarity = cosine_similarity([query_features], [feature])[0][0]
            similarities.append((similarity, category_images[i]))
        
        # Sort by similarity (descending) and return top_k
        similarities.sort(reverse=True, key=lambda x: x[0])
        return similarities[:top_k]
    
    def predict_plant(self, image, confidence_threshold=0.90):
        """Predict plant species with confidence based on Random Forest probabilities"""
        try:
            if self.model is None:
                return "Model not trained"
            
            # Extract features from input image
            query_features = self.extract_features(image)
            features_reshaped = query_features.reshape(1, -1)
            
            # Get probability estimates for each class
            proba = self.model.predict_proba(features_reshaped)[0]
            max_prob = np.max(proba)
            prediction = np.argmax(proba)
            
            plant_name = self.categories[prediction]
            
            # Check if confidence meets threshold
            if max_prob >= confidence_threshold:
                return plant_name + f" (Confidence: {max_prob:.2f})"
            else:
                return "Plant not identified"
                
        except Exception as e:
            print(f"Prediction error: {e}")
            return "Error during prediction"

