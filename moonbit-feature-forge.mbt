// MoonBit Feature Forge - Core Pipeline Module
// Unified local feature extraction, ORB description, matching, and RANSAC filtering pipeline.

///|
pub(all) struct FeatureConfig {
  fast : FastConfig
  orb : OrbConfig
  pyramid_levels : Int
  match_k : Int
  ratio : Double
  use_ratio : Bool
  enforce_unique : Bool
  ransac_iters : Int
  ransac_threshold : Double
  seed : Int
}

///|
pub fn FeatureConfig::default() -> FeatureConfig {
  {
    fast: FastConfig::new(20, 9, true, 512, 3, 0.0),
    orb: OrbConfig::default(),
    pyramid_levels: 1,
    match_k: 2,
    ratio: 0.8,
    use_ratio: true,
    enforce_unique: true,
    ransac_iters: 100,
    ransac_threshold: 3.0,
    seed: 42,
  }
}

///|
pub(all) struct PipelineResult {
  keypoints1 : Array[Keypoint]
  keypoints2 : Array[Keypoint]
  descriptors1 : Array[Descriptor]
  descriptors2 : Array[Descriptor]
  matches : Array[Match]
  match_stats : MatchStats
  affine : RansacResult
  homography : HomographyRansacResult
}

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
pub fn run_pipeline(
  img1 : GrayImage,
  img2 : GrayImage,
  config : FeatureConfig,
) -> PipelineResult {
  let (keypoints1, descriptors1) = extract_multiscale_features(
    img1,
    config.fast,
    config.orb,
    config.pyramid_levels,
  )
  let (keypoints2, descriptors2) = extract_multiscale_features(
    img2,
    config.fast,
    config.orb,
    config.pyramid_levels,
  )
  let policy = MatchPolicy::new(
    config.match_k,
    config.ratio,
    config.use_ratio,
    config.enforce_unique,
  )
  let matches = match_with_policy(descriptors1, descriptors2, policy)
  let affine = ransac_affine(
    matches,
    keypoints1,
    keypoints2,
    config.ransac_iters,
    config.ransac_threshold,
  )
  let homography = ransac_homography(
    matches,
    keypoints1,
    keypoints2,
    config.ransac_iters,
    config.ransac_threshold,
    config.seed,
  )
  {
    keypoints1,
    keypoints2,
    descriptors1,
    descriptors2,
    matches,
    match_stats: match_stats(matches),
    affine,
    homography,
  }
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
  let defaults = FeatureConfig::default()
  let config : FeatureConfig = {
    fast: FastConfig::new(fast_threshold, 9, true, 512, 3, 0.0),
    orb: defaults.orb,
    pyramid_levels: defaults.pyramid_levels,
    match_k: defaults.match_k,
    ratio,
    use_ratio: defaults.use_ratio,
    enforce_unique: defaults.enforce_unique,
    ransac_iters: defaults.ransac_iters,
    ransac_threshold,
    seed: defaults.seed,
  }
  run_pipeline(img1, img2, config).affine
}
