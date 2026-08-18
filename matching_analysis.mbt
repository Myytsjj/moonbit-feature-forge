// Match-graph diagnostics and geometric filtering helpers.

///|
pub(all) struct MatchGraphStats {
  match_count : Int
  query_nodes : Int
  train_nodes : Int
  unique_queries : Int
  unique_trains : Int
  duplicate_queries : Int
  duplicate_trains : Int
  mean_distance : Double
  maximum_distance : Int
}

///|
fn matching_contains(values : Array[Int], value : Int) -> Bool {
  let mut i = 0
  while i < values.length() {
    if values[i] == value {
      return true
    }
    i = i + 1
  }
  false
}

///|
pub fn summarize_match_graph(
  matches : Array[Match],
  query_count : Int,
  train_count : Int,
) -> MatchGraphStats {
  let queries : Array[Int] = []
  let trains : Array[Int] = []
  let mut total_distance = 0
  let mut maximum_distance = 0
  let mut i = 0
  while i < matches.length() {
    let current = matches[i]
    if !matching_contains(queries, current.query_idx) {
      queries.push(current.query_idx)
    }
    if !matching_contains(trains, current.train_idx) {
      trains.push(current.train_idx)
    }
    total_distance = total_distance + current.distance
    if current.distance > maximum_distance {
      maximum_distance = current.distance
    }
    i = i + 1
  }
  {
    match_count: matches.length(),
    query_nodes: if query_count < 0 {
      0
    } else {
      query_count
    },
    train_nodes: if train_count < 0 {
      0
    } else {
      train_count
    },
    unique_queries: queries.length(),
    unique_trains: trains.length(),
    duplicate_queries: matches.length() - queries.length(),
    duplicate_trains: matches.length() - trains.length(),
    mean_distance: if matches.length() == 0 {
      0.0
    } else {
      Double::from_int(total_distance) / Double::from_int(matches.length())
    },
    maximum_distance,
  }
}

///|
pub fn match_distance_histogram(
  matches : Array[Match],
  bins : Int,
  maximum_distance : Int,
) -> Array[Int] {
  if bins <= 0 {
    return []
  }
  let result = Array::make(bins, 0)
  let high = if maximum_distance <= 0 { 1 } else { maximum_distance }
  let mut i = 0
  while i < matches.length() {
    let distance = if matches[i].distance < 0 { 0 } else { matches[i].distance }
    let mut slot = distance * bins / (high + 1)
    if slot >= bins {
      slot = bins - 1
    }
    result[slot] = result[slot] + 1
    i = i + 1
  }
  result
}

///|
fn matching_sort_ints(values : Array[Int]) -> Unit {
  let mut i = 1
  while i < values.length() {
    let value = values[i]
    let mut j = i
    while j > 0 && value < values[j - 1] {
      values[j] = values[j - 1]
      j = j - 1
    }
    values[j] = value
    i = i + 1
  }
}

///|
pub fn match_distance_percentile(
  matches : Array[Match],
  percentile : Double,
) -> Int {
  if matches.length() == 0 {
    return 0
  }
  let values : Array[Int] = []
  let mut i = 0
  while i < matches.length() {
    values.push(matches[i].distance)
    i = i + 1
  }
  matching_sort_ints(values)
  let mut probability = percentile
  if probability < 0.0 {
    probability = 0.0
  }
  if probability > 1.0 {
    probability = 1.0
  }
  let index = (probability * Double::from_int(values.length() - 1)).to_int()
  values[index]
}

///|
fn matching_sort_double(values : Array[Double]) -> Unit {
  let mut i = 1
  while i < values.length() {
    let value = values[i]
    let mut j = i
    while j > 0 && value < values[j - 1] {
      values[j] = values[j - 1]
      j = j - 1
    }
    values[j] = value
    i = i + 1
  }
}

///|
fn valid_match_points(
  item : Match,
  keypoints1 : Array[Keypoint],
  keypoints2 : Array[Keypoint],
) -> Bool {
  item.query_idx >= 0 &&
  item.query_idx < keypoints1.length() &&
  item.train_idx >= 0 &&
  item.train_idx < keypoints2.length()
}

///|
pub fn median_match_displacement(
  matches : Array[Match],
  keypoints1 : Array[Keypoint],
  keypoints2 : Array[Keypoint],
) -> FloatPoint2 {
  let dxs : Array[Double] = []
  let dys : Array[Double] = []
  let mut i = 0
  while i < matches.length() {
    let current = matches[i]
    if valid_match_points(current, keypoints1, keypoints2) {
      dxs.push(
        Double::from_int(
          keypoints2[current.train_idx].x - keypoints1[current.query_idx].x,
        ),
      )
      dys.push(
        Double::from_int(
          keypoints2[current.train_idx].y - keypoints1[current.query_idx].y,
        ),
      )
    }
    i = i + 1
  }
  if dxs.length() == 0 {
    return FloatPoint2::new(0.0, 0.0)
  }
  matching_sort_double(dxs)
  matching_sort_double(dys)
  let middle = dxs.length() / 2
  if dxs.length() % 2 == 1 {
    FloatPoint2::new(dxs[middle], dys[middle])
  } else {
    FloatPoint2::new(
      (dxs[middle - 1] + dxs[middle]) / 2.0,
      (dys[middle - 1] + dys[middle]) / 2.0,
    )
  }
}

