// Feature-set summaries and descriptor diagnostics used by applications that
// need to inspect a run without depending on a plotting or numeric package.

///|
pub(all) struct KeypointStats {
  count : Int
  mean_response : Double
  minimum_response : Double
  maximum_response : Double
  centroid : FloatPoint2
  bounds : Rect
}

///|
fn feature_pi() -> Double {
  3.141592653589793
}

///|
fn normalize_angle(angle : Double) -> Double {
  let pi = feature_pi()
  let two_pi = pi * 2.0
  let mut value = angle
  while value < -pi {
    value = value + two_pi
  }
  while value >= pi {
    value = value - two_pi
  }
  value
}

///|
pub fn keypoint_centroid(keypoints : Array[Keypoint]) -> FloatPoint2 {
  if keypoints.length() == 0 {
    return FloatPoint2::new(0.0, 0.0)
  }
  let mut sum_x = 0.0
  let mut sum_y = 0.0
  let mut i = 0
  while i < keypoints.length() {
    sum_x = sum_x + Double::from_int(keypoints[i].x)
    sum_y = sum_y + Double::from_int(keypoints[i].y)
    i = i + 1
  }
  let count = Double::from_int(keypoints.length())
  FloatPoint2::new(sum_x / count, sum_y / count)
}

///|
pub fn keypoint_bounds(keypoints : Array[Keypoint]) -> Rect {
  if keypoints.length() == 0 {
    return Rect::new(0, 0, 0, 0)
  }
  let mut left = keypoints[0].x
  let mut top = keypoints[0].y
  let mut right = keypoints[0].x
  let mut bottom = keypoints[0].y
  let mut i = 1
  while i < keypoints.length() {
    let point = keypoints[i]
    if point.x < left {
      left = point.x
    }
    if point.y < top {
      top = point.y
    }
    if point.x > right {
      right = point.x
    }
    if point.y > bottom {
      bottom = point.y
    }
    i = i + 1
  }
  Rect::new(left, top, right + 1, bottom + 1)
}

///|
pub fn summarize_keypoints(keypoints : Array[Keypoint]) -> KeypointStats {
  if keypoints.length() == 0 {
    return {
      count: 0,
      mean_response: 0.0,
      minimum_response: 0.0,
      maximum_response: 0.0,
      centroid: FloatPoint2::new(0.0, 0.0),
      bounds: Rect::new(0, 0, 0, 0),
    }
  }
  let mut minimum = keypoints[0].response
  let mut maximum = keypoints[0].response
  let mut total = 0.0
  let mut i = 0
  while i < keypoints.length() {
    let response = keypoints[i].response
    if response < minimum {
      minimum = response
    }
    if response > maximum {
      maximum = response
    }
    total = total + response
    i = i + 1
  }
  {
    count: keypoints.length(),
    mean_response: total / Double::from_int(keypoints.length()),
    minimum_response: minimum,
    maximum_response: maximum,
    centroid: keypoint_centroid(keypoints),
    bounds: keypoint_bounds(keypoints),
  }
}

///|
pub fn keypoint_response_histogram(
  keypoints : Array[Keypoint],
  bins : Int,
  minimum : Double,
  maximum : Double,
) -> Array[Int] {
  if bins <= 0 {
    return []
  }
  let result = Array::make(bins, 0)
  let high = if maximum <= minimum { minimum + 1.0 } else { maximum }
  let span = high - minimum
  let mut i = 0
  while i < keypoints.length() {
    let mut slot = ((keypoints[i].response - minimum) *
    Double::from_int(bins) /
    span).to_int()
    if slot < 0 {
      slot = 0
    }
    if slot >= bins {
      slot = bins - 1
    }
    result[slot] = result[slot] + 1
    i = i + 1
  }
  result
}

///|
pub fn keypoint_orientation_histogram(
  keypoints : Array[Keypoint],
  bins : Int,
) -> Array[Int] {
  if bins <= 0 {
    return []
  }
  let result = Array::make(bins, 0)
  let width = feature_pi() * 2.0 / Double::from_int(bins)
  let mut i = 0
  while i < keypoints.length() {
    let normalized = normalize_angle(keypoints[i].angle)
    let shifted = normalized + feature_pi()
    let mut slot = (shifted / width).to_int()
    if slot < 0 {
      slot = 0
    }
    if slot >= bins {
      slot = bins - 1
    }
    result[slot] = result[slot] + 1
    i = i + 1
  }
  result
}

