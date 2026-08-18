// Additional byte-safe filters for texture inspection and robust feature input.

///|
pub(all) struct Kernel1D {
  radius : Int
  weights : Array[Double]
  normalizer : Double
}

///|
pub fn Kernel1D::box(radius : Int) -> Kernel1D {
  let safe_radius = if radius < 0 { 0 } else { radius }
  let size = safe_radius * 2 + 1
  {
    radius: safe_radius,
    weights: Array::make(size, 1.0),
    normalizer: Double::from_int(size),
  }
}

///|
pub fn Kernel1D::triangle(radius : Int) -> Kernel1D {
  let safe_radius = if radius < 0 { 0 } else { radius }
  let weights = Array::make(safe_radius * 2 + 1, 0.0)
  let mut total = 0.0
  let mut offset = -safe_radius
  while offset <= safe_radius {
    let weight = Double::from_int(
      safe_radius + 1 - (if offset < 0 { -offset } else { offset }),
    )
    weights[offset + safe_radius] = weight
    total = total + weight
    offset = offset + 1
  }
  { radius: safe_radius, weights, normalizer: total }
}

///|
pub fn Kernel1D::gaussian_like(radius : Int, sigma : Double) -> Kernel1D {
  let safe_radius = if radius < 0 { 0 } else { radius }
  let safe_sigma = if sigma <= 0.0 { 1.0 } else { sigma }
  let weights = Array::make(safe_radius * 2 + 1, 0.0)
  let mut total = 0.0
  let mut offset = -safe_radius
  while offset <= safe_radius {
    let distance = Double::from_int(if offset < 0 { -offset } else { offset })
    let scaled = distance / safe_sigma
    let weight = 1.0 / (1.0 + scaled * scaled)
    weights[offset + safe_radius] = weight
    total = total + weight
    offset = offset + 1
  }
  { radius: safe_radius, weights, normalizer: total }
}

///|
pub fn Kernel1D::normalized(self : Kernel1D) -> Kernel1D {
  if self.normalizer <= 0.0 {
    return self
  }
  let weights = Array::make(self.weights.length(), 0.0)
  let mut i = 0
  while i < self.weights.length() {
    weights[i] = self.weights[i] / self.normalizer
    i = i + 1
  }
  { radius: self.radius, weights, normalizer: 1.0 }
}

///|
fn filter_clamp(value : Double) -> Int {
  let rounded = (value + 0.5).to_int()
  if rounded < 0 {
    0
  } else if rounded > 255 {
    255
  } else {
    rounded
  }
}

