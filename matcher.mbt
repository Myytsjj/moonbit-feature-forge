// Hamming Distance & Descriptor Matcher Engine

///|
fn popcount8(val : Byte) -> Int {
  let mut v = val.to_int()
  v = v - ((v >> 1) & 0x55)
  v = (v & 0x33) + ((v >> 2) & 0x33)
  (v + (v >> 4)) & 0x0F
}

///|
pub fn hamming_distance(d1 : Descriptor, d2 : Descriptor) -> Int {
  let mut dist = 0
  let len = if d1.data.length() < d2.data.length() {
    d1.data.length()
  } else {
    d2.data.length()
  }
  let mut i = 0
  while i < len {
    let xor_val = d1.data[i] ^ d2.data[i]
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
