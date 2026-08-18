// Compact quality dashboards for automated consumers of the feature pipeline.

///|
pub(all) struct FeatureQualityReport {
  count : Int
  density : Double
  response_mean : Double
  response_variance : Double
  spatial_coverage : Double
  border_safe : Int
}

///|
pub(all) struct DescriptorQualityReport {
  count : Int
  bytes : Int
  unique : Int
  duplicate_fraction : Double
  bit_balance : Double
  mean_nearest_distance : Double
}

///|
pub(all) struct QualityDashboard {
  image1 : PhotometricReport
  image2 : PhotometricReport
  features1 : FeatureQualityReport
  features2 : FeatureQualityReport
  descriptors1 : DescriptorQualityReport
  descriptors2 : DescriptorQualityReport
  match_graph : MatchGraphStats
  gate : PipelineQualityGate
  fingerprint : Int
}

///|
pub fn feature_quality_report(
  keypoints : Array[Keypoint],
  width : Int,
  height : Int,
  border : Int,
) -> FeatureQualityReport {
  let summary = summarize_keypoints(keypoints)
  let border_size = if border < 0 { 0 } else { border }
  let safe_count = keypoints.length()
  let mut border_safe = 0
  let mut i = 0
  while i < keypoints.length() {
    if keypoints[i].x >= border_size &&
      keypoints[i].y >= border_size &&
      keypoints[i].x < width - border_size &&
      keypoints[i].y < height - border_size {
      border_safe = border_safe + 1
    }
    i = i + 1
  }
  {
    count: safe_count,
    density: feature_density(keypoints, width, height),
    response_mean: summary.mean_response,
    response_variance: keypoint_response_variance(keypoints),
    spatial_coverage: if width <= 0 || height <= 0 {
      0.0
    } else {
      Double::from_int(rect_area(summary.bounds)) /
      Double::from_int(width * height)
    },
    border_safe,
  }
}

///|
pub fn descriptor_quality_report(
  descriptors : Array[Descriptor],
) -> DescriptorQualityReport {
  let summary = summarize_descriptors(descriptors)
  let profile = descriptor_distance_profile(descriptors)
  let mut total_nearest = 0.0
  let mut i = 0
  while i < profile.length() {
    total_nearest = total_nearest + profile[i]
    i = i + 1
  }
  {
    count: summary.count,
    bytes: summary.bytes,
    unique: descriptor_unique_count(descriptors),
    duplicate_fraction: descriptor_duplicate_fraction(descriptors),
    bit_balance: summary.bit_balance,
    mean_nearest_distance: if profile.length() == 0 {
      0.0
    } else {
      total_nearest / Double::from_int(profile.length())
    },
  }
}

///|
fn quality_hash(value : Int, next : Int) -> Int {
  (value * 65599 + next + 17) & 0x7FFFFFFF
}

///|
pub fn pipeline_fingerprint(result : PipelineResult) -> Int {
  let mut fingerprint = 19
  fingerprint = quality_hash(fingerprint, result.keypoints1.length())
  fingerprint = quality_hash(fingerprint, result.keypoints2.length())
  fingerprint = quality_hash(fingerprint, result.descriptors1.length())
  fingerprint = quality_hash(fingerprint, result.descriptors2.length())
  fingerprint = quality_hash(fingerprint, result.matches.length())
  fingerprint = quality_hash(fingerprint, result.homography.inliers.length())
  let mut i = 0
  while i < result.matches.length() {
    fingerprint = quality_hash(fingerprint, result.matches[i].query_idx)
    fingerprint = quality_hash(fingerprint, result.matches[i].train_idx)
    fingerprint = quality_hash(fingerprint, result.matches[i].distance)
    i = i + 1
  }
  fingerprint
}

///|
pub fn build_quality_dashboard(
  image1 : GrayImage,
  image2 : GrayImage,
  result : PipelineResult,
) -> QualityDashboard {
  {
    image1: photometric_report(image1),
    image2: photometric_report(image2),
    features1: feature_quality_report(
      result.keypoints1,
      image1.width,
      image1.height,
      3,
    ),
    features2: feature_quality_report(
      result.keypoints2,
      image2.width,
      image2.height,
      3,
    ),
    descriptors1: descriptor_quality_report(result.descriptors1),
    descriptors2: descriptor_quality_report(result.descriptors2),
    match_graph: summarize_match_graph(
      result.matches,
      result.keypoints1.length(),
      result.keypoints2.length(),
    ),
    gate: pipeline_quality_from_result(result),
    fingerprint: pipeline_fingerprint(result),
  }
}

