///|
fn descriptor_with_byte(value : Int) -> Descriptor {
  let descriptor = Descriptor::new(1)
  descriptor.data[0] = value.to_byte()
  descriptor
}

///|
test "hamming distance zero pads unequal descriptor lengths" {
  let short = descriptor_with_byte(0)
  let long = Descriptor::new(2)
  long.data[1] = (1 : Byte)
  assert_eq(hamming_distance(short, long), 1)
}

///|
test "match policy applies ratio and stable top-k ordering" {
  let query = [descriptor_with_byte(0)]
  let train = [
    descriptor_with_byte(1),
    descriptor_with_byte(2),
    descriptor_with_byte(255),
  ]
  let rejected = match_with_policy(
    query,
    train,
    MatchPolicy::new(2, 0.8, true, false),
  )
  assert_eq(rejected.length(), 0)
  let accepted = match_with_policy(
    query,
    train,
    MatchPolicy::new(1, 0.8, false, false),
  )
  assert_eq(accepted.length(), 1)
  assert_eq(accepted[0].train_idx, 0)
  assert_eq(accepted[0].distance, 1)
}

///|
test "unique filtering keeps the closest match for each train index" {
  let matches : Array[Match] = [
    Match::new(0, 0, 5),
    Match::new(1, 0, 2),
    Match::new(2, 1, 1),
  ]
  let unique = enforce_unique_train_matches(matches)
  assert_eq(unique.length(), 2)
  assert_eq(unique[0].query_idx, 1)
  assert_eq(unique[0].train_idx, 0)
  assert_eq(unique[1].query_idx, 2)
}

///|
test "descriptor index returns the exact brute force nearest neighbor" {
  let train = [
    descriptor_with_byte(0),
    descriptor_with_byte(7),
    descriptor_with_byte(255),
  ]
  let index = DescriptorIndex::build(train)
  let query = descriptor_with_byte(6)
  let indexed = index.query(query, 2)
  let brute = knn_match([query], train, 2)
  assert_eq(indexed.length(), 2)
  assert_eq(indexed[0].train_idx, brute[0][0].train_idx)
  assert_eq(indexed[0].distance, brute[0][0].distance)
  assert_eq(indexed[1].train_idx, brute[0][1].train_idx)
}

///|
test "match statistics describe empty and non-empty results" {
  let empty = match_stats([])
  assert_eq(empty.count, 0)
  let stats = match_stats([Match::new(0, 1, 3), Match::new(1, 0, 7)])
  assert_eq(stats.count, 2)
  assert_eq(stats.minimum, 3)
  assert_eq(stats.maximum, 7)
  assert_eq(stats.mean, 5.0)
}

///|
test "mutual matching keeps symmetric nearest neighbors" {
  let query = [descriptor_with_byte(0), descriptor_with_byte(255)]
  let train = [descriptor_with_byte(0), descriptor_with_byte(255)]
  let matches = mutual_match(
    query,
    train,
    MatchPolicy::new(1, 0.8, false, false),
  )
  assert_eq(matches.length(), 2)
  assert_eq(matches[0].query_idx, 0)
  assert_eq(matches[0].train_idx, 0)
  assert_eq(matches[1].query_idx, 1)
  assert_eq(matches[1].train_idx, 1)
}