///|
fn matching_distance(left : FloatPoint2, right : FloatPoint2) -> Double {
  let dx = left.x - right.x
  let dy = left.y - right.y
  let squared = dx * dx + dy * dy
  if squared <= 0.000000000001 {
    0.0
  } else {
    let mut guess = if squared > 1.0 { squared } else { 1.0 }
    let mut i = 0
    while i < 20 {
      guess = (guess + squared / guess) / 2.0
      i = i + 1
    }
    guess
  }
}

///|
pub fn filter_matches_by_displacement(
  matches : Array[Match],
  keypoints1 : Array[Keypoint],
  keypoints2 : Array[Keypoint],
  tolerance : Double,
) -> Array[Match] {
  let result : Array[Match] = []
  if tolerance < 0.0 {
    return result
  }
  let expected = median_match_displacement(matches, keypoints1, keypoints2)
  let mut i = 0
  while i < matches.length() {
    let current = matches[i]
    if valid_match_points(current, keypoints1, keypoints2) {
      let actual = FloatPoint2::new(
        Double::from_int(
          keypoints2[current.train_idx].x - keypoints1[current.query_idx].x,
        ),
        Double::from_int(
          keypoints2[current.train_idx].y - keypoints1[current.query_idx].y,
        ),
      )
      if matching_distance(actual, expected) <= tolerance {
        result.push(current)
      }
    }
    i = i + 1
  }
  result
}

///|
pub fn displacement_residuals(
  matches : Array[Match],
  keypoints1 : Array[Keypoint],
  keypoints2 : Array[Keypoint],
) -> Array[Double] {
  let result : Array[Double] = []
  let expected = median_match_displacement(matches, keypoints1, keypoints2)
  let mut i = 0
  while i < matches.length() {
    let current = matches[i]
    if valid_match_points(current, keypoints1, keypoints2) {
      let actual = FloatPoint2::new(
        Double::from_int(
          keypoints2[current.train_idx].x - keypoints1[current.query_idx].x,
        ),
        Double::from_int(
          keypoints2[current.train_idx].y - keypoints1[current.query_idx].y,
        ),
      )
      result.push(matching_distance(actual, expected))
    }
    i = i + 1
  }
  result
}

///|
pub(all) struct MatchQuality {
  count : Int
  inliers : Int
  ratio : Double
  mean_residual : Double
  maximum_residual : Double
}

///|
fn matching_quality(
  residuals : Array[Double],
  threshold : Double,
) -> MatchQuality {
  if residuals.length() == 0 {
    return {
      count: 0,
      inliers: 0,
      ratio: 0.0,
      mean_residual: 0.0,
      maximum_residual: 0.0,
    }
  }
  let safe_threshold = if threshold < 0.0 { 0.0 } else { threshold }
  let mut inliers = 0
  let mut total = 0.0
  let mut maximum = 0.0
  let mut i = 0
  while i < residuals.length() {
    let value = residuals[i]
    total = total + value
    if value > maximum {
      maximum = value
    }
    if value <= safe_threshold {
      inliers = inliers + 1
    }
    i = i + 1
  }
  {
    count: residuals.length(),
    inliers,
    ratio: Double::from_int(inliers) / Double::from_int(residuals.length()),
    mean_residual: total / Double::from_int(residuals.length()),
    maximum_residual: maximum,
  }
}

///|
pub fn residuals_for_affine(
  transform : AffineTransform,
  matches : Array[Match],
  keypoints1 : Array[Keypoint],
  keypoints2 : Array[Keypoint],
) -> Array[Double] {
  let residuals : Array[Double] = []
  let mut i = 0
  while i < matches.length() {
    let current = matches[i]
    if valid_match_points(current, keypoints1, keypoints2) {
      let source = keypoints1[current.query_idx]
      let target = keypoints2[current.train_idx]
      let (x, y) = transform.apply(
        Double::from_int(source.x),
        Double::from_int(source.y),
      )
      residuals.push(
        matching_distance(
          FloatPoint2::new(x, y),
          FloatPoint2::new(
            Double::from_int(target.x),
            Double::from_int(target.y),
          ),
        ),
      )
    }
    i = i + 1
  }
  residuals
}