///|
pub fn apply_kernel_horizontal(img : GrayImage, kernel : Kernel1D) -> GrayImage {
  let result = GrayImage::new(img.width, img.height)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      let mut value = 0.0
      let mut offset = -kernel.radius
      while offset <= kernel.radius {
        let weight = kernel.weights[offset + kernel.radius]
        value = value +
          weight *
          Double::from_int(img.sample(x + offset, y, BorderMode::Clamp))
        offset = offset + 1
      }
      let normalized = if kernel.normalizer == 1.0 {
        value
      } else {
        value / kernel.normalizer
      }
      result.set(x, y, filter_clamp(normalized))
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn apply_kernel_vertical(img : GrayImage, kernel : Kernel1D) -> GrayImage {
  let result = GrayImage::new(img.width, img.height)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      let mut value = 0.0
      let mut offset = -kernel.radius
      while offset <= kernel.radius {
        let weight = kernel.weights[offset + kernel.radius]
        value = value +
          weight *
          Double::from_int(img.sample(x, y + offset, BorderMode::Clamp))
        offset = offset + 1
      }
      let normalized = if kernel.normalizer == 1.0 {
        value
      } else {
        value / kernel.normalizer
      }
      result.set(x, y, filter_clamp(normalized))
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn apply_separable_kernel(img : GrayImage, kernel : Kernel1D) -> GrayImage {
  apply_kernel_vertical(apply_kernel_horizontal(img, kernel), kernel)
}

///|
pub fn smooth_triangle(img : GrayImage, radius : Int) -> GrayImage {
  apply_separable_kernel(img, Kernel1D::triangle(radius))
}

///|
pub fn smooth_gaussian_like(
  img : GrayImage,
  radius : Int,
  sigma : Double,
) -> GrayImage {
  apply_separable_kernel(img, Kernel1D::gaussian_like(radius, sigma))
}

///|
fn filter_sort(values : Array[Int]) -> Unit {
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
pub fn rank_filter(img : GrayImage, radius : Int, rank : Int) -> GrayImage {
  let result = GrayImage::new(img.width, img.height)
  let safe_radius = if radius < 0 { 0 } else { radius }
  let side = safe_radius * 2 + 1
  let count = side * side
  if count <= 0 {
    return result
  }
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      let values = Array::make(count, 0)
      let mut cursor = 0
      let mut dy = -safe_radius
      while dy <= safe_radius {
        let mut dx = -safe_radius
        while dx <= safe_radius {
          values[cursor] = img.sample(x + dx, y + dy, BorderMode::Clamp)
          cursor = cursor + 1
          dx = dx + 1
        }
        dy = dy + 1
      }
      filter_sort(values)
      let slot = if rank < 0 {
        0
      } else if rank >= count {
        count - 1
      } else {
        rank
      }
      result.set(x, y, values[slot])
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn median_filter(img : GrayImage, radius : Int) -> GrayImage {
  let safe_radius = if radius < 0 { 0 } else { radius }
  let side = safe_radius * 2 + 1
  rank_filter(img, safe_radius, side * side / 2)
}

///|
pub fn percentile_filter(
  img : GrayImage,
  radius : Int,
  percentile : Double,
) -> GrayImage {
  let safe_radius = if radius < 0 { 0 } else { radius }
  let side = safe_radius * 2 + 1
  let count = side * side
  let mut probability = percentile
  if probability < 0.0 {
    probability = 0.0
  }
  if probability > 1.0 {
    probability = 1.0
  }
  rank_filter(
    img,
    safe_radius,
    (probability * Double::from_int(count - 1)).to_int(),
  )
}

///|
pub fn laplacian_response(img : GrayImage) -> GrayImage {
  let result = GrayImage::new(img.width, img.height)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      let center = img.get(x, y) * 4
      let neighbors = img.sample(x - 1, y, BorderMode::Clamp) +
        img.sample(x + 1, y, BorderMode::Clamp) +
        img.sample(x, y - 1, BorderMode::Clamp) +
        img.sample(x, y + 1, BorderMode::Clamp)
      let response = center - neighbors
      result.set(x, y, if response < 0 { -response } else { response })
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn unsharp_mask(
  img : GrayImage,
  radius : Int,
  amount : Double,
) -> GrayImage {
  let blurred = smooth_gaussian_like(
    img,
    if radius < 0 {
      0
    } else {
      radius
    },
    1.0,
  )
  let result = GrayImage::new(img.width, img.height)
  let safe_amount = if amount < 0.0 { 0.0 } else { amount }
  let mut i = 0
  while i < img.data.length() {
    let detail = Double::from_int(img.data[i] - blurred.data[i])
    result.data[i] = filter_clamp(
      Double::from_int(img.data[i]) + detail * safe_amount,
    )
    i = i + 1
  }
  result
}

///|
pub(all) struct ThresholdSummary {
  threshold : Int
  foreground : Int
  background : Int
  mean_foreground : Double
  mean_background : Double
}

///|
pub fn otsu_summary(img : GrayImage) -> ThresholdSummary {
  let histogram = img.histogram()
  let total = img.data.length()
  if total == 0 {
    return {
      threshold: 0,
      foreground: 0,
      background: 0,
      mean_foreground: 0.0,
      mean_background: 0.0,
    }
  }
  let mut weighted_total = 0
  let mut i = 0
  while i < 256 {
    weighted_total = weighted_total + histogram[i] * i
    i = i + 1
  }
  let mut weight_background = 0
  let mut sum_background = 0
  let mut best_threshold = 0
  let mut best_between = -1.0
  i = 0
  while i < 256 {
    weight_background = weight_background + histogram[i]
    sum_background = sum_background + histogram[i] * i
    let weight_foreground = total - weight_background
    if weight_background > 0 && weight_foreground > 0 {
      let mean_background = Double::from_int(sum_background) /
        Double::from_int(weight_background)
      let mean_foreground = Double::from_int(weighted_total - sum_background) /
        Double::from_int(weight_foreground)
      let difference = mean_background - mean_foreground
      let between = Double::from_int(weight_background * weight_foreground) *
        difference *
        difference
      if between > best_between {
        best_between = between
        best_threshold = i
      }
    }
    i = i + 1
  }
  let threshold_image = binary_threshold(img, best_threshold)
  let foreground_count = threshold_image.data.length() -
    count_zero_pixels(threshold_image)
  let background_count = threshold_image.data.length() - foreground_count
  let foreground_sum = sum_selected_pixels(img, threshold_image, true)
  let background_sum = sum_selected_pixels(img, threshold_image, false)
  {
    threshold: best_threshold,
    foreground: foreground_count,
    background: background_count,
    mean_foreground: if foreground_count == 0 {
      0.0
    } else {
      foreground_sum / Double::from_int(foreground_count)
    },
    mean_background: if background_count == 0 {
      0.0
    } else {
      background_sum / Double::from_int(background_count)
    },
  }
}

///|
fn count_zero_pixels(img : GrayImage) -> Int {
  let mut count = 0
  let mut i = 0
  while i < img.data.length() {
    if img.data[i] == 0 {
      count = count + 1
    }
    i = i + 1
  }
  count
}

///|
fn sum_selected_pixels(
  img : GrayImage,
  mask : GrayImage,
  foreground : Bool,
) -> Double {
  let mut total = 0.0
  let mut i = 0
  while i < img.data.length() && i < mask.data.length() {
    let selected = if foreground { mask.data[i] > 0 } else { mask.data[i] == 0 }
    if selected {
      total = total + Double::from_int(img.data[i])
    }
    i = i + 1
  }
  total
}

///|
pub fn otsu_threshold(img : GrayImage) -> Int {
  otsu_summary(img).threshold
}

///|
pub fn threshold_otsu(img : GrayImage) -> GrayImage {
  binary_threshold(img, otsu_threshold(img))
}

///|
pub fn threshold_sauvola(
  img : GrayImage,
  radius : Int,
  sensitivity : Double,
  bias : Double,
) -> GrayImage {
  let result = GrayImage::new(img.width, img.height)
  let integral = IntegralImage::build(img)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      let window = integral.window(x, y, radius)
      let mean = integral.mean(window)
      let variance = integral.variance(window)
      let deviation = if variance <= 0.0 {
        0.0
      } else {
        let mut estimate = if variance > 1.0 { variance } else { 1.0 }
        let mut i = 0
        while i < 16 {
          estimate = (estimate + variance / estimate) / 2.0
          i = i + 1
        }
        estimate
      }
      let threshold = mean * (1.0 + sensitivity * (deviation / 128.0 - 1.0)) +
        bias
      if Double::from_int(img.get(x, y)) >= threshold {
        result.set(x, y, 255)
      }
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn contrast_stretch(img : GrayImage, low : Int, high : Int) -> GrayImage {
  let result = GrayImage::new(img.width, img.height)
  let mut minimum = low
  let mut maximum = high
  if minimum < 0 {
    minimum = 0
  }
  if maximum > 255 {
    maximum = 255
  }
  if maximum <= minimum {
    return result
  }
  let span = maximum - minimum
  let mut i = 0
  while i < img.data.length() {
    let value = img.data[i]
    let mapped = if value <= minimum {
      0
    } else if value >= maximum {
      255
    } else {
      (value - minimum) * 255 / span
    }
    result.data[i] = mapped
    i = i + 1
  }
  result
}

///|
pub fn quantize_image(img : GrayImage, levels : Int) -> GrayImage {
  let result = GrayImage::new(img.width, img.height)
  if levels <= 1 {
    return result
  }
  let steps = levels - 1
  let mut i = 0
  while i < img.data.length() {
    let quantized = (img.data[i] * steps + 127) / 255
    result.data[i] = quantized * 255 / steps
    i = i + 1
  }
  result
}

///|
pub fn image_add(left : GrayImage, right : GrayImage) -> GrayImage {
  let width = if left.width < right.width { left.width } else { right.width }
  let height = if left.height < right.height {
    left.height
  } else {
    right.height
  }
  let result = GrayImage::new(width, height)
  let mut y = 0
  while y < height {
    let mut x = 0
    while x < width {
      result.set(x, y, left.get(x, y) + right.get(x, y))
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn image_subtract(left : GrayImage, right : GrayImage) -> GrayImage {
  let width = if left.width < right.width { left.width } else { right.width }
  let height = if left.height < right.height {
    left.height
  } else {
    right.height
  }
  let result = GrayImage::new(width, height)
  let mut y = 0
  while y < height {
    let mut x = 0
    while x < width {
      result.set(x, y, left.get(x, y) - right.get(x, y))
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn image_blend(
  left : GrayImage,
  right : GrayImage,
  weight : Double,
) -> GrayImage {
  let width = if left.width < right.width { left.width } else { right.width }
  let height = if left.height < right.height {
    left.height
  } else {
    right.height
  }
  let result = GrayImage::new(width, height)
  let safe_weight = if weight < 0.0 {
    0.0
  } else if weight > 1.0 {
    1.0
  } else {
    weight
  }
  let mut y = 0
  while y < height {
    let mut x = 0
    while x < width {
      let value = Double::from_int(left.get(x, y)) * (1.0 - safe_weight) +
        Double::from_int(right.get(x, y)) * safe_weight
      result.set(x, y, filter_clamp(value))
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn local_binary_pattern(img : GrayImage, radius : Int) -> GrayImage {
  let result = GrayImage::new(img.width, img.height)
  let safe_radius = if radius <= 0 { 1 } else { radius }
  let offsets : Array[(Int, Int)] = [
    (0, -1),
    (1, -1),
    (1, 0),
    (1, 1),
    (0, 1),
    (-1, 1),
    (-1, 0),
    (-1, -1),
  ]
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      let center = img.get(x, y)
      let mut code = 0
      let mut i = 0
      while i < offsets.length() {
        let (dx, dy) = offsets[i]
        if img.sample(
            x + dx * safe_radius,
            y + dy * safe_radius,
            BorderMode::Clamp,
          ) >=
          center {
          code = code | (1 << i)
        }
        i = i + 1
      }
      result.set(x, y, code)
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn texture_histogram(img : GrayImage) -> Array[Int] {
  let histogram = Array::make(256, 0)
  let mut i = 0
  while i < img.data.length() {
    histogram[img.data[i]] = histogram[img.data[i]] + 1
    i = i + 1
  }
  histogram
}

///|
pub fn block_texture_histogram(img : GrayImage, rect : Rect) -> Array[Int] {
  let clipped = img.crop(rect)
  texture_histogram(local_binary_pattern(clipped, 1))
}

///|
pub fn edge_strength(img : GrayImage) -> GrayImage {
  let gradients = sobel_gradients(img)
  gradient_magnitude(gradients)
}

///|
pub fn edge_threshold(img : GrayImage, threshold : Int) -> GrayImage {
  binary_threshold(edge_strength(img), threshold)
}

///|
pub fn edge_density(img : GrayImage, threshold : Int) -> Double {
  if img.data.length() == 0 {
    return 0.0
  }
  let edges = edge_threshold(img, threshold)
  let mut count = 0
  let mut i = 0
  while i < edges.data.length() {
    if edges.data[i] > 0 {
      count = count + 1
    }
    i = i + 1
  }
  Double::from_int(count) / Double::from_int(edges.data.length())
}

///|
pub fn gradient_energy(img : GrayImage, rect : Rect) -> Double {
  let field = sobel_gradients(img)
  let (left, top, right, bottom) = (
    if rect.x0 < 0 {
      0
    } else if rect.x0 > img.width {
      img.width
    } else {
      rect.x0
    },
    if rect.y0 < 0 {
      0
    } else if rect.y0 > img.height {
      img.height
    } else {
      rect.y0
    },
    if rect.x1 > img.width {
      img.width
    } else if rect.x1 < 0 {
      0
    } else {
      rect.x1
    },
    if rect.y1 > img.height {
      img.height
    } else if rect.y1 < 0 {
      0
    } else {
      rect.y1
    },
  )
  let mut total = 0.0
  let mut count = 0
  let mut y = top
  while y < bottom {
    let mut x = left
    while x < right {
      let index = y * img.width + x
      total = total +
        field.gx[index] * field.gx[index] +
        field.gy[index] * field.gy[index]
      count = count + 1
      x = x + 1
    }
    y = y + 1
  }
  if count == 0 {
    0.0
  } else {
    total / Double::from_int(count)
  }
}

///|
pub fn non_maximum_response(response : GrayImage, radius : Int) -> GrayImage {
  let result = GrayImage::new(response.width, response.height)
  let safe_radius = if radius < 0 { 0 } else { radius }
  let mut y = 0
  while y < response.height {
    let mut x = 0
    while x < response.width {
      let value = response.get(x, y)
      let mut maximum = true
      let mut dy = -safe_radius
      while dy <= safe_radius {
        let mut dx = -safe_radius
        while dx <= safe_radius {
          if (dx != 0 || dy != 0) && response.get(x + dx, y + dy) > value {
            maximum = false
          }
          dx = dx + 1
        }
        dy = dy + 1
      }
      if maximum {
        result.set(x, y, value)
      }
      x = x + 1
    }
    y = y + 1
  }
  result
}
