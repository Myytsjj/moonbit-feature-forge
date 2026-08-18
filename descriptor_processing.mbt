// Descriptor packing, signatures, and batch-search helpers for ORB-like data.

///|
pub(all) struct DescriptorSignature {
  bytes : Int
  checksum : Int
  popcount : Int
  zero_bytes : Int
  nonzero_bytes : Int
}

///|
pub(all) struct DescriptorSearchReport {
  queries : Int
  candidates : Int
  comparisons : Int
  mean_best_distance : Double
  exact : Bool
}

///|
fn descriptor_mod(value : Int, modulus : Int) -> Int {
  if modulus <= 0 {
    0
  } else {
    let result = value % modulus
    if result < 0 {
      result + modulus
    } else {
      result
    }
  }
}

///|
pub fn descriptor_signature(descriptor : Descriptor) -> DescriptorSignature {
  let mut checksum = 17
  let mut popcount = 0
  let mut zero_bytes = 0
  let mut i = 0
  while i < descriptor.data.length() {
    let value = descriptor.data[i].to_int()
    checksum = (checksum * 31 + value + i) & 0x7FFFFFFF
    popcount = popcount + feature_popcount(descriptor.data[i])
    if value == 0 {
      zero_bytes = zero_bytes + 1
    }
    i = i + 1
  }
  {
    bytes: descriptor.data.length(),
    checksum,
    popcount,
    zero_bytes,
    nonzero_bytes: descriptor.data.length() - zero_bytes,
  }
}

///|
pub fn descriptor_checksum(descriptor : Descriptor) -> Int {
  descriptor_signature(descriptor).checksum
}

///|
pub fn descriptor_set_checksum(descriptors : Array[Descriptor]) -> Int {
  let mut checksum = 23
  let mut i = 0
  while i < descriptors.length() {
    checksum = (checksum * 37 + descriptor_checksum(descriptors[i]) + i) &
      0x7FFFFFFF
    i = i + 1
  }
  checksum
}

///|
pub fn descriptor_zero(bytes : Int) -> Descriptor {
  Descriptor::new(if bytes < 0 { 0 } else { bytes })
}

///|
pub fn descriptor_copy(descriptor : Descriptor) -> Descriptor {
  let result = Descriptor::new(descriptor.data.length())
  let mut i = 0
  while i < descriptor.data.length() {
    result.data[i] = descriptor.data[i]
    i = i + 1
  }
  result
}

///|
pub fn descriptor_prefix(descriptor : Descriptor, bytes : Int) -> Descriptor {
  let count = if bytes < 0 {
    0
  } else if bytes > descriptor.data.length() {
    descriptor.data.length()
  } else {
    bytes
  }
  let result = Descriptor::new(count)
  let mut i = 0
  while i < count {
    result.data[i] = descriptor.data[i]
    i = i + 1
  }
  result
}

///|
pub fn descriptor_suffix(descriptor : Descriptor, start : Int) -> Descriptor {
  let offset = if start < 0 {
    0
  } else if start > descriptor.data.length() {
    descriptor.data.length()
  } else {
    start
  }
  let result = Descriptor::new(descriptor.data.length() - offset)
  let mut i = offset
  while i < descriptor.data.length() {
    result.data[i - offset] = descriptor.data[i]
    i = i + 1
  }
  result
}

///|
pub fn descriptor_concat(left : Descriptor, right : Descriptor) -> Descriptor {
  let result = Descriptor::new(left.data.length() + right.data.length())
  let mut i = 0
  while i < left.data.length() {
    result.data[i] = left.data[i]
    i = i + 1
  }
  i = 0
  while i < right.data.length() {
    result.data[left.data.length() + i] = right.data[i]
    i = i + 1
  }
  result
}

