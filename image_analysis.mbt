// Integral-image statistics, binary morphology, and connected-region analysis.
// These routines are deliberately byte-oriented so they can be used by the
// feature pipeline without introducing an image codec or native dependency.

///|
pub(all) struct IntegralImage {
  width : Int
  height : Int
  sums : Array[Double]
  squares : Array[Double]
}

///|
fn clipped_rect(rect : Rect, width : Int, height : Int) -> (Int, Int, Int, Int) {
  let left = if rect.x0 < 0 {
    0
  } else if rect.x0 > width {
    width
  } else {
    rect.x0
  }
  let top = if rect.y0 < 0 {
    0
  } else if rect.y0 > height {
    height
  } else {
    rect.y0
  }
  let right = if rect.x1 < left {
    left
  } else if rect.x1 > width {
    width
  } else {
    rect.x1
  }
  let bottom = if rect.y1 < top {
    top
  } else if rect.y1 > height {
    height
  } else {
    rect.y1
  }
  (left, top, right, bottom)
}

///|
pub fn IntegralImage::build(img : GrayImage) -> IntegralImage {
  let stride = img.width + 1
  let row_count = img.height + 1
  let sums = Array::make(stride * row_count, 0.0)
  let squares = Array::make(stride * row_count, 0.0)
  let mut y = 1
  while y <= img.height {
    let mut row_sum = 0.0
    let mut row_square = 0.0
    let mut x = 1
    while x <= img.width {
      let value = Double::from_int(img.get(x - 1, y - 1))
      row_sum = row_sum + value
      row_square = row_square + value * value
      let index = y * stride + x
      sums[index] = sums[(y - 1) * stride + x] + row_sum
      squares[index] = squares[(y - 1) * stride + x] + row_square
      x = x + 1
    }
    y = y + 1
  }
  { width: img.width, height: img.height, sums, squares }
}

///|
pub fn IntegralImage::sum(self : IntegralImage, rect : Rect) -> Double {
  let (left, top, right, bottom) = clipped_rect(rect, self.width, self.height)
  if right <= left || bottom <= top {
    return 0.0
  }
  let stride = self.width + 1
  self.sums[bottom * stride + right] -
  self.sums[top * stride + right] -
  self.sums[bottom * stride + left] +
  self.sums[top * stride + left]
}

///|
pub fn IntegralImage::square_sum(self : IntegralImage, rect : Rect) -> Double {
  let (left, top, right, bottom) = clipped_rect(rect, self.width, self.height)
  if right <= left || bottom <= top {
    return 0.0
  }
  let stride = self.width + 1
  self.squares[bottom * stride + right] -
  self.squares[top * stride + right] -
  self.squares[bottom * stride + left] +
  self.squares[top * stride + left]
}

///|
pub fn IntegralImage::count(self : IntegralImage, rect : Rect) -> Int {
  let (left, top, right, bottom) = clipped_rect(rect, self.width, self.height)
  if right <= left || bottom <= top {
    0
  } else {
    (right - left) * (bottom - top)
  }
}

///|
pub fn IntegralImage::mean(self : IntegralImage, rect : Rect) -> Double {
  let count = self.count(rect)
  if count <= 0 {
    0.0
  } else {
    self.sum(rect) / Double::from_int(count)
  }
}

///|
pub fn IntegralImage::variance(self : IntegralImage, rect : Rect) -> Double {
  let count = self.count(rect)
  if count <= 0 {
    return 0.0
  }
  let mean = self.mean(rect)
  let value = self.square_sum(rect) / Double::from_int(count) - mean * mean
  if value < 0.0 {
    0.0
  } else {
    value
  }
}

///|
pub fn IntegralImage::window(
  self : IntegralImage,
  x : Int,
  y : Int,
  radius : Int,
) -> Rect {
  let safe_radius = if radius < 0 { 0 } else { radius }
  let requested = Rect::new(
    x - safe_radius,
    y - safe_radius,
    x + safe_radius + 1,
    y + safe_radius + 1,
  )
  let (left, top, right, bottom) = clipped_rect(
    requested,
    self.width,
    self.height,
  )
  Rect::new(left, top, right, bottom)
}

