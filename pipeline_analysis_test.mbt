///|
test "benchmark aggregation handles empty and repeated samples" {
  let empty = aggregate_benchmarks([])
  assert_eq(empty.count, 0)
  let samples : Array[BenchmarkResult] = [
    BenchmarkResult::new(10, 10, 1, 4, 4, 3, 0.5, 10.0),
    BenchmarkResult::new(10, 10, 1, 6, 5, 4, 1.0, 20.0),
  ]
  let aggregate = aggregate_benchmarks(samples)
  assert_eq(aggregate.count, 2)
  assert_eq(aggregate.total_iterations, 2)
  assert_eq(aggregate.minimum_ms, 10.0)
  assert_eq(aggregate.maximum_ms, 20.0)
  assert_eq(aggregate.mean_ms, 15.0)
  assert_true(
    benchmark_throughput(aggregate) > 66.6 &&
    benchmark_throughput(aggregate) < 66.7,
  )
}

///|
test "pipeline reports and gates remain deterministic" {
  let image = GrayImage::new(12, 12)
  let report = photometric_report(image)
  assert_eq(report.width, 12)
  assert_eq(report.mean, 0.0)
  let gate = pipeline_quality_gate(0.8, 4, 3, 1.0)
  assert_true(gate.passed)
  assert_true(pipeline_quality_gate(0.1, 1, 0, 1.0).passed is false)
  let pyramid = ImagePyramid::build(image, 3)
  let summary = summarize_pyramid(pyramid)
  assert_eq(summary.levels, 3)
  assert_true(format_quality_gate(gate).length() > 0)
}