///|
pub fn descriptor_rotate_bits(
  descriptor : Descriptor,
  shift : Int,
) -> Descriptor {
  let bit_count = descriptor.data.length() * 8
  let result = Descriptor::new(descriptor.data.length())
  if bit_count == 0 {
    return result
  }
  let offset = descriptor_mod(shift, bit_count)
  let mut bit = 0
  while bit < bit_count {
    let source_bit = descriptor_mod(bit - offset, bit_count)
    let source_byte = source_bit / 8
    let source_offset = source_bit % 8
    if ((descriptor.data[source_byte].to_int() >> source_offset) & 1) != 0 {
      let target_byte = bit / 8
      let target_offset = bit % 8
      result.data[target_byte] = (result.data[target_byte].to_int() |
      (1 << target_offset)).to_byte()
    }
    bit = bit + 1
  }
  result
}

///|
pub fn descriptor_reverse_bits(descriptor : Descriptor) -> Descriptor {
  let result = Descriptor::new(descriptor.data.length())
  let bit_count = descriptor.data.length() * 8
  let mut bit = 0
  while bit < bit_count {
    let source = bit_count - bit - 1
    if ((descriptor.data[source / 8].to_int() >> (source % 8)) & 1) != 0 {
      result.data[bit / 8] = (result.data[bit / 8].to_int() | (1 << (bit % 8))).to_byte()
    }
    bit = bit + 1
  }
  result
}

///|
pub fn descriptor_mask(
  descriptor : Descriptor,
  mask : Descriptor,
) -> Descriptor {
  let length = if descriptor.data.length() < mask.data.length() {
    descriptor.data.length()
  } else {
    mask.data.length()
  }
  let result = Descriptor::new(length)
  let mut i = 0
  while i < length {
    result.data[i] = (descriptor.data[i].to_int() & mask.data[i].to_int()).to_byte()
    i = i + 1
  }
  result
}

///|
pub fn descriptor_xor(left : Descriptor, right : Descriptor) -> Descriptor {
  let length = if left.data.length() > right.data.length() {
    left.data.length()
  } else {
    right.data.length()
  }
  let result = Descriptor::new(length)
  let mut i = 0
  while i < length {
    let a = if i < left.data.length() { left.data[i].to_int() } else { 0 }
    let b = if i < right.data.length() { right.data[i].to_int() } else { 0 }
    result.data[i] = (a ^ b).to_byte()
    i = i + 1
  }
  result
}

///|
pub fn descriptor_or(left : Descriptor, right : Descriptor) -> Descriptor {
  let length = if left.data.length() > right.data.length() {
    left.data.length()
  } else {
    right.data.length()
  }
  let result = Descriptor::new(length)
  let mut i = 0
  while i < length {
    let a = if i < left.data.length() { left.data[i].to_int() } else { 0 }
    let b = if i < right.data.length() { right.data[i].to_int() } else { 0 }
    result.data[i] = (a | b).to_byte()
    i = i + 1
  }
  result
}

///|
pub fn descriptor_bit_slice(
  descriptor : Descriptor,
  start_bit : Int,
  length : Int,
) -> Descriptor {
  let safe_start = if start_bit < 0 { 0 } else { start_bit }
  let safe_length = if length < 0 { 0 } else { length }
  let result = Descriptor::new((safe_length + 7) / 8)
  let mut bit = 0
  while bit < safe_length {
    let source = safe_start + bit
    if source / 8 < descriptor.data.length() &&
      ((descriptor.data[source / 8].to_int() >> (source % 8)) & 1) != 0 {
      result.data[bit / 8] = (result.data[bit / 8].to_int() | (1 << (bit % 8))).to_byte()
    }
    bit = bit + 1
  }
  result
}

///|
pub fn descriptor_byte_histogram(descriptors : Array[Descriptor]) -> Array[Int] {
  let result = Array::make(256, 0)
  let mut i = 0
  while i < descriptors.length() {
    let mut j = 0
    while j < descriptors[i].data.length() {
      result[descriptors[i].data[j].to_int()] = result[descriptors[i].data[j].to_int()] +
        1
      j = j + 1
    }
    i = i + 1
  }
  result
}

///|
pub fn descriptor_nonzero_fraction(descriptor : Descriptor) -> Double {
  if descriptor.data.length() == 0 {
    return 0.0
  }
  let signature = descriptor_signature(descriptor)
  Double::from_int(signature.nonzero_bytes) / Double::from_int(signature.bytes)
}

