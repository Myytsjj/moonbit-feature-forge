// Hamming Distance & Descriptor Matcher Engine
// High-performance binary vector matching for 256-bit BRIEF/ORB descriptors.

///|
// Fast population count (number of set 1 bits in a Byte)
fn popcount8(val : Byte) -> Int {
  let mut v = val.to_int()
  v = v - ((v >> 1) & 0x55)
  v = (v & 0x33) + ((v >> 2) & 0x33)
  (v + (v >> 4)) & 0x0F
}

///|
pub fn hamming_distance(d1 : Descriptor, d2 : Descriptor) -> Int {
  let mut dist = 0
  let len = if d1.data.length() > d2.data.length() {
    d1.data.length()
  } else {
    d2.data.length()
  }
  let mut i = 0
  while i < len {
    let left = if i < d1.data.length() { d1.data[i] } else { (0 : Byte) }
    let right = if i < d2.data.length() { d2.data[i] } else { (0 : Byte) }
    let xor_val = left ^ right
    dist = dist + popcount8(xor_val)
    i = i + 1
  }
  dist
}

///|
pub fn match_descriptors(
  query : Array[Descriptor],
  train : Array[Descriptor],
) -> Array[Match] {
  let matches : Array[Match] = []
  let mut q_idx = 0
  while q_idx < query.length() {
    let q_desc = query[q_idx]
    let mut best_dist = 999999
    let mut best_t_idx = -1

    let mut t_idx = 0
    while t_idx < train.length() {
      let t_desc = train[t_idx]
      let dist = hamming_distance(q_desc, t_desc)
      if dist < best_dist {
        best_dist = dist
        best_t_idx = t_idx
      }
      t_idx = t_idx + 1
    }

    if best_t_idx >= 0 {
      matches.push(Match::new(q_idx, best_t_idx, best_dist))
    }
    q_idx = q_idx + 1
  }
  matches
}

///|
pub fn knn_match(
  query : Array[Descriptor],
  train : Array[Descriptor],
  k : Int,
) -> Array[Array[Match]] {
  let results : Array[Array[Match]] = []
  if k <= 0 || train.length() == 0 {
    return results
  }

  let mut q_idx = 0
  while q_idx < query.length() {
    let q_desc = query[q_idx]

    let row_matches : Array[Match] = []
    let mut t_idx = 0
    while t_idx < train.length() {
      let dist = hamming_distance(q_desc, train[t_idx])
      row_matches.push(Match::new(q_idx, t_idx, dist))
      t_idx = t_idx + 1
    }

    let mut i = 0
    while i < row_matches.length() - 1 {
      let mut min_idx = i
      let mut j = i + 1
      while j < row_matches.length() {
        if row_matches[j].distance < row_matches[min_idx].distance {
          min_idx = j
        }
        j = j + 1
      }
      if min_idx != i {
        let temp = row_matches[i]
        row_matches[i] = row_matches[min_idx]
        row_matches[min_idx] = temp
      }
      i = i + 1
    }

    let top_k : Array[Match] = []
    let limit = if k < row_matches.length() { k } else { row_matches.length() }
    let mut idx = 0
    while idx < limit {
      top_k.push(row_matches[idx])
      idx = idx + 1
    }
    results.push(top_k)
    q_idx = q_idx + 1
  }
  results
}

///|
pub fn ratio_test(
  knn_matches : Array[Array[Match]],
  ratio : Double,
) -> Array[Match] {
  let filtered : Array[Match] = []
  let mut i = 0
  while i < knn_matches.length() {
    let row = knn_matches[i]
    if row.length() >= 2 {
      let m1 = row[0]
      let m2 = row[1]
      if Double::from_int(m1.distance) < ratio * Double::from_int(m2.distance) {
        filtered.push(m1)
      }
    } else if row.length() == 1 {
      filtered.push(row[0])
    }
    i = i + 1
  }
  filtered
}

///|
pub fn cross_check(
  matches_12 : Array[Match],
  matches_21 : Array[Match],
) -> Array[Match] {
  let verified : Array[Match] = []
  let mut i = 0
  while i < matches_12.length() {
    let m12 = matches_12[i]
    let mut j = 0
    while j < matches_21.length() {
      let m21 = matches_21[j]
      if m12.query_idx == m21.train_idx && m12.train_idx == m21.query_idx {
        verified.push(m12)
      }
      j = j + 1
    }
    i = i + 1
  }
  verified
}

///|
pub(all) struct MatchPolicy {
  k : Int
  ratio : Double
  use_ratio : Bool
  enforce_unique : Bool
}

///|
pub fn MatchPolicy::new(
  k : Int,
  ratio : Double,
  use_ratio : Bool,
  enforce_unique : Bool,
) -> MatchPolicy {
  { k, ratio, use_ratio, enforce_unique }
}

///|
pub fn MatchPolicy::default() -> MatchPolicy {
  MatchPolicy::new(2, 0.8, true, true)
}

///|
pub(all) struct MatchStats {
  count : Int
  minimum : Int
  maximum : Int
  mean : Double
}