///|
pub fn residuals_for_homography(
  model : Homography,
  matches : Array[Match],
  keypoints1 : Array[Keypoint],
  keypoints2 : Array[Keypoint],
) -> Array[Double] {
  let residuals : Array[Double] = []
  let mut i = 0
  while i < matches.length() {
    let current = matches[i]
    if valid_match_points(current, keypoints1, keypoints2) {
      let source = FloatPoint2::new(
        Double::from_int(keypoints1[current.query_idx].x),
        Double::from_int(keypoints1[current.query_idx].y),
      )
      let target = FloatPoint2::new(
        Double::from_int(keypoints2[current.train_idx].x),
        Double::from_int(keypoints2[current.train_idx].y),
      )
      residuals.push(
        matching_distance(
          match model.project(source) {
            None => FloatPoint2::new(1000000000.0, 1000000000.0)
            Some(value) => value
          },
          target,
        ),
      )
    }
    i = i + 1
  }
  residuals
}

///|
pub fn evaluate_affine_matches(
  transform : AffineTransform,
  matches : Array[Match],
  keypoints1 : Array[Keypoint],
  keypoints2 : Array[Keypoint],
  threshold : Double,
) -> MatchQuality {
  matching_quality(
    residuals_for_affine(transform, matches, keypoints1, keypoints2),
    threshold,
  )
}

///|
pub fn evaluate_homography_matches(
  model : Homography,
  matches : Array[Match],
  keypoints1 : Array[Keypoint],
  keypoints2 : Array[Keypoint],
  threshold : Double,
) -> MatchQuality {
  matching_quality(
    residuals_for_homography(model, matches, keypoints1, keypoints2),
    threshold,
  )
}

///|
pub fn inlier_mask(
  residuals : Array[Double],
  threshold : Double,
) -> Array[Bool] {
  let result = Array::make(residuals.length(), false)
  let safe_threshold = if threshold < 0.0 { 0.0 } else { threshold }
  let mut i = 0
  while i < residuals.length() {
    result[i] = residuals[i] <= safe_threshold
    i = i + 1
  }
  result
}

///|
pub fn apply_match_mask(
  matches : Array[Match],
  mask : Array[Bool],
) -> Array[Match] {
  let result : Array[Match] = []
  let count = if matches.length() < mask.length() {
    matches.length()
  } else {
    mask.length()
  }
  let mut i = 0
  while i < count {
    if mask[i] {
      result.push(matches[i])
    }
    i = i + 1
  }
  result
}

///|
pub fn filter_matches_by_affine(
  transform : AffineTransform,
  matches : Array[Match],
  keypoints1 : Array[Keypoint],
  keypoints2 : Array[Keypoint],
  threshold : Double,
) -> Array[Match] {
  let result : Array[Match] = []
  let safe_threshold = if threshold < 0.0 { 0.0 } else { threshold }
  let mut i = 0
  while i < matches.length() {
    let current = matches[i]
    if valid_match_points(current, keypoints1, keypoints2) {
      let source = keypoints1[current.query_idx]
      let target = keypoints2[current.train_idx]
      let (x, y) = transform.apply(
        Double::from_int(source.x),
        Double::from_int(source.y),
      )
      let residual = matching_distance(
        FloatPoint2::new(x, y),
        FloatPoint2::new(Double::from_int(target.x), Double::from_int(target.y)),
      )
      if residual <= safe_threshold {
        result.push(current)
      }
    }
    i = i + 1
  }
  result
}

///|
pub fn filter_matches_by_homography(
  model : Homography,
  matches : Array[Match],
  keypoints1 : Array[Keypoint],
  keypoints2 : Array[Keypoint],
  threshold : Double,
) -> Array[Match] {
  let result : Array[Match] = []
  let safe_threshold = if threshold < 0.0 { 0.0 } else { threshold }
  let mut i = 0
  while i < matches.length() {
    let current = matches[i]
    if valid_match_points(current, keypoints1, keypoints2) {
      let source = FloatPoint2::new(
        Double::from_int(keypoints1[current.query_idx].x),
        Double::from_int(keypoints1[current.query_idx].y),
      )
      let target = FloatPoint2::new(
        Double::from_int(keypoints2[current.train_idx].x),
        Double::from_int(keypoints2[current.train_idx].y),
      )
      let projected = match model.project(source) {
        None => FloatPoint2::new(1000000000.0, 1000000000.0)
        Some(value) => value
      }
      if matching_distance(projected, target) <= safe_threshold {
        result.push(current)
      }
    }
    i = i + 1
  }
  result
}

///|
pub(all) struct DescriptorBucketStats {
  bucket_count : Int
  non_empty_buckets : Int
  maximum_bucket : Int
  mean_bucket : Double
}

