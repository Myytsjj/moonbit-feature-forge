// MoonBit Feature Forge - Core Pipeline Module
// Unified local feature extraction, ORB description, matching, and RANSAC filtering pipeline.

///|
pub fn extract_features(
  img : GrayImage,
  fast_threshold : Int,
) -> (Array[Keypoint], Array[Descriptor]) {
  let fast_config = FastConfig::new(fast_threshold, 9, true, 0, 3, 0.0)
  let raw_kps = detect_fast_with_config(img, fast_config)
  compute_orb_descriptors_with_config(img, raw_kps, OrbConfig::default())
}

///|
pub fn extract_multiscale_features(
  img : GrayImage,
  fast_config : FastConfig,
  orb_config : OrbConfig,
  level_count : Int,
) -> (Array[Keypoint], Array[Descriptor]) {
  let keypoints : Array[Keypoint] = []
  let descriptors : Array[Descriptor] = []
  let pyramid = ImagePyramid::build(img, level_count)
  let mut level = 0
  while level < pyramid.level_count() {
    let level_img = pyramid.level(level)
    let detected = detect_fast_with_config(level_img, fast_config)
    let (valid, level_descriptors) = compute_orb_descriptors_with_config(
      level_img, detected, orb_config,
    )
    let mut index = 0
    while index < valid.length() {
      let level_kp = valid[index]
      let original = pyramid.to_original(
        FloatPoint2::new(
          Double::from_int(level_kp.x),
          Double::from_int(level_kp.y),
        ),
        level,
      )
      let size = if level_kp.size <= 0 {
        1
      } else {
        (Double::from_int(level_kp.size) / pyramid.scale(level)).to_int()
      }
      let mapped : Keypoint = {
        x: original.x.to_int(),
        y: original.y.to_int(),
        response: level_kp.response,
        angle: level_kp.angle,
        octave: level,
        size,
      }
      keypoints.push(mapped)
      descriptors.push(level_descriptors[index])
      index = index + 1
    }
    level = level + 1
  }
  (keypoints, descriptors)
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