///|
fn match_before(left : Match, right : Match) -> Bool {
  if left.distance < right.distance {
    true
  } else if left.distance > right.distance {
    false
  } else if left.query_idx < right.query_idx {
    true
  } else if left.query_idx > right.query_idx {
    false
  } else {
    left.train_idx < right.train_idx
  }
}

///|
fn query_before(left : Match, right : Match) -> Bool {
  if left.query_idx < right.query_idx {
    true
  } else if left.query_idx > right.query_idx {
    false
  } else {
    left.train_idx < right.train_idx
  }
}

///|
fn sort_matches(matches : Array[Match], by_distance : Bool) -> Unit {
  let mut i = 1
  while i < matches.length() {
    let current = matches[i]
    let mut j = i
    while j > 0 &&
          (if by_distance {
            match_before(current, matches[j - 1])
          } else {
            query_before(current, matches[j - 1])
          }) {
      matches[j] = matches[j - 1]
      j = j - 1
    }
    matches[j] = current
    i = i + 1
  }
}

///|
fn contains_int(values : Array[Int], value : Int) -> Bool {
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
pub fn enforce_unique_train_matches(matches : Array[Match]) -> Array[Match] {
  let ordered : Array[Match] = []
  let mut i = 0
  while i < matches.length() {
    ordered.push(matches[i])
    i = i + 1
  }
  sort_matches(ordered, true)
  let used : Array[Int] = []
  let unique : Array[Match] = []
  i = 0
  while i < ordered.length() {
    let current = ordered[i]
    if !contains_int(used, current.train_idx) {
      used.push(current.train_idx)
      unique.push(current)
    }
    i = i + 1
  }
  sort_matches(unique, false)
  unique
}

///|
fn first_matches(rows : Array[Array[Match]]) -> Array[Match] {
  let result : Array[Match] = []
  let mut i = 0
  while i < rows.length() {
    if rows[i].length() > 0 {
      result.push(rows[i][0])
    }
    i = i + 1
  }
  result
}

///|
pub fn match_with_policy(
  query : Array[Descriptor],
  train : Array[Descriptor],
  policy : MatchPolicy,
) -> Array[Match] {
  if query.length() == 0 || train.length() == 0 || policy.k <= 0 {
    return []
  }
  let rows = knn_match(query, train, policy.k)
  let selected = if policy.use_ratio {
    ratio_test(rows, policy.ratio)
  } else {
    first_matches(rows)
  }
  if policy.enforce_unique {
    enforce_unique_train_matches(selected)
  } else {
    selected
  }
}

///|
pub fn mutual_match(
  query : Array[Descriptor],
  train : Array[Descriptor],
  policy : MatchPolicy,
) -> Array[Match] {
  let forward = match_with_policy(query, train, policy)
  let backward = match_with_policy(train, query, policy)
  cross_check(forward, backward)
}

///|
pub fn match_stats(matches : Array[Match]) -> MatchStats {
  if matches.length() == 0 {
    return { count: 0, minimum: 0, maximum: 0, mean: 0.0 }
  }
  let mut minimum = matches[0].distance
  let mut maximum = matches[0].distance
  let mut total = 0
  let mut i = 0
  while i < matches.length() {
    let distance = matches[i].distance
    if distance < minimum {
      minimum = distance
    }
    if distance > maximum {
      maximum = distance
    }
    total = total + distance
    i = i + 1
  }
  {
    count: matches.length(),
    minimum,
    maximum,
    mean: Double::from_int(total) / Double::from_int(matches.length()),
  }
}

///|
pub(all) struct DescriptorIndex {
  descriptors : Array[Descriptor]
  buckets : Array[Array[Int]]
}

///|
fn descriptor_bucket(descriptor : Descriptor) -> Int {
  if descriptor.data.length() == 0 {
    0
  } else {
    descriptor.data[0].to_int()
  }
}

///|
pub fn DescriptorIndex::build(
  descriptors : Array[Descriptor],
) -> DescriptorIndex {
  let buckets : Array[Array[Int]] = []
  let mut bucket_index = 0
  while bucket_index < 256 {
    buckets.push([])
    bucket_index = bucket_index + 1
  }
  let mut i = 0
  while i < descriptors.length() {
    buckets[descriptor_bucket(descriptors[i])].push(i)
    i = i + 1
  }
  { descriptors, buckets }
}

///|
pub fn DescriptorIndex::query(
  self : DescriptorIndex,
  query : Descriptor,
  k : Int,
) -> Array[Match] {
  if k <= 0 || self.descriptors.length() == 0 {
    return []
  }
  let result : Array[Match] = []
  let primary = self.buckets[descriptor_bucket(query)]
  let mut i = 0
  while i < primary.length() {
    let train_idx = primary[i]
    result.push(
      Match::new(
        0,
        train_idx,
        hamming_distance(query, self.descriptors[train_idx]),
      ),
    )
    i = i + 1
  }
  i = 0
  while i < self.descriptors.length() {
    if !contains_int(primary, i) {
      result.push(
        Match::new(0, i, hamming_distance(query, self.descriptors[i])),
      )
    }
    i = i + 1
  }
  sort_matches(result, true)
  let limit = if k < result.length() { k } else { result.length() }
  while result.length() > limit {
    ignore(result.pop())
  }
  result
}