///|
pub fn descriptor_bit_fraction(descriptor : Descriptor) -> Double {
  if descriptor.data.length() == 0 {
    return 0.0
  }
  Double::from_int(descriptor_popcount(descriptor)) /
  Double::from_int(descriptor.data.length() * 8)
}

///|
pub fn descriptor_hamming_similarity(
  left : Descriptor,
  right : Descriptor,
) -> Double {
  let capacity = if left.data.length() > right.data.length() {
    left.data.length()
  } else {
    right.data.length()
  }
  if capacity == 0 {
    return 1.0
  }
  1.0 -
  Double::from_int(hamming_distance(left, right)) /
  Double::from_int(capacity * 8)
}

///|
pub fn descriptor_batch_hamming(
  query : Descriptor,
  descriptors : Array[Descriptor],
) -> Array[Int] {
  let result = Array::make(descriptors.length(), 0)
  let mut i = 0
  while i < descriptors.length() {
    result[i] = hamming_distance(query, descriptors[i])
    i = i + 1
  }
  result
}

///|
pub fn descriptor_index_batch_query(
  index : DescriptorIndex,
  queries : Array[Descriptor],
  k : Int,
) -> Array[Array[Match]] {
  let result : Array[Array[Match]] = []
  let mut i = 0
  while i < queries.length() {
    let row = index.query(queries[i], k)
    let mut j = 0
    while j < row.length() {
      row[j] = Match::new(i, row[j].train_idx, row[j].distance)
      j = j + 1
    }
    result.push(row)
    i = i + 1
  }
  result
}

///|
pub fn descriptor_batch_search_report(
  index : DescriptorIndex,
  queries : Array[Descriptor],
  k : Int,
) -> DescriptorSearchReport {
  let rows = descriptor_index_batch_query(index, queries, k)
  let mut comparisons = 0
  let mut total_best = 0
  let mut i = 0
  while i < rows.length() {
    comparisons = comparisons + index.descriptors.length()
    if rows[i].length() > 0 {
      total_best = total_best + rows[i][0].distance
    }
    i = i + 1
  }
  {
    queries: queries.length(),
    candidates: index.descriptors.length(),
    comparisons,
    mean_best_distance: if queries.length() == 0 {
      0.0
    } else {
      Double::from_int(total_best) / Double::from_int(queries.length())
    },
    exact: true,
  }
}

///|
pub fn descriptor_top_k_vote(
  rows : Array[Array[Match]],
  train_count : Int,
) -> Array[Int] {
  if train_count <= 0 {
    return []
  }
  let votes = Array::make(train_count, 0)
  let mut i = 0
  while i < rows.length() {
    if rows[i].length() > 0 &&
      rows[i][0].train_idx >= 0 &&
      rows[i][0].train_idx < train_count {
      votes[rows[i][0].train_idx] = votes[rows[i][0].train_idx] + 1
    }
    i = i + 1
  }
  votes
}

///|
pub fn descriptor_recall_at_k(
  rows : Array[Array[Match]],
  truth : Array[Int],
  k : Int,
) -> Double {
  if rows.length() == 0 || truth.length() == 0 || k <= 0 {
    return 0.0
  }
  let count = if rows.length() < truth.length() {
    rows.length()
  } else {
    truth.length()
  }
  let mut hits = 0
  let mut i = 0
  while i < count {
    let limit = if k < rows[i].length() { k } else { rows[i].length() }
    let mut j = 0
    while j < limit {
      if rows[i][j].train_idx == truth[i] {
        hits = hits + 1
      }
      j = j + 1
    }
    i = i + 1
  }
  Double::from_int(hits) / Double::from_int(count)
}