///|
fn cell_for_keypoint(
  keypoint : Keypoint,
  width : Int,
  height : Int,
  grid_width : Int,
  grid_height : Int,
) -> Int? {
  if width <= 0 || height <= 0 || grid_width <= 0 || grid_height <= 0 {
    return None
  }
  let mut cell_x = keypoint.x * grid_width / width
  let mut cell_y = keypoint.y * grid_height / height
  if cell_x < 0 {
    cell_x = 0
  }
  if cell_y < 0 {
    cell_y = 0
  }
  if cell_x >= grid_width {
    cell_x = grid_width - 1
  }
  if cell_y >= grid_height {
    cell_y = grid_height - 1
  }
  Some(cell_y * grid_width + cell_x)
}

///|
pub fn keypoint_grid_counts(
  keypoints : Array[Keypoint],
  width : Int,
  height : Int,
  grid_width : Int,
  grid_height : Int,
) -> Array[Int] {
  if grid_width <= 0 || grid_height <= 0 {
    return []
  }
  let counts = Array::make(grid_width * grid_height, 0)
  let mut i = 0
  while i < keypoints.length() {
    match
      cell_for_keypoint(keypoints[i], width, height, grid_width, grid_height) {
      None => ()
      Some(cell) => counts[cell] = counts[cell] + 1
    }
    i = i + 1
  }
  counts
}

///|
pub fn select_keypoints_grid(
  keypoints : Array[Keypoint],
  width : Int,
  height : Int,
  grid_width : Int,
  grid_height : Int,
  per_cell : Int,
) -> Array[Keypoint] {
  if grid_width <= 0 || grid_height <= 0 || per_cell <= 0 {
    return []
  }
  let counts = Array::make(grid_width * grid_height, 0)
  let result : Array[Keypoint] = []
  let mut i = 0
  while i < keypoints.length() {
    match
      cell_for_keypoint(keypoints[i], width, height, grid_width, grid_height) {
      None => ()
      Some(cell) =>
        if counts[cell] < per_cell {
          result.push(keypoints[i])
          counts[cell] = counts[cell] + 1
        }
    }
    i = i + 1
  }
  result
}

///|
pub fn keypoints_in_rect(
  keypoints : Array[Keypoint],
  rect : Rect,
) -> Array[Keypoint] {
  let result : Array[Keypoint] = []
  let mut i = 0
  while i < keypoints.length() {
    let point = keypoints[i]
    if point.x >= rect.x0 &&
      point.x < rect.x1 &&
      point.y >= rect.y0 &&
      point.y < rect.y1 {
      result.push(point)
    }
    i = i + 1
  }
  result
}

///|
pub fn keypoint_response_sum(keypoints : Array[Keypoint]) -> Double {
  let mut total = 0.0
  let mut i = 0
  while i < keypoints.length() {
    total = total + keypoints[i].response
    i = i + 1
  }
  total
}

///|
pub fn keypoint_scale_histogram(
  keypoints : Array[Keypoint],
  bins : Int,
) -> Array[Int] {
  if bins <= 0 {
    return []
  }
  let result = Array::make(bins, 0)
  let mut i = 0
  while i < keypoints.length() {
    let size = if keypoints[i].size < 0 { 0 } else { keypoints[i].size }
    let mut slot = size / 8
    if slot >= bins {
      slot = bins - 1
    }
    result[slot] = result[slot] + 1
    i = i + 1
  }
  result
}

///|
fn feature_popcount(value : Byte) -> Int {
  let mut number = value.to_int()
  let mut count = 0
  while number > 0 {
    count = count + (number & 1)
    number = number >> 1
  }
  count
}

///|
pub fn descriptor_popcount(descriptor : Descriptor) -> Int {
  let mut total = 0
  let mut i = 0
  while i < descriptor.data.length() {
    total = total + feature_popcount(descriptor.data[i])
    i = i + 1
  }
  total
}

