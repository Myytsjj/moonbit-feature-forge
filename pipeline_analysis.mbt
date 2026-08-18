// Pipeline-level reports, benchmark aggregation, and release-quality gates.

///|
pub(all) struct BenchmarkAggregate {
  count : Int
  total_iterations : Int
  total_features1 : Int
  total_features2 : Int
  total_matches : Int
  mean_features1 : Double
  mean_features2 : Double
  mean_matches : Double
  mean_inlier_ratio : Double
  minimum_ms : Double
  maximum_ms : Double
  mean_ms : Double
}

///|
pub fn aggregate_benchmarks(
  samples : Array[BenchmarkResult],
) -> BenchmarkAggregate {
  if samples.length() == 0 {
    return {
      count: 0,
      total_iterations: 0,
      total_features1: 0,
      total_features2: 0,
      total_matches: 0,
      mean_features1: 0.0,
      mean_features2: 0.0,
      mean_matches: 0.0,
      mean_inlier_ratio: 0.0,
      minimum_ms: 0.0,
      maximum_ms: 0.0,
      mean_ms: 0.0,
    }
  }
  let mut total_iterations = 0
  let mut total_features1 = 0
  let mut total_features2 = 0
  let mut total_matches = 0
  let mut total_ratio = 0.0
  let mut total_ms = 0.0
  let mut minimum_ms = samples[0].total_ms
  let mut maximum_ms = samples[0].total_ms
  let mut i = 0
  while i < samples.length() {
    let sample = samples[i]
    total_iterations = total_iterations + sample.iterations
    total_features1 = total_features1 + sample.features1
    total_features2 = total_features2 + sample.features2
    total_matches = total_matches + sample.matches
    total_ratio = total_ratio + sample.inlier_ratio
    total_ms = total_ms + sample.total_ms
    if sample.total_ms < minimum_ms {
      minimum_ms = sample.total_ms
    }
    if sample.total_ms > maximum_ms {
      maximum_ms = sample.total_ms
    }
    i = i + 1
  }
  let count = Double::from_int(samples.length())
  {
    count: samples.length(),
    total_iterations,
    total_features1,
    total_features2,
    total_matches,
    mean_features1: Double::from_int(total_features1) / count,
    mean_features2: Double::from_int(total_features2) / count,
    mean_matches: Double::from_int(total_matches) / count,
    mean_inlier_ratio: total_ratio / count,
    minimum_ms,
    maximum_ms,
    mean_ms: total_ms / count,
  }
}

///|
pub fn benchmark_throughput(aggregate : BenchmarkAggregate) -> Double {
  if aggregate.count == 0 || aggregate.mean_ms <= 0.0 {
    0.0
  } else {
    Double::from_int(aggregate.total_iterations) *
    1000.0 /
    (aggregate.mean_ms * Double::from_int(aggregate.count))
  }
}

///|
pub fn benchmark_average_latency(aggregate : BenchmarkAggregate) -> Double {
  if aggregate.total_iterations <= 0 {
    0.0
  } else {
    aggregate.mean_ms / Double::from_int(aggregate.total_iterations)
  }
}

///|
pub fn benchmark_speedup(
  baseline : BenchmarkAggregate,
  candidate : BenchmarkAggregate,
) -> Double {
  if candidate.mean_ms <= 0.0 {
    0.0
  } else {
    baseline.mean_ms / candidate.mean_ms
  }
}

///|
pub fn format_benchmark_aggregate(aggregate : BenchmarkAggregate) -> String {
  "samples=\{aggregate.count} iterations=\{aggregate.total_iterations} mean_features1=\{aggregate.mean_features1} mean_features2=\{aggregate.mean_features2} mean_matches=\{aggregate.mean_matches} mean_ms=\{aggregate.mean_ms} throughput=\{benchmark_throughput(aggregate)}"
}

///|
pub(all) struct PhotometricReport {
  width : Int
  height : Int
  mean : Double
  variance : Double
  minimum : Int
  maximum : Int
  nonzero : Int
  contrast : Double
}

///|
pub fn photometric_report(img : GrayImage) -> PhotometricReport {
  let moments = image_moments(img)
  let mut nonzero = 0
  let mut i = 0
  while i < img.data.length() {
    if img.data[i] > 0 {
      nonzero = nonzero + 1
    }
    i = i + 1
  }
  {
    width: img.width,
    height: img.height,
    mean: moments.0,
    variance: moments.1,
    minimum: moments.2,
    maximum: moments.3,
    nonzero,
    contrast: Double::from_int(moments.3 - moments.2),
  }
}

///|
pub(all) struct PhotometricComparison {
  overlap_width : Int
  overlap_height : Int
  mse : Double
  mean_difference : Double
  foreground_iou : Double
}

