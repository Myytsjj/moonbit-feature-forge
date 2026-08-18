// Public-input validation and compact snapshots for integration tests and
// application telemetry. No file or network I/O is hidden in these helpers.

///|
pub(all) struct FeatureSnapshot {
  keypoints : Int
  descriptors : Int
  descriptor_bytes : Int
  mean_response : Double
  bounds : Rect
  fingerprint : Int
}

///|
pub(all) struct SnapshotDelta {
  keypoints : Int
  descriptors : Int
  descriptor_bytes : Int
  response_delta : Double
  same_shape : Bool
}

///|
pub fn snapshot_features(
  keypoints : Array[Keypoint],
  descriptors : Array[Descriptor],
) -> FeatureSnapshot {
  let keypoint_summary = summarize_keypoints(keypoints)
  let descriptor_summary = summarize_descriptors(descriptors)
  let mut fingerprint = 29
  fingerprint = (fingerprint * 31 + keypoints.length()) & 0x7FFFFFFF
  fingerprint = (fingerprint * 31 + descriptors.length()) & 0x7FFFFFFF
  let mut i = 0
  while i < descriptors.length() {
    fingerprint = (fingerprint * 31 + descriptor_checksum(descriptors[i])) &
      0x7FFFFFFF
    i = i + 1
  }
  {
    keypoints: keypoints.length(),
    descriptors: descriptors.length(),
    descriptor_bytes: descriptor_summary.bytes,
    mean_response: keypoint_summary.mean_response,
    bounds: keypoint_summary.bounds,
    fingerprint,
  }
}

///|
pub fn compare_snapshots(
  left : FeatureSnapshot,
  right : FeatureSnapshot,
) -> SnapshotDelta {
  {
    keypoints: right.keypoints - left.keypoints,
    descriptors: right.descriptors - left.descriptors,
    descriptor_bytes: right.descriptor_bytes - left.descriptor_bytes,
    response_delta: right.mean_response - left.mean_response,
    same_shape: left.keypoints == right.keypoints &&
    left.descriptors == right.descriptors,
  }
}

///|
pub fn format_feature_snapshot(snapshot : FeatureSnapshot) -> String {
  "keypoints=\{snapshot.keypoints} descriptors=\{snapshot.descriptors} bytes=\{snapshot.descriptor_bytes} mean_response=\{snapshot.mean_response} fingerprint=\{snapshot.fingerprint}"
}

///|
pub fn validate_image_shape(img : GrayImage) -> Bool {
  img.width >= 0 &&
  img.height >= 0 &&
  img.data.length() == img.width * img.height
}

///|
pub fn validate_image_bytes(img : GrayImage) -> Bool {
  let mut i = 0
  while i < img.data.length() {
    if img.data[i] < 0 || img.data[i] > 255 {
      return false
    }
    i = i + 1
  }
  true
}

///|
pub fn validate_keypoints(
  keypoints : Array[Keypoint],
  width : Int,
  height : Int,
) -> Bool {
  let mut i = 0
  while i < keypoints.length() {
    if keypoints[i].x < 0 ||
      keypoints[i].x >= width ||
      keypoints[i].y < 0 ||
      keypoints[i].y >= height ||
      keypoints[i].size < 0 {
      return false
    }
    i = i + 1
  }
  true
}

///|
pub fn validate_descriptor_lengths(descriptors : Array[Descriptor]) -> Bool {
  if descriptors.length() < 2 {
    return true
  }
  let length = descriptors[0].data.length()
  let mut i = 1
  while i < descriptors.length() {
    if descriptors[i].data.length() != length {
      return false
    }
    i = i + 1
  }
  true
}

///|
pub fn validate_pipeline_result(result : PipelineResult) -> Bool {
  result.keypoints1.length() == result.descriptors1.length() &&
  result.keypoints2.length() == result.descriptors2.length() &&
  validate_match_indices(
    result.matches,
    result.descriptors1.length(),
    result.descriptors2.length(),
  ) &&
  validate_descriptor_lengths(result.descriptors1) &&
  validate_descriptor_lengths(result.descriptors2)
}

///|
pub fn pipeline_invariant_report(result : PipelineResult) -> Array[String] {
  let issues : Array[String] = []
  if result.keypoints1.length() != result.descriptors1.length() {
    issues.push("image1 feature/descriptor count mismatch")
  }
  if result.keypoints2.length() != result.descriptors2.length() {
    issues.push("image2 feature/descriptor count mismatch")
  }
  if !validate_match_indices(
      result.matches,
      result.descriptors1.length(),
      result.descriptors2.length(),
    ) {
    issues.push("match index out of range")
  }
  if !validate_descriptor_lengths(result.descriptors1) {
    issues.push("image1 descriptor lengths differ")
  }
  if !validate_descriptor_lengths(result.descriptors2) {
    issues.push("image2 descriptor lengths differ")
  }
  if result.homography.inlier_ratio < 0.0 ||
    result.homography.inlier_ratio > 1.0 {
    issues.push("homography ratio outside [0,1]")
  }
  issues
}

///|
pub fn format_snapshot_delta(delta : SnapshotDelta) -> String {
  "delta_keypoints=\{delta.keypoints} delta_descriptors=\{delta.descriptors} delta_bytes=\{delta.descriptor_bytes} delta_response=\{delta.response_delta} same_shape=\{delta.same_shape}"
}

///|
pub fn safe_match_ratio(matches : Array[Match], query_count : Int) -> Double {
  if query_count <= 0 {
    0.0
  } else {
    let ratio = Double::from_int(matches.length()) /
      Double::from_int(query_count)
    if ratio > 1.0 {
      1.0
    } else if ratio < 0.0 {
      0.0
    } else {
      ratio
    }
  }
}