///|
pub(all) struct DescriptorStats {
  count : Int
  bytes : Int
  mean_popcount : Double
  minimum_popcount : Int
  maximum_popcount : Int
  bit_balance : Double
}

///|
pub fn summarize_descriptors(
  descriptors : Array[Descriptor],
) -> DescriptorStats {
  if descriptors.length() == 0 {
    return {
      count: 0,
      bytes: 0,
      mean_popcount: 0.0,
      minimum_popcount: 0,
      maximum_popcount: 0,
      bit_balance: 0.0,
    }
  }
  let mut bytes = 0
  let mut total_bits = 0
  let mut minimum = 2147483647
  let mut maximum = 0
  let mut i = 0
  while i < descriptors.length() {
    let descriptor = descriptors[i]
    if descriptor.data.length() > bytes {
      bytes = descriptor.data.length()
    }
    let bits = descriptor_popcount(descriptor)
    total_bits = total_bits + bits
    if bits < minimum {
      minimum = bits
    }
    if bits > maximum {
      maximum = bits
    }
    i = i + 1
  }
  let capacity = bytes * 8 * descriptors.length()
  let balance = if capacity == 0 {
    0.0
  } else {
    Double::from_int(total_bits) / Double::from_int(capacity)
  }
  {
    count: descriptors.length(),
    bytes,
    mean_popcount: Double::from_int(total_bits) /
    Double::from_int(descriptors.length()),
    minimum_popcount: minimum,
    maximum_popcount: maximum,
    bit_balance: balance,
  }
}

///|
pub fn descriptor_bit_histogram(descriptors : Array[Descriptor]) -> Array[Int] {
  let mut bytes = 0
  let mut i = 0
  while i < descriptors.length() {
    if descriptors[i].data.length() > bytes {
      bytes = descriptors[i].data.length()
    }
    i = i + 1
  }
  let result = Array::make(bytes * 8, 0)
  i = 0
  while i < descriptors.length() {
    let descriptor = descriptors[i]
    let mut byte_index = 0
    while byte_index < descriptor.data.length() {
      let value = descriptor.data[byte_index].to_int()
      let mut bit = 0
      while bit < 8 {
        if ((value >> bit) & 1) != 0 {
          result[byte_index * 8 + bit] = result[byte_index * 8 + bit] + 1
        }
        bit = bit + 1
      }
      byte_index = byte_index + 1
    }
    i = i + 1
  }
  result
}

///|
pub fn descriptors_equal(left : Descriptor, right : Descriptor) -> Bool {
  if left.data.length() != right.data.length() {
    return false
  }
  let mut i = 0
  while i < left.data.length() {
    if left.data[i] != right.data[i] {
      return false
    }
    i = i + 1
  }
  true
}

///|
pub fn descriptor_mean_profile(
  descriptors : Array[Descriptor],
) -> Array[Double] {
  let stats = summarize_descriptors(descriptors)
  let result = Array::make(stats.bytes, 0.0)
  if descriptors.length() == 0 {
    return result
  }
  let mut i = 0
  while i < descriptors.length() {
    let mut byte_index = 0
    while byte_index < descriptors[i].data.length() {
      result[byte_index] = result[byte_index] +
        Double::from_int(descriptors[i].data[byte_index].to_int())
      byte_index = byte_index + 1
    }
    i = i + 1
  }
  i = 0
  while i < result.length() {
    result[i] = result[i] / Double::from_int(descriptors.length())
    i = i + 1
  }
  result
}

///|
pub fn descriptor_variance_profile(
  descriptors : Array[Descriptor],
) -> Array[Double] {
  let mean = descriptor_mean_profile(descriptors)
  let result = Array::make(mean.length(), 0.0)
  if descriptors.length() == 0 {
    return result
  }
  let mut i = 0
  while i < descriptors.length() {
    let mut byte_index = 0
    while byte_index < descriptors[i].data.length() {
      let difference = Double::from_int(
          descriptors[i].data[byte_index].to_int(),
        ) -
        mean[byte_index]
      result[byte_index] = result[byte_index] + difference * difference
      byte_index = byte_index + 1
    }
    i = i + 1
  }
  i = 0
  while i < result.length() {
    result[i] = result[i] / Double::from_int(descriptors.length())
    i = i + 1
  }
  result
}

