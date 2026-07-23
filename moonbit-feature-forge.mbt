// MoonBit Feature Forge - Core Pipeline Module
// Unified local feature extraction, ORB description, matching, and RANSAC filtering pipeline.

///|
pub fn extract_features(
  img : GrayImage,
  fast_threshold : Int,
) -> (Array[Keypoint], Array[Descriptor]) {
  let raw_kps = detect_fast(img, fast_threshold, true)
  compute_orb_descriptors(img, raw_kps)
}

///|
pub fn match_and_filter(
  desc1 : Array[Descriptor],
  desc2 : Array[Descriptor],
  ratio : Double,
) -> Array[Match] {
  let knn_matches = knn_match(desc1, desc2, 2)
  ratio_test(knn_matches, ratio)
}

///|
pub fn full_feature_pipeline(
  img1 : GrayImage,
  img2 : GrayImage,
  fast_threshold : Int,
  ratio : Double,
  ransac_threshold : Double,
) -> RansacResult {
  let (kps1, desc1) = extract_features(img1, fast_threshold)
  let (kps2, desc2) = extract_features(img2, fast_threshold)

  let good_matches = match_and_filter(desc1, desc2, ratio)
  ransac_affine(good_matches, kps1, kps2, 100, ransac_threshold)
}