///|
pub fn descriptor_precision_at_k(
  rows : Array[Array[Match]],
  truth : Array[Int],
  k : Int,
) -> Double {
  if rows.length() == 0 || truth.length() == 0 || k <= 0 {
    return 0.0
  }
  let count = if rows.length() < truth.length() {
    rows.length()
  } else {
    truth.length()
  }
  let mut hits = 0
  let mut predictions = 0
  let mut i = 0
  while i < count {
    let limit = if k < rows[i].length() { k } else { rows[i].length() }
    predictions = predictions + limit
    let mut j = 0
    while j < limit {
      if rows[i][j].train_idx == truth[i] {
        hits = hits + 1
      }
      j = j + 1
    }
    i = i + 1
  }
  if predictions == 0 {
    0.0
  } else {
    Double::from_int(hits) / Double::from_int(predictions)
  }
}

///|
pub fn descriptor_distance_quantiles(
  query : Descriptor,
  candidates : Array[Descriptor],
) -> (Int, Int, Int) {
  let values = descriptor_batch_hamming(query, candidates)
  if values.length() == 0 {
    return (0, 0, 0)
  }
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
  (
    values[values.length() / 4],
    values[values.length() / 2],
    values[values.length() * 3 / 4],
  )
}

///|
pub fn descriptor_interpolate(
  left : Descriptor,
  right : Descriptor,
  weight : Double,
) -> Descriptor {
  let safe = if weight < 0.0 {
    0.0
  } else if weight > 1.0 {
    1.0
  } else {
    weight
  }
  let length = if left.data.length() < right.data.length() {
    left.data.length()
  } else {
    right.data.length()
  }
  let result = Descriptor::new(length)
  let mut i = 0
  while i < length {
    let value = Double::from_int(left.data[i].to_int()) * (1.0 - safe) +
      Double::from_int(right.data[i].to_int()) * safe
    result.data[i] = value.to_int().to_byte()
    i = i + 1
  }
  result
}

///|
pub fn descriptor_pack_bits(bits : Array[Bool]) -> Descriptor {
  let result = Descriptor::new((bits.length() + 7) / 8)
  let mut i = 0
  while i < bits.length() {
    if bits[i] {
      result.data[i / 8] = (result.data[i / 8].to_int() | (1 << (i % 8))).to_byte()
    }
    i = i + 1
  }
  result
}

///|
pub fn descriptor_unpack_bits(
  descriptor : Descriptor,
  bit_count : Int,
) -> Array[Bool] {
  let count = if bit_count < 0 {
    0
  } else if bit_count > descriptor.data.length() * 8 {
    descriptor.data.length() * 8
  } else {
    bit_count
  }
  let result = Array::make(count, false)
  let mut i = 0
  while i < count {
    result[i] = ((descriptor.data[i / 8].to_int() >> (i % 8)) & 1) != 0
    i = i + 1
  }
  result
}

///|
pub fn descriptor_distance_profile(
  descriptors : Array[Descriptor],
) -> Array[Double] {
  let result = Array::make(descriptors.length(), 0.0)
  if descriptors.length() < 2 {
    return result
  }
  let mut i = 0
  while i < descriptors.length() {
    let mut nearest = 2147483647
    let mut j = 0
    while j < descriptors.length() {
      if i != j {
        let distance = hamming_distance(descriptors[i], descriptors[j])
        if distance < nearest {
          nearest = distance
        }
      }
      j = j + 1
    }
    result[i] = Double::from_int(nearest)
    i = i + 1
  }
  result
}

///|
pub fn descriptor_unique_count(descriptors : Array[Descriptor]) -> Int {
  let unique : Array[Descriptor] = []
  let mut i = 0
  while i < descriptors.length() {
    let mut found = false
    let mut j = 0
    while j < unique.length() {
      if descriptors_equal(descriptors[i], unique[j]) {
        found = true
      }
      j = j + 1
    }
    if !found {
      unique.push(descriptors[i])
    }
    i = i + 1
  }
  unique.length()
}

///|
pub fn descriptor_duplicate_fraction(descriptors : Array[Descriptor]) -> Double {
  if descriptors.length() == 0 {
    return 0.0
  }
  1.0 -
  Double::from_int(descriptor_unique_count(descriptors)) /
  Double::from_int(descriptors.length())
}
