///|
test "match graph statistics count duplicate endpoints" {
  let matches : Array[Match] = [
    Match::new(0, 0, 2),
    Match::new(0, 1, 4),
    Match::new(1, 1, 6),
  ]
  let stats = summarize_match_graph(matches, 3, 3)
  assert_eq(stats.match_count, 3)
  assert_eq(stats.unique_queries, 2)
  assert_eq(stats.unique_trains, 2)
  assert_eq(stats.duplicate_queries, 1)
  assert_eq(stats.duplicate_trains, 1)
  assert_eq(match_distance_histogram(matches, 3, 8)[0], 1)
}

///|
test "match distance percentile and displacement filter are stable" {
  let keypoints1 : Array[Keypoint] = [
    Keypoint::new(0, 0, 1.0, 0.0),
    Keypoint::new(10, 0, 1.0, 0.0),
    Keypoint::new(0, 10, 1.0, 0.0),
  ]
  let keypoints2 : Array[Keypoint] = [
    Keypoint::new(2, 3, 1.0, 0.0),
    Keypoint::new(12, 3, 1.0, 0.0),
    Keypoint::new(30, 30, 1.0, 0.0),
  ]
  let matches : Array[Match] = [
    Match::new(0, 0, 1),
    Match::new(1, 1, 2),
    Match::new(2, 2, 3),
  ]
  assert_eq(match_distance_percentile(matches, 0.5), 2)
  let displacement = median_match_displacement(matches, keypoints1, keypoints2)
  assert_eq(displacement.x, 2.0)
  assert_eq(displacement.y, 3.0)
  assert_eq(
    filter_matches_by_displacement(matches, keypoints1, keypoints2, 1.0).length(),
    2,
  )
}

///|
test "model match quality handles invalid indices" {
  let matches : Array[Match] = [Match::new(0, 9, 1)]
  let keypoints : Array[Keypoint] = [Keypoint::new(0, 0, 1.0, 0.0)]
  let quality = evaluate_affine_matches(
    AffineTransform::identity(),
    matches,
    keypoints,
    keypoints,
    1.0,
  )
  assert_eq(quality.count, 0)
  assert_eq(inlier_mask([1.0, 2.0, 0.5], 1.0).length(), 3)
}

///|
test "descriptor index bucket statistics and match merging are useful" {
  let first = Descriptor::new(1)
  first.data[0] = (1 : Byte)
  let second = Descriptor::new(1)
  second.data[0] = (1 : Byte)
  let index = DescriptorIndex::build([first, second])
  let index_stats = descriptor_index_stats(index)
  assert_eq(index_stats.non_empty_buckets, 1)
  assert_eq(index_stats.maximum_bucket, 2)
  let merged = merge_match_sets([Match::new(0, 0, 4)], [Match::new(0, 0, 2)])
  assert_eq(merged.length(), 1)
  assert_eq(merged[0].distance, 2)
}