///|
pub fn format_quality_dashboard(dashboard : QualityDashboard) -> String {
  "fingerprint=\{dashboard.fingerprint} features=\{dashboard.features1.count}/\{dashboard.features2.count} unique_descriptors=\{dashboard.descriptors1.unique}/\{dashboard.descriptors2.unique} matches=\{dashboard.match_graph.match_count} inlier_ratio=\{dashboard.gate.inlier_ratio} passed=\{dashboard.gate.passed}"
}

///|
pub fn validate_descriptor_set(
  descriptors : Array[Descriptor],
  expected_bytes : Int,
) -> Bool {
  if expected_bytes < 0 {
    return false
  }
  let mut i = 0
  while i < descriptors.length() {
    if descriptors[i].data.length() != expected_bytes {
      return false
    }
    i = i + 1
  }
  true
}

///|
pub fn validate_match_indices(
  matches : Array[Match],
  query_count : Int,
  train_count : Int,
) -> Bool {
  let mut i = 0
  while i < matches.length() {
    if matches[i].query_idx < 0 ||
      matches[i].query_idx >= query_count ||
      matches[i].train_idx < 0 ||
      matches[i].train_idx >= train_count {
      return false
    }
    i = i + 1
  }
  true
}

///|
pub fn quality_gate_score(result : PipelineResult) -> Double {
  pipeline_quality_from_result(result).score
}

///|
pub fn quality_dashboard_is_reproducible(
  first : QualityDashboard,
  second : QualityDashboard,
) -> Bool {
  first.fingerprint == second.fingerprint &&
  first.match_graph.match_count == second.match_graph.match_count &&
  first.gate.passed == second.gate.passed
}

///|
pub(all) struct ThresholdTrial {
  threshold : Int
  keypoints : Int
  descriptors : Int
  mean_response : Double
  score : Double
}

///|
pub fn evaluate_fast_thresholds(
  img : GrayImage,
  thresholds : Array[Int],
) -> Array[ThresholdTrial] {
  let result : Array[ThresholdTrial] = []
  let mut i = 0
  while i < thresholds.length() {
    let config = FastConfig::new(thresholds[i], 9, true, 0, 3, 0.0)
    let keypoints = detect_fast_with_config(img, config)
    let summary = summarize_keypoints(keypoints)
    let score = if keypoints.length() == 0 {
      0.0
    } else {
      summary.mean_response / (1.0 + Double::from_int(keypoints.length()))
    }
    result.push({
      threshold: thresholds[i],
      keypoints: keypoints.length(),
      descriptors: keypoints.length(),
      mean_response: summary.mean_response,
      score,
    })
    i = i + 1
  }
  result
}

///|
pub fn choose_fast_threshold(
  trials : Array[ThresholdTrial],
  minimum_keypoints : Int,
) -> Int? {
  let mut found = false
  let mut best_threshold = 0
  let mut best_score = -1.0
  let minimum = if minimum_keypoints < 0 { 0 } else { minimum_keypoints }
  let mut i = 0
  while i < trials.length() {
    if trials[i].keypoints >= minimum &&
      (!found || trials[i].score > best_score) {
      found = true
      best_threshold = trials[i].threshold
      best_score = trials[i].score
    }
    i = i + 1
  }
  if found {
    Some(best_threshold)
  } else {
    None
  }
}

///|
pub fn feature_response_curve(
  img : GrayImage,
  thresholds : Array[Int],
) -> Array[Double] {
  let trials = evaluate_fast_thresholds(img, thresholds)
  let result = Array::make(trials.length(), 0.0)
  let mut i = 0
  while i < trials.length() {
    result[i] = trials[i].mean_response
    i = i + 1
  }
  result
}

///|
pub fn match_quality_curve(
  matches : Array[Match],
  thresholds : Array[Int],
) -> Array[Double] {
  let result = Array::make(thresholds.length(), 0.0)
  let mut i = 0
  while i < thresholds.length() {
    let mut count = 0
    let mut j = 0
    while j < matches.length() {
      if matches[j].distance <= thresholds[i] {
        count = count + 1
      }
      j = j + 1
    }
    result[i] = if matches.length() == 0 {
      0.0
    } else {
      Double::from_int(count) / Double::from_int(matches.length())
    }
    i = i + 1
  }
  result
}