///|
pub fn compare_photometric(
  left : GrayImage,
  right : GrayImage,
) -> PhotometricComparison {
  let width = if left.width < right.width { left.width } else { right.width }
  let height = if left.height < right.height {
    left.height
  } else {
    right.height
  }
  let left_report = photometric_report(left)
  let right_report = photometric_report(right)
  {
    overlap_width: width,
    overlap_height: height,
    mse: image_mse(left, right),
    mean_difference: left_report.mean - right_report.mean,
    foreground_iou: binary_iou(left, right),
  }
}

///|
pub fn image_similarity(left : GrayImage, right : GrayImage) -> Double {
  let mse = image_mse(left, right)
  if mse <= 0.0 {
    1.0
  } else {
    1.0 / (1.0 + mse)
  }
}

///|
pub(all) struct PipelineQualityGate {
  passed : Bool
  inlier_ratio : Double
  inlier_count : Int
  match_count : Int
  maximum_error : Double
  score : Double
}

///|
pub fn pipeline_quality_gate(
  inlier_ratio : Double,
  inlier_count : Int,
  match_count : Int,
  maximum_error : Double,
) -> PipelineQualityGate {
  let ratio = if inlier_ratio < 0.0 {
    0.0
  } else if inlier_ratio > 1.0 {
    1.0
  } else {
    inlier_ratio
  }
  let safe_inliers = if inlier_count < 0 { 0 } else { inlier_count }
  let safe_matches = if match_count < 0 { 0 } else { match_count }
  let safe_error = if maximum_error < 0.0 { 0.0 } else { maximum_error }
  let ratio_score = ratio
  let count_score = if safe_inliers >= 20 {
    1.0
  } else {
    Double::from_int(safe_inliers) / 20.0
  }
  let error_score = 1.0 / (1.0 + safe_error)
  let score = ratio_score * count_score * error_score
  {
    passed: ratio >= 0.5 &&
    safe_inliers >= 3 &&
    safe_matches > 0 &&
    safe_error <= 3.0,
    inlier_ratio: ratio,
    inlier_count: safe_inliers,
    match_count: safe_matches,
    maximum_error: safe_error,
    score,
  }
}

///|
pub fn format_quality_gate(gate : PipelineQualityGate) -> String {
  let status = if gate.passed { "passed" } else { "failed" }
  "quality=\{status} ratio=\{gate.inlier_ratio} inliers=\{gate.inlier_count} matches=\{gate.match_count} max_error=\{gate.maximum_error} score=\{gate.score}"
}

///|
pub(all) struct PyramidSummary {
  levels : Int
  original_width : Int
  original_height : Int
  final_width : Int
  final_height : Int
  final_scale : Double
}

///|
pub fn summarize_pyramid(pyramid : ImagePyramid) -> PyramidSummary {
  let levels = pyramid.level_count()
  if levels == 0 {
    return {
      levels: 0,
      original_width: 0,
      original_height: 0,
      final_width: 0,
      final_height: 0,
      final_scale: 0.0,
    }
  }
  let first = pyramid.level(0)
  let last = pyramid.level(levels - 1)
  {
    levels,
    original_width: first.width,
    original_height: first.height,
    final_width: last.width,
    final_height: last.height,
    final_scale: pyramid.scale(levels - 1),
  }
}

///|
pub fn pyramid_pixel_capacity(pyramid : ImagePyramid) -> Int {
  let mut total = 0
  let mut i = 0
  while i < pyramid.level_count() {
    let level = pyramid.level(i)
    total = total + level.width * level.height
    i = i + 1
  }
  total
}

///|
pub fn feature_density(
  keypoints : Array[Keypoint],
  width : Int,
  height : Int,
) -> Double {
  if width <= 0 || height <= 0 {
    0.0
  } else {
    Double::from_int(keypoints.length()) / Double::from_int(width * height)
  }
}

///|
pub fn match_coverage(
  matches : Array[Match],
  query_count : Int,
  train_count : Int,
) -> Double {
  if query_count <= 0 || train_count <= 0 {
    return 0.0
  }
  let graph = summarize_match_graph(matches, query_count, train_count)
  let query_coverage = Double::from_int(graph.unique_queries) /
    Double::from_int(query_count)
  let train_coverage = Double::from_int(graph.unique_trains) /
    Double::from_int(train_count)
  if query_coverage < train_coverage {
    query_coverage
  } else {
    train_coverage
  }
}

///|
pub(all) struct PipelineReport {
  features1 : KeypointStats
  features2 : KeypointStats
  descriptors1 : DescriptorStats
  descriptors2 : DescriptorStats
  matches : MatchGraphStats
  affine_quality : MatchQuality
  homography_quality : MatchQuality
  gate : PipelineQualityGate
}

