///|
test "keypoint summary and spatial selection are bounded" {
  let keypoints : Array[Keypoint] = [
    Keypoint::new(1, 1, 2.0, 0.0),
    Keypoint::new(8, 1, 4.0, 1.0),
    Keypoint::new(1, 8, 6.0, 2.0),
    Keypoint::new(8, 8, 8.0, 3.0),
  ]
  let summary = summarize_keypoints(keypoints)
  assert_eq(summary.count, 4)
  assert_eq(summary.maximum_response, 8.0)
  assert_true(summary.centroid.x > 4.4 && summary.centroid.x < 4.6)
  let selected = select_keypoints_grid(keypoints, 10, 10, 2, 2, 1)
  assert_eq(selected.length(), 4)
  assert_eq(keypoint_grid_counts(selected, 10, 10, 2, 2).length(), 4)
}

///|
test "keypoint histograms clamp invalid bin parameters" {
  let keypoints : Array[Keypoint] = [
    Keypoint::new(1, 1, 0.0, -1.0),
    Keypoint::new(2, 2, 10.0, 7.0),
  ]
  assert_eq(keypoint_response_histogram(keypoints, 0, 0.0, 10.0).length(), 0)
  assert_eq(keypoint_orientation_histogram(keypoints, 4).length(), 4)
  assert_eq(keypoint_response_histogram(keypoints, 4, 0.0, 10.0)[0], 1)
}

///|
test "descriptor summaries count bits and preserve empty inputs" {
  let first = Descriptor::new(2)
  first.data[0] = (1 : Byte)
  first.data[1] = (255 : Byte)
  let second = Descriptor::new(2)
  second.data[0] = (3 : Byte)
  let stats = summarize_descriptors([first, second])
  assert_eq(stats.count, 2)
  assert_eq(stats.bytes, 2)
  assert_eq(stats.minimum_popcount, 2)
  assert_eq(stats.maximum_popcount, 9)
  assert_eq(descriptor_bit_histogram([first])[0], 1)
  assert_eq(summarize_descriptors([]).count, 0)
}

///|
test "descriptor profiles and patch statistics handle mismatches" {
  let left = Descriptor::new(1)
  left.data[0] = (255 : Byte)
  let right = Descriptor::new(2)
  right.data[0] = (255 : Byte)
  assert_true(descriptors_equal(left, right) is false)
  assert_eq(descriptor_mean_profile([left, right]).length(), 2)
  let image = GrayImage::new(7, 7)
  image.set(3, 3, 20)
  let patch = describe_patch(image, Keypoint::new(3, 3, 1.0, 0.0), 2)
  assert_eq(patch.count, 25)
  assert_true(patch.maximum >= patch.minimum)
}

///|
test "keypoint bounds and scale histogram handle no points" {
  let empty_bounds = keypoint_bounds([])
  assert_eq(empty_bounds.x0, 0)
  assert_eq(empty_bounds.y0, 0)
  assert_eq(empty_bounds.x1, 0)
  assert_eq(empty_bounds.y1, 0)
  assert_eq(keypoint_scale_histogram([], 4).length(), 4)
  assert_eq(keypoint_centroid([]).x, 0.0)
}