///|
pub fn descriptor_index_stats(index : DescriptorIndex) -> DescriptorBucketStats {
  let mut non_empty = 0
  let mut maximum = 0
  let mut total = 0
  let mut i = 0
  while i < index.buckets.length() {
    let size = index.buckets[i].length()
    total = total + size
    if size > 0 {
      non_empty = non_empty + 1
    }
    if size > maximum {
      maximum = size
    }
    i = i + 1
  }
  {
    bucket_count: index.buckets.length(),
    non_empty_buckets: non_empty,
    maximum_bucket: maximum,
    mean_bucket: if index.buckets.length() == 0 {
      0.0
    } else {
      Double::from_int(total) / Double::from_int(index.buckets.length())
    },
  }
}

///|
fn same_match_pair(left : Match, right : Match) -> Bool {
  left.query_idx == right.query_idx && left.train_idx == right.train_idx
}

///|
pub fn merge_match_sets(
  left : Array[Match],
  right : Array[Match],
) -> Array[Match] {
  let result : Array[Match] = []
  let mut i = 0
  while i < left.length() {
    result.push(left[i])
    i = i + 1
  }
  i = 0
  while i < right.length() {
    let current = right[i]
    let mut found = -1
    let mut j = 0
    while j < result.length() {
      if same_match_pair(result[j], current) {
        found = j
      }
      j = j + 1
    }
    if found < 0 {
      result.push(current)
    } else if current.distance < result[found].distance {
      result[found] = current
    }
    i = i + 1
  }
  result
}

///|
pub fn query_match_support(matches : Array[Match], query_idx : Int) -> Int {
  let mut count = 0
  let mut i = 0
  while i < matches.length() {
    if matches[i].query_idx == query_idx {
      count = count + 1
    }
    i = i + 1
  }
  count
}

///|
pub fn train_match_support(matches : Array[Match], train_idx : Int) -> Int {
  let mut count = 0
  let mut i = 0
  while i < matches.length() {
    if matches[i].train_idx == train_idx {
      count = count + 1
    }
    i = i + 1
  }
  count
}

///|
pub fn match_reciprocal_rank(
  matches : Array[Match],
  query_idx : Int,
  train_idx : Int,
) -> Double {
  let mut rank = 0
  let mut i = 0
  while i < matches.length() {
    if matches[i].query_idx == query_idx {
      rank = rank + 1
      if matches[i].train_idx == train_idx {
        return 1.0 / Double::from_int(rank)
      }
    }
    i = i + 1
  }
  0.0
}

///|
pub fn match_pair_consistency(
  left : Match,
  right : Match,
  keypoints1 : Array[Keypoint],
  keypoints2 : Array[Keypoint],
  tolerance : Double,
) -> Bool {
  if !valid_match_points(left, keypoints1, keypoints2) ||
    !valid_match_points(right, keypoints1, keypoints2) ||
    tolerance < 0.0 {
    return false
  }
  let left_dx = keypoints2[left.train_idx].x - keypoints1[left.query_idx].x
  let left_dy = keypoints2[left.train_idx].y - keypoints1[left.query_idx].y
  let right_dx = keypoints2[right.train_idx].x - keypoints1[right.query_idx].x
  let right_dy = keypoints2[right.train_idx].y - keypoints1[right.query_idx].y
  matching_distance(
    FloatPoint2::new(Double::from_int(left_dx), Double::from_int(left_dy)),
    FloatPoint2::new(Double::from_int(right_dx), Double::from_int(right_dy)),
  ) <=
  tolerance
}

///|
pub fn consistent_match_subset(
  matches : Array[Match],
  keypoints1 : Array[Keypoint],
  keypoints2 : Array[Keypoint],
  tolerance : Double,
) -> Array[Match] {
  let result : Array[Match] = []
  let reference = if matches.length() == 0 { None } else { Some(matches[0]) }
  match reference {
    None => result
    Some(anchor) => {
      let mut i = 0
      while i < matches.length() {
        if match_pair_consistency(
            anchor,
            matches[i],
            keypoints1,
            keypoints2,
            tolerance,
          ) {
          result.push(matches[i])
        }
        i = i + 1
      }
      result
    }
  }
}

///|
pub fn match_distance_mean(matches : Array[Match]) -> Double {
  if matches.length() == 0 {
    return 0.0
  }
  let mut total = 0
  let mut i = 0
  while i < matches.length() {
    total = total + matches[i].distance
    i = i + 1
  }
  Double::from_int(total) / Double::from_int(matches.length())
}

///|
pub fn match_distance_variance(matches : Array[Match]) -> Double {
  if matches.length() == 0 {
    return 0.0
  }
  let mean = match_distance_mean(matches)
  let mut total = 0.0
  let mut i = 0
  while i < matches.length() {
    let difference = Double::from_int(matches[i].distance) - mean
    total = total + difference * difference
    i = i + 1
  }
  total / Double::from_int(matches.length())
}