///|
pub fn descriptor_distance_matrix(
  query : Array[Descriptor],
  train : Array[Descriptor],
) -> Array[Array[Int]] {
  let result : Array[Array[Int]] = []
  let mut i = 0
  while i < query.length() {
    let row = Array::make(train.length(), 0)
    let mut j = 0
    while j < train.length() {
      row[j] = hamming_distance(query[i], train[j])
      j = j + 1
    }
    result.push(row)
    i = i + 1
  }
  result
}

///|
pub(all) struct PatchStats {
  count : Int
  mean : Double
  variance : Double
  minimum : Int
  maximum : Int
  energy : Double
}

///|
pub fn describe_patch(
  img : GrayImage,
  keypoint : Keypoint,
  radius : Int,
) -> PatchStats {
  let safe_radius = if radius < 0 { 0 } else { radius }
  let count = (safe_radius * 2 + 1) * (safe_radius * 2 + 1)
  if count <= 0 {
    return {
      count: 0,
      mean: 0.0,
      variance: 0.0,
      minimum: 0,
      maximum: 0,
      energy: 0.0,
    }
  }
  let mut total = 0.0
  let mut square_total = 0.0
  let mut minimum = 255
  let mut maximum = 0
  let mut dy = -safe_radius
  while dy <= safe_radius {
    let mut dx = -safe_radius
    while dx <= safe_radius {
      let value = img.get(keypoint.x + dx, keypoint.y + dy)
      let numeric = Double::from_int(value)
      total = total + numeric
      square_total = square_total + numeric * numeric
      if value < minimum {
        minimum = value
      }
      if value > maximum {
        maximum = value
      }
      dx = dx + 1
    }
    dy = dy + 1
  }
  let mean = total / Double::from_int(count)
  let variance = square_total / Double::from_int(count) - mean * mean
  {
    count,
    mean,
    variance: if variance < 0.0 {
      0.0
    } else {
      variance
    },
    minimum,
    maximum,
    energy: square_total,
  }
}

///|
pub fn keypoint_patch_statistics(
  img : GrayImage,
  keypoints : Array[Keypoint],
  radius : Int,
) -> Array[PatchStats] {
  let result : Array[PatchStats] = []
  let mut i = 0
  while i < keypoints.length() {
    result.push(describe_patch(img, keypoints[i], radius))
    i = i + 1
  }
  result
}

///|
pub fn keypoint_response_variance(keypoints : Array[Keypoint]) -> Double {
  if keypoints.length() == 0 {
    return 0.0
  }
  let summary = summarize_keypoints(keypoints)
  let mut total = 0.0
  let mut i = 0
  while i < keypoints.length() {
    let difference = keypoints[i].response - summary.mean_response
    total = total + difference * difference
    i = i + 1
  }
  total / Double::from_int(keypoints.length())
}

///|
pub fn descriptor_hamming_histogram(
  query : Array[Descriptor],
  train : Array[Descriptor],
  bins : Int,
) -> Array[Int] {
  if bins <= 0 {
    return []
  }
  let result = Array::make(bins, 0)
  let mut i = 0
  while i < query.length() {
    let mut j = 0
    while j < train.length() {
      let distance = hamming_distance(query[i], train[j])
      let mut slot = distance * bins / 256
      if slot >= bins {
        slot = bins - 1
      }
      result[slot] = result[slot] + 1
      j = j + 1
    }
    i = i + 1
  }
  result
}

///|
pub fn keypoint_octave_histogram(
  keypoints : Array[Keypoint],
  bins : Int,
) -> Array[Int] {
  if bins <= 0 {
    return []
  }
  let result = Array::make(bins, 0)
  let mut i = 0
  while i < keypoints.length() {
    let mut octave = keypoints[i].octave
    if octave < 0 {
      octave = 0
    }
    if octave >= bins {
      octave = bins - 1
    }
    result[octave] = result[octave] + 1
    i = i + 1
  }
  result
}