///|
pub fn local_mean(img : GrayImage, radius : Int) -> GrayImage {
  let result = GrayImage::new(img.width, img.height)
  let integral = IntegralImage::build(img)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      let mean = integral.mean(integral.window(x, y, radius))
      let value = (mean + 0.5).to_int()
      result.set(x, y, value)
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn local_variance(img : GrayImage, radius : Int) -> Array[Double] {
  let result = Array::make(img.width * img.height, 0.0)
  let integral = IntegralImage::build(img)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      result[y * img.width + x] = integral.variance(
        integral.window(x, y, radius),
      )
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn adaptive_threshold(
  img : GrayImage,
  radius : Int,
  offset : Int,
) -> GrayImage {
  let result = GrayImage::new(img.width, img.height)
  let integral = IntegralImage::build(img)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      let mean = integral.mean(integral.window(x, y, radius))
      if Double::from_int(img.get(x, y)) >= mean - Double::from_int(offset) {
        result.set(x, y, 255)
      }
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn binary_threshold(img : GrayImage, threshold : Int) -> GrayImage {
  let result = GrayImage::new(img.width, img.height)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      if img.get(x, y) >= threshold {
        result.set(x, y, 255)
      }
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
fn binary_neighborhood_has(
  img : GrayImage,
  x : Int,
  y : Int,
  radius : Int,
  want_all : Bool,
) -> Bool {
  let safe_radius = if radius < 0 { 0 } else { radius }
  let mut found = if want_all { true } else { false }
  let mut dy = -safe_radius
  while dy <= safe_radius {
    let mut dx = -safe_radius
    while dx <= safe_radius {
      let on = img.get(x + dx, y + dy) > 0
      if want_all && !on {
        return false
      }
      if !want_all && on {
        found = true
      }
      dx = dx + 1
    }
    dy = dy + 1
  }
  found
}

///|
pub fn binary_dilate(img : GrayImage, radius : Int) -> GrayImage {
  let result = GrayImage::new(img.width, img.height)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      if binary_neighborhood_has(img, x, y, radius, false) {
        result.set(x, y, 255)
      }
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn binary_erode(img : GrayImage, radius : Int) -> GrayImage {
  let result = GrayImage::new(img.width, img.height)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      if binary_neighborhood_has(img, x, y, radius, true) {
        result.set(x, y, 255)
      }
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn binary_open(img : GrayImage, radius : Int) -> GrayImage {
  binary_dilate(binary_erode(img, radius), radius)
}

///|
pub fn binary_close(img : GrayImage, radius : Int) -> GrayImage {
  binary_erode(binary_dilate(img, radius), radius)
}

///|
pub fn binary_boundary(img : GrayImage, radius : Int) -> GrayImage {
  let eroded = binary_erode(img, radius)
  let result = GrayImage::new(img.width, img.height)
  let mut i = 0
  while i < img.data.length() {
    if img.data[i] > 0 && eroded.data[i] == 0 {
      result.data[i] = 255
    }
    i = i + 1
  }
  result
}

///|
pub(all) struct RegionStats {
  label : Int
  area : Int
  bounds : Rect
  centroid : FloatPoint2
  mean : Double
  minimum : Int
  maximum : Int
}

///|
fn region_neighbor(x : Int, y : Int, direction : Int) -> (Int, Int) {
  match direction {
    0 => (x + 1, y)
    1 => (x - 1, y)
    2 => (x, y + 1)
    _ => (x, y - 1)
  }
}

///|
fn label_components_internal(
  binary : GrayImage,
) -> (Array[Int], Array[RegionStats]) {
  let labels = Array::make(binary.width * binary.height, 0)
  let regions : Array[RegionStats] = []
  let mut next_label = 1
  let mut y = 0
  while y < binary.height {
    let mut x = 0
    while x < binary.width {
      let origin_index = y * binary.width + x
      if binary.data[origin_index] > 0 && labels[origin_index] == 0 {
        let queue : Array[(Int, Int)] = [(x, y)]
        labels[origin_index] = next_label
        let mut head = 0
        let mut area = 0
        let mut sum_x = 0.0
        let mut sum_y = 0.0
        let mut sum_value = 0.0
        let mut minimum = 255
        let mut maximum = 0
        let mut left = x
        let mut top = y
        let mut right = x
        let mut bottom = y
        while head < queue.length() {
          let (cx, cy) = queue[head]
          let value = binary.get(cx, cy)
          area = area + 1
          sum_x = sum_x + Double::from_int(cx)
          sum_y = sum_y + Double::from_int(cy)
          sum_value = sum_value + Double::from_int(value)
          if value < minimum {
            minimum = value
          }
          if value > maximum {
            maximum = value
          }
          if cx < left {
            left = cx
          }
          if cy < top {
            top = cy
          }
          if cx > right {
            right = cx
          }
          if cy > bottom {
            bottom = cy
          }
          let mut direction = 0
          while direction < 4 {
            let (nx, ny) = region_neighbor(cx, cy, direction)
            if nx >= 0 && nx < binary.width && ny >= 0 && ny < binary.height {
              let neighbor_index = ny * binary.width + nx
              if binary.data[neighbor_index] > 0 && labels[neighbor_index] == 0 {
                labels[neighbor_index] = next_label
                queue.push((nx, ny))
              }
            }
            direction = direction + 1
          }
          head = head + 1
        }
        regions.push({
          label: next_label,
          area,
          bounds: Rect::new(left, top, right + 1, bottom + 1),
          centroid: FloatPoint2::new(
            sum_x / Double::from_int(area),
            sum_y / Double::from_int(area),
          ),
          mean: sum_value / Double::from_int(area),
          minimum,
          maximum,
        })
        next_label = next_label + 1
      }
      x = x + 1
    }
    y = y + 1
  }
  (labels, regions)
}

///|
pub fn label_components(binary : GrayImage) -> Array[RegionStats] {
  let (_, regions) = label_components_internal(binary)
  regions
}

///|
pub fn region_mask(binary : GrayImage, label : Int) -> GrayImage {
  let (labels, _) = label_components_internal(binary)
  let result = GrayImage::new(binary.width, binary.height)
  let mut i = 0
  while i < labels.length() {
    if label > 0 && labels[i] == label {
      result.data[i] = 255
    }
    i = i + 1
  }
  result
}

///|
pub fn filter_regions(
  regions : Array[RegionStats],
  minimum_area : Int,
  maximum_area : Int,
) -> Array[RegionStats] {
  let result : Array[RegionStats] = []
  let low = if minimum_area < 0 { 0 } else { minimum_area }
  let high = if maximum_area < low { 2147483647 } else { maximum_area }
  let mut i = 0
  while i < regions.length() {
    if regions[i].area >= low && regions[i].area <= high {
      result.push(regions[i])
    }
    i = i + 1
  }
  result
}

///|
pub fn largest_region(regions : Array[RegionStats]) -> RegionStats? {
  if regions.length() == 0 {
    return None
  }
  let mut best = regions[0]
  let mut i = 1
  while i < regions.length() {
    if regions[i].area > best.area {
      best = regions[i]
    }
    i = i + 1
  }
  Some(best)
}

///|
pub fn regions_total_area(regions : Array[RegionStats]) -> Int {
  let mut total = 0
  let mut i = 0
  while i < regions.length() {
    total = total + regions[i].area
    i = i + 1
  }
  total
}

///|
pub fn row_projection(img : GrayImage) -> Array[Int] {
  let result = Array::make(img.height, 0)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      result[y] = result[y] + img.get(x, y)
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn column_projection(img : GrayImage) -> Array[Int] {
  let result = Array::make(img.width, 0)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      result[x] = result[x] + img.get(x, y)
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn projection_peaks(values : Array[Int], minimum : Int) -> Array[Int] {
  let peaks : Array[Int] = []
  if values.length() == 0 {
    return peaks
  }
  let mut i = 0
  while i < values.length() {
    let left_ok = i == 0 || values[i] >= values[i - 1]
    let right_ok = i == values.length() - 1 || values[i] > values[i + 1]
    if values[i] >= minimum && left_ok && right_ok {
      peaks.push(i)
    }
    i = i + 1
  }
  peaks
}

///|
pub fn image_mean(img : GrayImage) -> Double {
  if img.data.length() == 0 {
    0.0
  } else {
    IntegralImage::build(img).mean(Rect::new(0, 0, img.width, img.height))
  }
}

///|
pub fn image_variance(img : GrayImage) -> Double {
  if img.data.length() == 0 {
    0.0
  } else {
    IntegralImage::build(img).variance(Rect::new(0, 0, img.width, img.height))
  }
}

///|
pub fn image_moments(img : GrayImage) -> (Double, Double, Int, Int) {
  if img.data.length() == 0 {
    return (0.0, 0.0, 0, 0)
  }
  let mut minimum = 255
  let mut maximum = 0
  let mut i = 0
  while i < img.data.length() {
    if img.data[i] < minimum {
      minimum = img.data[i]
    }
    if img.data[i] > maximum {
      maximum = img.data[i]
    }
    i = i + 1
  }
  (image_mean(img), image_variance(img), minimum, maximum)
}

///|
pub fn image_mse(left : GrayImage, right : GrayImage) -> Double {
  let width = if left.width < right.width { left.width } else { right.width }
  let height = if left.height < right.height {
    left.height
  } else {
    right.height
  }
  if width <= 0 || height <= 0 {
    return 0.0
  }
  let mut total = 0.0
  let mut y = 0
  while y < height {
    let mut x = 0
    while x < width {
      let difference = Double::from_int(left.get(x, y) - right.get(x, y))
      total = total + difference * difference
      x = x + 1
    }
    y = y + 1
  }
  total / Double::from_int(width * height)
}

///|
pub fn binary_iou(left : GrayImage, right : GrayImage) -> Double {
  let width = if left.width < right.width { left.width } else { right.width }
  let height = if left.height < right.height {
    left.height
  } else {
    right.height
  }
  let mut intersection = 0
  let mut union = 0
  let mut y = 0
  while y < height {
    let mut x = 0
    while x < width {
      let left_on = left.get(x, y) > 0
      let right_on = right.get(x, y) > 0
      if left_on && right_on {
        intersection = intersection + 1
      }
      if left_on || right_on {
        union = union + 1
      }
      x = x + 1
    }
    y = y + 1
  }
  if union == 0 {
    1.0
  } else {
    Double::from_int(intersection) / Double::from_int(union)
  }
}

///|
pub fn pad_image(img : GrayImage, border : Int, value : Int) -> GrayImage {
  let safe = if border < 0 { 0 } else { border }
  let result = GrayImage::new(img.width + safe * 2, img.height + safe * 2)
  result.fill(value)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      result.set(x + safe, y + safe, img.get(x, y))
      x = x + 1
    }
    y = y + 1
  }
  result
}