///|
pub fn safe_inlier_ratio(inliers : Int, matches : Int) -> Double {
  if matches <= 0 || inliers <= 0 {
    0.0
  } else {
    let ratio = Double::from_int(inliers) / Double::from_int(matches)
    if ratio > 1.0 {
      1.0
    } else {
      ratio
    }
  }
}

///|
pub fn feature_count_difference(
  left : Array[Keypoint],
  right : Array[Keypoint],
) -> Int {
  left.length() - right.length()
}

///|
pub fn descriptor_count_difference(
  left : Array[Descriptor],
  right : Array[Descriptor],
) -> Int {
  left.length() - right.length()
}

///|
pub fn stable_descriptor_bytes(descriptors : Array[Descriptor]) -> Int {
  let mut bytes = 0
  let mut i = 0
  while i < descriptors.length() {
    if descriptors[i].data.length() > bytes {
      bytes = descriptors[i].data.length()
    }
    i = i + 1
  }
  bytes
}

///|
pub fn result_fingerprint(result : PipelineResult) -> Int {
  let snapshot1 = snapshot_features(result.keypoints1, result.descriptors1)
  let snapshot2 = snapshot_features(result.keypoints2, result.descriptors2)
  let mut fingerprint = snapshot1.fingerprint
  fingerprint = (fingerprint * 31 + snapshot2.fingerprint) & 0x7FFFFFFF
  fingerprint = (fingerprint * 31 + result.matches.length()) & 0x7FFFFFFF
  fingerprint = (fingerprint * 31 + result.homography.inliers.length()) &
    0x7FFFFFFF
  fingerprint
}

///|
pub fn results_have_same_shape(
  left : PipelineResult,
  right : PipelineResult,
) -> Bool {
  left.keypoints1.length() == right.keypoints1.length() &&
  left.keypoints2.length() == right.keypoints2.length() &&
  left.descriptors1.length() == right.descriptors1.length() &&
  left.descriptors2.length() == right.descriptors2.length() &&
  left.matches.length() == right.matches.length()
}

///|
pub fn result_delta_summary(
  left : PipelineResult,
  right : PipelineResult,
) -> String {
  let first = snapshot_features(left.keypoints1, left.descriptors1)
  let second = snapshot_features(right.keypoints1, right.descriptors1)
  format_snapshot_delta(compare_snapshots(first, second))
}

///|
pub fn format_rect(rect : Rect) -> String {
  "rect=\{rect.x0},\{rect.y0},\{rect.x1},\{rect.y1}"
}

///|
pub fn format_point(point : FloatPoint2) -> String {
  "point=\{point.x},\{point.y}"
}

///|
pub fn format_keypoint(keypoint : Keypoint) -> String {
  "keypoint=\{keypoint.x},\{keypoint.y} response=\{keypoint.response} angle=\{keypoint.angle} octave=\{keypoint.octave} size=\{keypoint.size}"
}

///|
pub fn validate_regions(
  regions : Array[RegionStats],
  width : Int,
  height : Int,
) -> Bool {
  let mut i = 0
  while i < regions.length() {
    let region = regions[i]
    if region.label <= 0 ||
      region.area <= 0 ||
      region.bounds.x0 < 0 ||
      region.bounds.y0 < 0 ||
      region.bounds.x1 > width ||
      region.bounds.y1 > height ||
      region.bounds.x1 <= region.bounds.x0 ||
      region.bounds.y1 <= region.bounds.y0 {
      return false
    }
    i = i + 1
  }
  true
}

///|
pub fn validate_tracks(tracks : Array[FeatureTrack]) -> Bool {
  let mut i = 0
  while i < tracks.length() {
    if tracks[i].id < 0 ||
      tracks[i].age < 0 ||
      tracks[i].missed < 0 ||
      tracks[i].keypoints.length() != tracks[i].descriptors.length() {
      return false
    }
    i = i + 1
  }
  true
}

///|
pub fn report_is_empty(report : PipelineReport) -> Bool {
  report.features1.count == 0 &&
  report.features2.count == 0 &&
  report.matches.match_count == 0
}

///|
pub fn dashboard_is_valid(dashboard : QualityDashboard) -> Bool {
  dashboard.features1.count >= 0 &&
  dashboard.features2.count >= 0 &&
  dashboard.descriptors1.count >= 0 &&
  dashboard.descriptors2.count >= 0 &&
  dashboard.match_graph.match_count >= 0 &&
  dashboard.gate.inlier_ratio >= 0.0 &&
  dashboard.gate.inlier_ratio <= 1.0
}

///|
pub fn ratio_difference(left : Double, right : Double) -> Double {
  if left > right {
    left - right
  } else {
    right - left
  }
}

///|
pub fn counts_are_nonnegative(values : Array[Int]) -> Bool {
  let mut i = 0
  while i < values.length() {
    if values[i] < 0 {
      return false
    }
    i = i + 1
  }
  true
}

///|
pub fn bounds_are_ordered(rect : Rect) -> Bool {
  rect.x1 >= rect.x0 && rect.y1 >= rect.y0
}

///|
pub fn image_area(img : GrayImage) -> Int {
  if img.width <= 0 || img.height <= 0 {
    0
  } else {
    img.width * img.height
  }
}

///|
pub fn image_has_pixels(img : GrayImage) -> Bool {
  image_area(img) > 0 && img.data.length() > 0
}