///|
pub fn analyze_pipeline(result : PipelineResult) -> PipelineReport {
  let feature1 = summarize_keypoints(result.keypoints1)
  let feature2 = summarize_keypoints(result.keypoints2)
  let descriptor1 = summarize_descriptors(result.descriptors1)
  let descriptor2 = summarize_descriptors(result.descriptors2)
  let graph = summarize_match_graph(
    result.matches,
    result.keypoints1.length(),
    result.keypoints2.length(),
  )
  let affine = evaluate_affine_matches(
    result.affine.transform,
    result.matches,
    result.keypoints1,
    result.keypoints2,
    3.0,
  )
  let homography = evaluate_homography_matches(
    result.homography.model,
    result.matches,
    result.keypoints1,
    result.keypoints2,
    3.0,
  )
  let gate = pipeline_quality_gate(
    result.homography.inlier_ratio,
    result.homography.inliers.length(),
    result.matches.length(),
    result.homography.stats.maximum,
  )
  {
    features1: feature1,
    features2: feature2,
    descriptors1: descriptor1,
    descriptors2: descriptor2,
    matches: graph,
    affine_quality: affine,
    homography_quality: homography,
    gate,
  }
}

///|
pub fn format_pipeline_report(report : PipelineReport) -> String {
  "features1=\{report.features1.count} features2=\{report.features2.count} descriptors1=\{report.descriptors1.bytes} descriptors2=\{report.descriptors2.bytes} matches=\{report.matches.match_count} coverage=\{report.matches.unique_queries}/\{report.matches.query_nodes} affine_ratio=\{report.affine_quality.ratio} homography_ratio=\{report.homography_quality.ratio} \{format_quality_gate(report.gate)}"
}

///|
pub fn pipeline_quality_from_result(
  result : PipelineResult,
) -> PipelineQualityGate {
  pipeline_quality_gate(
    result.homography.inlier_ratio,
    result.homography.inliers.length(),
    result.matches.length(),
    result.homography.stats.maximum,
  )
}

///|
pub fn pipeline_is_usable(result : PipelineResult) -> Bool {
  pipeline_quality_from_result(result).passed
}

///|
pub fn pipeline_feature_balance(result : PipelineResult) -> Double {
  let first = result.keypoints1.length()
  let second = result.keypoints2.length()
  if first == 0 && second == 0 {
    return 1.0
  }
  let low = if first < second { first } else { second }
  let high = if first > second { first } else { second }
  if high == 0 {
    0.0
  } else {
    Double::from_int(low) / Double::from_int(high)
  }
}

///|
pub fn pipeline_descriptor_balance(result : PipelineResult) -> Double {
  let first = result.descriptors1.length()
  let second = result.descriptors2.length()
  if first == 0 && second == 0 {
    return 1.0
  }
  let low = if first < second { first } else { second }
  let high = if first > second { first } else { second }
  if high == 0 {
    0.0
  } else {
    Double::from_int(low) / Double::from_int(high)
  }
}

///|
pub fn pipeline_inlier_distance(result : PipelineResult) -> Double {
  if result.homography.inliers.length() == 0 {
    0.0
  } else {
    result.homography.stats.mean
  }
}

///|
pub fn pipeline_summary_lines(result : PipelineResult) -> Array[String] {
  let report = analyze_pipeline(result)
  [
    "features=\{report.features1.count}/\{report.features2.count}",
    "descriptors=\{report.descriptors1.bytes}/\{report.descriptors2.bytes} bytes",
    "matches=\{report.matches.match_count} unique=\{report.matches.unique_queries}/\{report.matches.unique_trains}",
    "homography=\{report.homography_quality.inliers}/\{report.homography_quality.count} mean_error=\{report.homography_quality.mean_residual}",
    format_quality_gate(report.gate),
  ]
}

///|
pub fn benchmark_results_are_comparable(
  left : BenchmarkResult,
  right : BenchmarkResult,
) -> Bool {
  left.width == right.width &&
  left.height == right.height &&
  left.iterations > 0 &&
  right.iterations > 0
}

///|
pub fn benchmark_relative_latency(
  left : BenchmarkResult,
  right : BenchmarkResult,
) -> Double {
  if right.total_ms <= 0.0 {
    0.0
  } else {
    left.total_ms / right.total_ms
  }
}

///|
pub fn benchmark_feature_rate(result : BenchmarkResult) -> Double {
  if result.total_ms <= 0.0 {
    0.0
  } else {
    Double::from_int(result.features1 + result.features2) *
    1000.0 /
    result.total_ms
  }
}

///|
pub fn benchmark_match_rate(result : BenchmarkResult) -> Double {
  if result.total_ms <= 0.0 {
    0.0
  } else {
    Double::from_int(result.matches) * 1000.0 / result.total_ms
  }
}
