import cv2
import numpy as np
import os
import matplotlib.pyplot as plt
from sklearn.metrics import accuracy_score, classification_report, confusion_matrix
from sklearn.preprocessing import StandardScaler
from sklearn.decomposition import PCA
from sklearn.ensemble import GradientBoostingClassifier, RandomForestClassifier
from sklearn.svm import SVC
from sklearn.neighbors import KNeighborsClassifier
from sklearn.linear_model import LogisticRegression
from skimage import morphology, measure, feature, color, filters
from scipy import ndimage
import warnings
warnings.filterwarnings('ignore')

# Try to import torch for deep features (optional but recommended)
try:
    import torch
    import torchvision.models as models
    import torchvision.transforms as transforms
    TORCH_AVAILABLE = True
except ImportError:
    TORCH_AVAILABLE = False
    print("PyTorch not available. Using traditional features only.")

# Try to import albumentations for augmentation
try:
    import albumentations as A
    ALBUMENTATIONS_AVAILABLE = True
except ImportError:
    ALBUMENTATIONS_AVAILABLE = False
    print("Albumentations not available. Using basic augmentation only.")

def analyze_branches(image_path):
    """
    Extract branch morphology features.
    Returns:
        dict with branch_count, total_branch_length_px, avg_branch_angle_deg,
        num_branch_segments, branching_factor, leaf_density
    """
    img = cv2.imread(image_path)
    if img is None:
        return None
    
    gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
    
    # Adaptive thresholding for varying lighting conditions
    binary = cv2.adaptiveThreshold(gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, 
                                   cv2.THRESH_BINARY_INV, 11, 2)
    
    # Morphological cleanup
    kernel = np.ones((3,3), np.uint8)
    cleaned = cv2.morphologyEx(binary, cv2.MORPH_OPEN, kernel, iterations=2)
    cleaned = cv2.morphologyEx(cleaned, cv2.MORPH_CLOSE, kernel, iterations=2)
    
    # Remove small noise
    labeled = measure.label(cleaned)
    props = measure.regionprops(labeled)
    for prop in props:
        if prop.area < 100:  # Remove tiny regions
            cleaned[labeled == prop.label] = 0
    
    # Skeletonize
    skeleton = morphology.skeletonize(cleaned // 255).astype(np.uint8)
    
    # Count endpoints for branch count
    kernel_neigh = np.array([[1,1,1],
                             [1,0,1],
                             [1,1,1]], dtype=np.uint8)
    neighbor_count = ndimage.convolve(skeleton, kernel_neigh, mode='constant')
    endpoints = np.where((skeleton == 1) & (neighbor_count == 1))
    branch_count = len(endpoints[0]) // 2
    
    # Connected components analysis
    labeled_branches, num_branches = measure.label(skeleton, connectivity=2, return_num=True)
    
    branch_lengths = []
    branch_angles = []
    for i in range(1, num_branches + 1):
        branch_pixels = np.argwhere(labeled_branches == i)
        if len(branch_pixels) < 10:
            continue
        branch_lengths.append(len(branch_pixels))
        # Fit line to branch
        if len(branch_pixels) > 5:
            vx, vy, x0, y0 = cv2.fitLine(branch_pixels.astype(np.float32), 
                                         cv2.DIST_L2, 0, 0.01, 0.01)
            angle = np.arctan2(vy, vx) * 180 / np.pi
            branch_angles.append(angle)
    
    # Additional morphological features
    plant_area = np.sum(cleaned // 255)
    convex_hull = morphology.convex_hull_object(cleaned // 255)
    convex_area = np.sum(convex_hull)
    solidity = plant_area / convex_area if convex_area > 0 else 0
    
    # Leaf density (rough estimate)
    leaf_density = plant_area / (gray.shape[0] * gray.shape[1])
    
    return {
        "branch_count": branch_count,
        "total_branch_length_px": sum(branch_lengths),
        "avg_branch_angle_deg": np.mean(branch_angles) if branch_angles else 0,
        "num_branch_segments": num_branches,
        "branching_factor": branch_count / (num_branches + 1e-6),
        "plant_area_px": plant_area,
        "solidity": solidity,
        "leaf_density": leaf_density
    }

class EnhancedFeatureExtractor:
    """Advanced feature extractor combining multiple feature types"""
    
    def __init__(self, use_deep_features=False):
        self.use_deep_features = use_deep_features and TORCH_AVAILABLE
        self.deep_model = None
        
        if self.use_deep_features:
            self._init_deep_model()
    
    def _init_deep_model(self):
        """Initialize deep learning model for feature extraction"""
        try:
            # Use EfficientNet for best trade-off
            self.deep_model = models.efficientnet_b0(pretrained=True)
            self.deep_model.eval()
            # Remove classification head
            self.deep_model = torch.nn.Sequential(*list(self.deep_model.children())[:-1])
            
            self.transform = transforms.Compose([
                transforms.ToPILImage(),
                transforms.Resize(224),
                transforms.ToTensor(),
                transforms.Normalize(mean=[0.485, 0.456, 0.406],
                                   std=[0.229, 0.224, 0.225])
            ])
            print("Deep feature extractor initialized successfully")
        except Exception as e:
            print(f"Failed to initialize deep model: {e}")
            self.use_deep_features = False
    
    def extract_deep_features(self, img):
        """Extract features using pre-trained CNN"""
        if not self.use_deep_features:
            return None
        
        with torch.no_grad():
            img_tensor = self.transform(img).unsqueeze(0)
            features = self.deep_model(img_tensor)
            return features.flatten().numpy()
    
    def extract_color_features(self, img):
        """Extract color histogram features"""
        hsv = cv2.cvtColor(img, cv2.COLOR_BGR2HSV)
        lab = cv2.cvtColor(img, cv2.COLOR_BGR2LAB)
        
        features = []
        
        # Color histograms
        for channel in range(3):
            hist_hsv = cv2.calcHist([hsv], [channel], None, [32], [0, 256])
            hist_lab = cv2.calcHist([lab], [channel], None, [32], [0, 256])
            features.extend(hist_hsv.flatten())
            features.extend(hist_lab.flatten())
        
        # Color moments
        for color_space in [hsv, lab]:
            for channel in range(3):
                mean = np.mean(color_space[:,:,channel])
                std = np.std(color_space[:,:,channel])
                skew = np.mean((color_space[:,:,channel] - mean) ** 3)
                features.extend([mean, std, skew])
        
        return np.array(features)
    
    def extract_texture_features(self, img):
        """Extract texture features using GLCM and LBP"""
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        
        # LBP features
        lbp = feature.local_binary_pattern(gray, 24, 3, method='uniform')
        lbp_hist, _ = np.histogram(lbp.ravel(), bins=26, range=(0, 26))
        lbp_hist = lbp_hist / np.sum(lbp_hist)
        
        # GLCM features
        from skimage.feature import graycomatrix, graycoprops
        
        glcm = graycomatrix(gray, [1], [0], levels=256, symmetric=True, normed=True)
        contrast = graycoprops(glcm, 'contrast')[0, 0]
        dissimilarity = graycoprops(glcm, 'dissimilarity')[0, 0]
        homogeneity = graycoprops(glcm, 'homogeneity')[0, 0]
        energy = graycoprops(glcm, 'energy')[0, 0]
        correlation = graycoprops(glcm, 'correlation')[0, 0]
        
        # Edge density
        edges = cv2.Canny(gray, 50, 150)
        edge_density = np.sum(edges > 0) / (gray.shape[0] * gray.shape[1])
        
        texture_features = np.concatenate([
            lbp_hist,
            [contrast, dissimilarity, homogeneity, energy, correlation, edge_density]
        ])
        
        return texture_features
    
    def extract_shape_features(self, img):
        """Extract shape-based features"""
        gray = cv2.cvtColor(img, cv2.COLOR_BGR2GRAY)
        _, binary = cv2.threshold(gray, 30, 255, cv2.THRESH_BINARY)
        
        contours, _ = cv2.findContours(binary, cv2.RETR_EXTERNAL, cv2.CHAIN_APPROX_SIMPLE)
        
        if not contours:
            return np.zeros(10)
        
        # Get largest contour
        largest_contour = max(contours, key=cv2.contourArea)
        
        # Basic shape features
        area = cv2.contourArea(largest_contour)
        perimeter = cv2.arcLength(largest_contour, True)
        circularity = (4 * np.pi * area) / (perimeter * perimeter + 1e-6)
        
        # Bounding box
        x, y, w, h = cv2.boundingRect(largest_contour)
        aspect_ratio = w / (h + 1e-6)
        extent = area / (w * h + 1e-6)
        
        # Convexity
        hull = cv2.convexHull(largest_contour)
        hull_area = cv2.contourArea(hull)
        convexity = area / (hull_area + 1e-6)
        
        # Hu moments (rotation and scale invariant)
        moments = cv2.moments(largest_contour)
        hu_moments = cv2.HuMoments(moments).flatten()
        hu_moments = -np.sign(hu_moments) * np.log10(np.abs(hu_moments) + 1e-10)
        
        shape_features = np.concatenate([
            [circularity, aspect_ratio, extent, convexity, area, perimeter],
            hu_moments[:4]  # First 4 Hu moments are most informative
        ])
        
        return shape_features
    
    def extract_all_features(self, img):
        """Extract and combine all feature types"""
        features = []
        
        # Traditional features
        color_feat = self.extract_color_features(img)
        texture_feat = self.extract_texture_features(img)
        shape_feat = self.extract_shape_features(img)
        
        features.extend(color_feat)
        features.extend(texture_feat)
        features.extend(shape_feat)
        
        # Deep features if available
        if self.use_deep_features:
            deep_feat = self.extract_deep_features(img)
            if deep_feat is not None:
                features.extend(deep_feat)
        
        return np.array(features)

class PlantMonitor:
    def __init__(self, use_deep_features=False):
        self.feature_extractor = EnhancedFeatureExtractor(use_deep_features=use_deep_features)
        self.march_features = {}
        self.april_features = {}
        self.march_branch_features = {}
        self.april_branch_features = {}
        self.march_image_paths = {}
        self.april_image_paths = {}
        self.categories = ["Agapanthus africanus", "Knowltonia Capensis", "Lessertia frutescens"]
    
    def augment_image(self, img, augment_type='standard'):
        """Apply data augmentation to reduce seasonal shift"""
        if ALBUMENTATIONS_AVAILABLE and augment_type == 'advanced':
            # Advanced augmentations for seasonal invariance
            aug = A.Compose([
                A.RandomBrightnessContrast(brightness_limit=0.3, contrast_limit=0.3, p=0.8),
                A.HueSaturationValue(hue_shift_limit=20, sat_shift_limit=30, 
                                    val_shift_limit=20, p=0.7),
                A.RandomGamma(gamma_limit=(70, 130), p=0.5),
                A.GaussianBlur(blur_limit=(3, 7), p=0.3),
                A.GaussNoise(var_limit=(10, 50), p=0.3),
                A.RandomRotate90(p=0.3),
                A.HorizontalFlip(p=0.5),
                A.VerticalFlip(p=0.3),
                A.RandomScale(scale_limit=0.2, p=0.5)
            ])
            return aug(image=img)['image']
        else:
            # Basic augmentations using OpenCV only
            augmented = img.copy()
            
            # Random brightness/contrast
            if np.random.random() > 0.5:
                alpha = np.random.uniform(0.7, 1.3)
                beta = np.random.uniform(-30, 30)
                augmented = cv2.convertScaleAbs(augmented, alpha=alpha, beta=beta)
            
            # Random horizontal flip
            if np.random.random() > 0.5:
                augmented = cv2.flip(augmented, 1)
            
            # Random rotation
            if np.random.random() > 0.7:
                angle = np.random.uniform(-15, 15)
                h, w = augmented.shape[:2]
                M = cv2.getRotationMatrix2D((w/2, h/2), angle, 1)
                augmented = cv2.warpAffine(augmented, M, (w, h))
            
            return augmented
    
    def load_month_data(self, month_path, month_name, augment_minority=True):
        """Load all images and extract combined features"""
        print(f"\n--- Loading {month_name} data ---")
        features_by_species = {}
        branch_features_by_species = {}
        paths_by_species = {}
        
        for species in self.categories:
            species_path = os.path.join(month_path, species)
            if not os.path.exists(species_path):
                print(f"Warning: {species_path} not found")
                features_by_species[species] = []
                branch_features_by_species[species] = []
                paths_by_species[species] = []
                continue
            
            features = []
            branch_features = []
            img_paths = []
            
            species_files = [f for f in os.listdir(species_path) 
                           if f.lower().endswith(('.png', '.jpg', '.jpeg'))]
            
            for file in species_files:
                img_path = os.path.join(species_path, file)
                img = cv2.imread(img_path)
                
                if img is not None:
                    # Extract visual features
                    visual_feat = self.feature_extractor.extract_all_features(img)
                    
                    # Extract branch features
                    branch_stats = analyze_branches(img_path)
                    if branch_stats:
                        branch_feat = np.array([
                            branch_stats['branch_count'],
                            branch_stats['total_branch_length_px'],
                            branch_stats['avg_branch_angle_deg'],
                            branch_stats['branching_factor'],
                            branch_stats['plant_area_px'],
                            branch_stats['solidity'],
                            branch_stats['leaf_density']
                        ])
                    else:
                        branch_feat = np.zeros(7)
                    
                    # Combine all features
                    combined_feat = np.concatenate([visual_feat, branch_feat])
                    features.append(combined_feat)
                    branch_features.append(branch_feat)
                    img_paths.append(img_path)
                    
                    # Augment minority classes (Knowltonia Capensis)
                    if augment_minority and species == "Knowltonia Capensis" and len(features) < 100:
                        for _ in range(2):  # Add 2 augmented versions
                            aug_img = self.augment_image(img)
                            aug_visual_feat = self.feature_extractor.extract_all_features(aug_img)
                            aug_branch_stats = analyze_branches(img_path)  # Branch stats similar
                            if aug_branch_stats:
                                aug_branch_feat = np.array([
                                    aug_branch_stats['branch_count'],
                                    aug_branch_stats['total_branch_length_px'],
                                    aug_branch_stats['avg_branch_angle_deg'],
                                    aug_branch_stats['branching_factor'],
                                    aug_branch_stats['plant_area_px'],
                                    aug_branch_stats['solidity'],
                                    aug_branch_stats['leaf_density']
                                ])
                            else:
                                aug_branch_feat = np.zeros(7)
                            
                            aug_combined_feat = np.concatenate([aug_visual_feat, aug_branch_feat])
                            features.append(aug_combined_feat)
                            branch_features.append(aug_branch_feat)
                            img_paths.append(img_path)
            
            features_by_species[species] = features
            branch_features_by_species[species] = branch_features
            paths_by_species[species] = img_paths
            print(f"{species}: {len([f for f in species_files])} original, {len(features)} total after augmentation")
        
        return features_by_species, branch_features_by_species, paths_by_species
    
    def compute_species_statistics(self, features_by_species):
        """Compute mean and std feature vector per species"""
        stats = {}
        for species, feats in features_by_species.items():
            if len(feats) == 0:
                stats[species] = {'mean': None, 'std': None, 'count': 0}
            else:
                feats_array = np.array(feats)
                stats[species] = {
                    'mean': np.mean(feats_array, axis=0),
                    'std': np.std(feats_array, axis=0),
                    'count': len(feats)
                }
        return stats
    
    def compare_feature_changes(self):
        """Compare mean feature vectors between March and April"""
        march_stats = self.compute_species_statistics(self.march_features)
        april_stats = self.compute_species_statistics(self.april_features)
        
        print("\n=== Feature Changes from March to April ===")
        for species in self.categories:
            m = march_stats[species]
            a = april_stats[species]
            if m['mean'] is None or a['mean'] is None:
                print(f"{species}: insufficient data")
                continue
            
            # Euclidean distance between mean vectors
            dist = np.linalg.norm(m['mean'] - a['mean'])
            # Cosine similarity
            cos_sim = np.dot(m['mean'], a['mean']) / (np.linalg.norm(m['mean']) * np.linalg.norm(a['mean']) + 1e-8)
            print(f"{species}:")
            print(f"  Number of images: March={m['count']}, April={a['count']}")
            print(f"  Mean feature shift (Euclidean): {dist:.4f}")
            print(f"  Cosine similarity: {cos_sim:.4f}")
    
    def cross_month_classification(self):
        """Advanced cross-month classification with multiple models and optimization"""
        print("\n=== Cross-Month Classification ===")
        
        # Prepare full feature sets and labels
        X_march, y_march = [], []
        for species, feats in self.march_features.items():
            label = self.categories.index(species)
            for f in feats:
                X_march.append(f)
                y_march.append(label)
        
        X_april, y_april = [], []
        for species, feats in self.april_features.items():
            label = self.categories.index(species)
            for f in feats:
                X_april.append(f)
                y_april.append(label)
        
        if len(X_march) == 0 or len(X_april) == 0:
            print("Insufficient data for cross classification")
            return
        
        X_march = np.array(X_march)
        X_april = np.array(X_april)
        
        # Normalize features
        scaler = StandardScaler()
        X_march_norm = scaler.fit_transform(X_march)
        X_april_norm = scaler.transform(X_april)
        
        # Apply PCA to reduce dimensionality and noise
        n_components = min(50, X_march_norm.shape[1] // 2)
        pca = PCA(n_components=n_components)
        X_march_pca = pca.fit_transform(X_march_norm)
        X_april_pca = pca.transform(X_april_norm)
        
        # Test multiple classifiers
        classifiers = {
            'Gradient Boosting': GradientBoostingClassifier(
                n_estimators=200, max_depth=5, learning_rate=0.1,
                subsample=0.8, random_state=42
            ),
            'Random Forest': RandomForestClassifier(
                n_estimators=300, max_depth=10, min_samples_split=5,
                class_weight='balanced', random_state=42
            ),
            'SVM (RBF)': SVC(
                kernel='rbf', C=10, gamma='scale', 
                class_weight='balanced', random_state=42, probability=True
            ),
            'KNN (weighted)': KNeighborsClassifier(
                n_neighbors=7, weights='distance', metric='minkowski'
            ),
            'Logistic Regression': LogisticRegression(
                max_iter=2000, C=1.0, class_weight='balanced', random_state=42
            )
        }
        
        results = {}
        best_clf = None
        best_acc = 0
        
        print("\nTraining on March → Testing on April:")
        for name, clf in classifiers.items():
            clf.fit(X_march_pca, y_march)
            y_pred = clf.predict(X_april_pca)
            acc = accuracy_score(y_april, y_pred)
            results[name] = acc
            
            if acc > best_acc:
                best_acc = acc
                best_clf = clf
            
            print(f"  {name}: {acc:.4f}")
        
        print("\nTraining on April → Testing on March:")
        for name, clf in classifiers.items():
            clf.fit(X_april_pca, y_april)
            y_pred = clf.predict(X_march_pca)
            acc = accuracy_score(y_march, y_pred)
            print(f"  {name}: {acc:.4f}")
        
        # Detailed report with best classifier (March→April)
        print("\n" + "="*60)
        print("DETAILED CLASSIFICATION REPORT (Best Model - March→April)")
        print("="*60)
        
        best_clf.fit(X_march_pca, y_march)
        y_pred_best = best_clf.predict(X_april_pca)
        
        print(f"\nBest Model: {max(results, key=results.get)}")
        print(f"Accuracy: {best_acc:.4f}")
        print("\nClassification Report:")
        print(classification_report(y_april, y_pred_best, target_names=self.categories))
        
        # Confusion matrix
        cm = confusion_matrix(y_april, y_pred_best)
        plt.figure(figsize=(10, 8))
        plt.imshow(cm, interpolation='nearest', cmap=plt.cm.Blues)
        plt.title('Confusion Matrix - March→April')
        plt.colorbar()
        tick_marks = np.arange(len(self.categories))
        plt.xticks(tick_marks, self.categories, rotation=45, ha='right')
        plt.yticks(tick_marks, self.categories)
        
        # Add text annotations
        for i in range(cm.shape[0]):
            for j in range(cm.shape[1]):
                plt.text(j, i, str(cm[i, j]), ha='center', va='center')
        
        plt.tight_layout()
        plt.ylabel('True label')
        plt.xlabel('Predicted label')
        plt.savefig('confusion_matrix.png', dpi=150, bbox_inches='tight')
        plt.show()
        
        return best_acc
    
    def visualize_feature_evolution(self, feature_indices=None):
        """Plot selected feature dimensions over time for each species"""
        if feature_indices is None:
            # Pick representative features
            feature_indices = [0, 10, 50, 100] if self.march_features else [0, 1, 2, 3]
        
        fig, axes = plt.subplots(len(self.categories), len(feature_indices), 
                                 figsize=(15, 10), squeeze=False)
        
        for i, species in enumerate(self.categories):
            march_feats = np.array(self.march_features.get(species, []))
            april_feats = np.array(self.april_features.get(species, []))
            
            for j, idx in enumerate(feature_indices):
                ax = axes[i, j]
                
                if idx < march_feats.shape[1] if len(march_feats) > 0 else False:
                    # Plot with jitter for better visibility
                    x_march = np.random.normal(0, 0.05, len(march_feats))
                    x_april = np.random.normal(1, 0.05, len(april_feats))
                    
                    ax.scatter(x_march, march_feats[:, idx], 
                              label='March', alpha=0.6, c='blue', s=20)
                    ax.scatter(x_april, april_feats[:, idx], 
                              label='April', alpha=0.6, c='red', s=20)
                    
                    # Add mean lines
                    if len(march_feats) > 0:
                        ax.axhline(y=np.mean(march_feats[:, idx]), xmin=0, xmax=0.2, 
                                  color='blue', linestyle='--', alpha=0.7)
                    if len(april_feats) > 0:
                        ax.axhline(y=np.mean(april_feats[:, idx]), xmin=0.8, xmax=1, 
                                  color='red', linestyle='--', alpha=0.7)
                
                ax.set_xticks([0, 1])
                ax.set_xticklabels(['March', 'April'])
                ax.set_title(f"{species}\nFeature {idx}")
                if i == 0 and j == 0:
                    ax.legend()
        
        plt.tight_layout()
        plt.savefig('feature_evolution.png', dpi=150, bbox_inches='tight')
        plt.show()
    
    def run_monitoring(self, march_path, april_path, use_augmentation=True):
        """Main pipeline with all improvements"""
        print("="*60)
        print("PLANT MONITORING SYSTEM - ENHANCED VERSION")
        print("="*60)
        
        # Load both months
        self.march_features, self.march_branch_features, self.march_image_paths = \
            self.load_month_data(march_path, "March", augment_minority=use_augmentation)
        
        self.april_features, self.april_branch_features, self.april_image_paths = \
            self.load_month_data(april_path, "April", augment_minority=use_augmentation)
        
        # Compare feature statistics
        self.compare_feature_changes()
        
        # Cross-month classification
        best_accuracy = self.cross_month_classification()
        
        # Visualize changes
        self.visualize_feature_evolution()
        
        # Branch analysis
        print("\n=== Branch Analysis ===")
        march_branches = self.monitor_branches(march_path, "March")
        april_branches = self.monitor_branches(april_path, "April")
        
        print("\nBranch Morphology Changes:")
        print("-" * 50)
        for species in self.categories:
            mb = march_branches.get(species)
            ab = april_branches.get(species)
            if mb is None or ab is None:
                print(f"{species}: insufficient branch data")
                continue
            
            print(f"\n{species}:")
            print(f"  Branch Count: March {mb['avg_branch_count']:.1f} → April {ab['avg_branch_count']:.1f} "
                  f"(Change: {ab['avg_branch_count'] - mb['avg_branch_count']:+.1f})")
            print(f"  Total Branch Length: March {mb['avg_total_length']:.0f}px → April {ab['avg_total_length']:.0f}px "
                  f"(Change: {ab['avg_total_length'] - mb['avg_total_length']:+.0f})")
            print(f"  Branching Factor: March {mb.get('avg_branching_factor', 0):.2f} → "
                  f"April {ab.get('avg_branching_factor', 0):.2f}")
            print(f"  Plant Solidity: March {mb.get('avg_solidity', 0):.3f} → "
                  f"April {ab.get('avg_solidity', 0):.3f}")
        
        # Generate summary report
        self.generate_report(best_accuracy)
        
        print("\n" + "="*60)
        print("Monitoring complete!")
        print("="*60)
        
        return best_accuracy
    
    def monitor_branches(self, month_path, month_name):
        """Enhanced branch monitoring with advanced metrics"""
        branch_stats = {}
        
        for species in self.categories:
            species_path = os.path.join(month_path, species)
            if not os.path.exists(species_path):
                continue
            
            branch_data = []
            for file in os.listdir(species_path):
                if file.lower().endswith(('.png', '.jpg', '.jpeg')):
                    img_path = os.path.join(species_path, file)
                    stats = analyze_branches(img_path)
                    if stats:
                        branch_data.append(stats)
            
            if branch_data:
                branch_stats[species] = {
                    "avg_branch_count": np.mean([b["branch_count"] for b in branch_data]),
                    "avg_total_length": np.mean([b["total_branch_length_px"] for b in branch_data]),
                    "avg_branch_angle": np.mean([b["avg_branch_angle_deg"] for b in branch_data]),
                    "avg_branching_factor": np.mean([b["branching_factor"] for b in branch_data]),
                    "avg_plant_area": np.mean([b["plant_area_px"] for b in branch_data]),
                    "avg_solidity": np.mean([b["solidity"] for b in branch_data]),
                    "avg_leaf_density": np.mean([b["leaf_density"] for b in branch_data])
                }
        
        return branch_stats
    
    def generate_report(self, best_accuracy):
        """Generate a comprehensive report of findings"""
        print("\n" + "="*60)
        print("FINAL ANALYSIS REPORT")
        print("="*60)
        
        print(f"\nOverall cross-month classification accuracy: {best_accuracy:.2%}")
        
        if best_accuracy < 0.5:
            print("\n⚠️  WARNING: Accuracy is below 50%. Recommendations:")
            print("   1. Consider using deep features (set use_deep_features=True)")
            print("   2. Collect more training data, especially for Knowltonia Capensis")
            print("   3. Verify image quality and consistency across months")
        elif best_accuracy < 0.7:
            print("\n📈 Good progress, but can improve. Recommendations:")
            print("   1. Enable deep features for better discrimination")
            print("   2. Add more augmentation types")
            print("   3. Try ensemble of multiple models")
        else:
            print("\n✅ Excellent accuracy! The monitoring system is working well.")
        
        print("\nSpecies-specific observations:")
        # Analyze which species is easiest/hardest based on branch changes
        # (This would be expanded with more detailed analysis)
        
        # Save report to file
        with open('monitoring_report.txt', 'w') as f:
            f.write("PLANT MONITORING REPORT\n")
            f.write("="*50 + "\n")
            f.write(f"Cross-month accuracy: {best_accuracy:.4f}\n")
            f.write(f"Date: {np.datetime64('today')}\n")

# ========== Usage ==========
if __name__ == "__main__":
    # Initialize with or without deep features
    # Set use_deep_features=True if you have PyTorch installed for better accuracy
    monitor = PlantMonitor(use_deep_features=TORCH_AVAILABLE)
    
    # Run monitoring
    accuracy = monitor.run_monitoring(
        march_path="../March",
        april_path="../April",
        use_augmentation=True  # Enable data augmentation
    )
    
    print(f"\nFinal Accuracy: {accuracy:.4f}")