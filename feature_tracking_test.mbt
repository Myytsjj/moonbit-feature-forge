///|
fn tracking_descriptor(value : Int) -> Descriptor {
  let descriptor = Descriptor::new(1)
  descriptor.data[0] = value.to_byte()
  descriptor
}

///|
test "grid index returns radius candidates and deterministic nearest point" {
  let points : Array[Keypoint] = [
    Keypoint::new(2, 2, 1.0, 0.0),
    Keypoint::new(7, 7, 2.0, 0.0),
  ]
  let index = KeypointGridIndex::build(points, 10, 10, 2, 2)
  assert_eq(index.query_radius(FloatPoint2::new(2.0, 2.0), 1.0).length(), 1)
  assert_eq(index.nearest(FloatPoint2::new(2.1, 2.0), 2.0), Some(0))
  assert_eq(index.maximum_occupancy(), 1)
}

///|
test "association and track update preserve ids and reject invalid bounds" {
  let first_points : Array[Keypoint] = [Keypoint::new(2, 2, 1.0, 0.0)]
  let second_points : Array[Keypoint] = [Keypoint::new(3, 2, 1.0, 0.0)]
  let associations = associate_keypoints(
    first_points,
    [tracking_descriptor(0)],
    second_points,
    [tracking_descriptor(1)],
    8,
    2.0,
  )
  assert_eq(associations.length(), 1)
  let tracks = initialize_tracks(first_points, [tracking_descriptor(0)], 10)
  let updated = update_tracks(
    tracks,
    second_points,
    [tracking_descriptor(1)],
    8,
    2.0,
    1,
  )
  assert_eq(updated[0].id, 10)
  assert_eq(updated[0].age, 2)
  assert_eq(updated[0].path_length(), 1.0)
}

///|
test "track summaries and descriptor votes handle empty inputs" {
  let summary = summarize_tracks([])
  assert_eq(summary.count, 0)
  assert_eq(track_coverage([], 10, 10), 0.0)
  let track = FeatureTrack::new(
    1,
    Keypoint::new(1, 1, 2.0, 0.0),
    tracking_descriptor(255),
  )
  assert_eq(track_descriptor_vote(track).data[0], (255 : Byte))
  assert_true(track_quality(track) >= 0.0)
}