///|
pub fn quality_weighted_match_score(
  matches : Array[Match],
  maximum_distance : Int,
) -> Double {
  if matches.length() == 0 || maximum_distance <= 0 {
    return 0.0
  }
  let mut total = 0.0
  let mut i = 0
  while i < matches.length() {
    let normalized = Double::from_int(matches[i].distance) /
      Double::from_int(maximum_distance)
    total = total + (if normalized > 1.0 { 0.0 } else { 1.0 - normalized })
    i = i + 1
  }
  total / Double::from_int(matches.length())
}

///|
pub fn clamp_quality(value : Double) -> Double {
  if value < 0.0 {
    0.0
  } else if value > 1.0 {
    1.0
  } else {
    value
  }
}

///|
pub fn quality_score_from_counts(
  true_positive : Int,
  false_positive : Int,
  false_negative : Int,
) -> Double {
  let tp = if true_positive < 0 { 0 } else { true_positive }
  let fp = if false_positive < 0 { 0 } else { false_positive }
  let fn_count = if false_negative < 0 { 0 } else { false_negative }
  let precision_denominator = tp + fp
  let recall_denominator = tp + fn_count
  let precision = if precision_denominator == 0 {
    0.0
  } else {
    Double::from_int(tp) / Double::from_int(precision_denominator)
  }
  let recall = if recall_denominator == 0 {
    0.0
  } else {
    Double::from_int(tp) / Double::from_int(recall_denominator)
  }
  if precision + recall == 0.0 {
    0.0
  } else {
    2.0 * precision * recall / (precision + recall)
  }
}

///|
pub fn threshold_trial_area(trials : Array[ThresholdTrial]) -> Double {
  if trials.length() < 2 {
    return 0.0
  }
  let mut area = 0.0
  let mut i = 1
  while i < trials.length() {
    let width = Double::from_int(trials[i].threshold - trials[i - 1].threshold)
    area = area + width * (trials[i].score + trials[i - 1].score) / 2.0
    i = i + 1
  }
  if area < 0.0 {
    -area
  } else {
    area
  }
}

///|
pub fn best_threshold_trial(trials : Array[ThresholdTrial]) -> ThresholdTrial? {
  if trials.length() == 0 {
    return None
  }
  let mut best = trials[0]
  let mut i = 1
  while i < trials.length() {
    if trials[i].score > best.score ||
      (trials[i].score == best.score && trials[i].threshold < best.threshold) {
      best = trials[i]
    }
    i = i + 1
  }
  Some(best)
}

///|
pub fn dashboard_score(dashboard : QualityDashboard) -> Double {
  let feature_balance = if dashboard.features1.count == 0 &&
    dashboard.features2.count == 0 {
    1.0
  } else {
    let low = if dashboard.features1.count < dashboard.features2.count {
      dashboard.features1.count
    } else {
      dashboard.features2.count
    }
    let high = if dashboard.features1.count > dashboard.features2.count {
      dashboard.features1.count
    } else {
      dashboard.features2.count
    }
    if high == 0 {
      0.0
    } else {
      Double::from_int(low) / Double::from_int(high)
    }
  }
  clamp_quality(feature_balance * dashboard.gate.score)
}

///|
pub fn dashboard_match_density(dashboard : QualityDashboard) -> Double {
  if dashboard.match_graph.query_nodes <= 0 {
    0.0
  } else {
    Double::from_int(dashboard.match_graph.match_count) /
    Double::from_int(dashboard.match_graph.query_nodes)
  }
}

///|
pub fn dashboard_descriptor_balance(dashboard : QualityDashboard) -> Double {
  let first = dashboard.descriptors1.count
  let second = dashboard.descriptors2.count
  if first == 0 && second == 0 {
    1.0
  } else {
    let low = if first < second { first } else { second }
    let high = if first > second { first } else { second }
    if high == 0 {
      0.0
    } else {
      Double::from_int(low) / Double::from_int(high)
    }
  }
}

///|
pub fn dashboard_pass_rate(dashboards : Array[QualityDashboard]) -> Double {
  if dashboards.length() == 0 {
    return 0.0
  }
  let mut passed = 0
  let mut i = 0
  while i < dashboards.length() {
    if dashboards[i].gate.passed {
      passed = passed + 1
    }
    i = i + 1
  }
  Double::from_int(passed) / Double::from_int(dashboards.length())
}
