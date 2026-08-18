///|
test "quality reports validate empty and bounded inputs" {
  let image = GrayImage::new(10, 10)
  let feature_report = feature_quality_report([], 10, 10, 3)
  assert_eq(feature_report.count, 0)
  assert_eq(feature_report.border_safe, 0)
  assert_eq(descriptor_quality_report([]).count, 0)
  assert_true(validate_image_shape(image))
  assert_true(validate_image_bytes(image))
  assert_true(validate_keypoints([], 10, 10))
  assert_true(validate_descriptor_lengths([]))
  assert_true(bounds_are_ordered(Rect::new(0, 0, 1, 1)))
}

///|
test "threshold trials and quality curves are deterministic" {
  let image = GrayImage::new(40, 40)
  image.set(20, 20, 255)
  let trials = evaluate_fast_thresholds(image, [10, 20, 30])
  assert_eq(trials.length(), 3)
  assert_true(feature_response_curve(image, [10, 20]).length() == 2)
  let selected = choose_fast_threshold(trials, 0)
  assert_true(selected is Some(_))
  assert_true(match_quality_curve([Match::new(0, 0, 2)], [1, 2])[1] == 1.0)
  assert_true(
    quality_score_from_counts(2, 1, 1) > 0.66 &&
    quality_score_from_counts(2, 1, 1) < 0.67,
  )
}
