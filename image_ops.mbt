// Image construction, sampling, and deterministic synthetic transforms.

///|
fn clamp_int(value : Int, low : Int, high : Int) -> Int {
  if high < low {
    low
  } else if value < low {
    low
  } else if value > high {
    high
  } else {
    value
  }
}

///|
fn reflect_index(index : Int, size : Int) -> Int {
  if size <= 1 {
    0
  } else {
    let mut value = index
    let period = (size - 1) * 2
    while value < 0 {
      value = value + period
    }
    value = value % period
    if value >= size {
      period - value
    } else {
      value
    }
  }
}

///|
fn sample_index(img : GrayImage, x : Int, y : Int, border : BorderMode) -> Int {
  if img.width <= 0 || img.height <= 0 {
    match border {
      Constant(value) => value
      _ => 0
    }
  } else if x >= 0 && x < img.width && y >= 0 && y < img.height {
    img.get(x, y)
  } else {
    match border {
      Constant(value) => value
      Clamp =>
        img.get(clamp_int(x, 0, img.width - 1), clamp_int(y, 0, img.height - 1))
      Reflect =>
        img.get(reflect_index(x, img.width), reflect_index(y, img.height))
    }
  }
}

///|
pub fn GrayImage::clone(self : GrayImage) -> GrayImage {
  let result = GrayImage::new(self.width, self.height)
  let mut i = 0
  while i < self.data.length() {
    result.data[i] = self.data[i]
    i = i + 1
  }
  result
}

///|
pub fn GrayImage::fill(self : GrayImage, value : Int) -> Unit {
  let clamped = if value < 0 { 0 } else if value > 255 { 255 } else { value }
  let mut i = 0
  while i < self.data.length() {
    self.data[i] = clamped
    i = i + 1
  }
}

///|
pub fn GrayImage::crop(self : GrayImage, rect : Rect) -> GrayImage {
  let left = clamp_int(rect.x0, 0, self.width)
  let top = clamp_int(rect.y0, 0, self.height)
  let right = clamp_int(rect.x1, left, self.width)
  let bottom = clamp_int(rect.y1, top, self.height)
  let result = GrayImage::new(right - left, bottom - top)
  let mut y = top
  while y < bottom {
    let mut x = left
    while x < right {
      result.set(x - left, y - top, self.get(x, y))
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn GrayImage::histogram(self : GrayImage) -> Array[Int] {
  let histogram = Array::make(256, 0)
  let mut i = 0
  while i < self.data.length() {
    let value = clamp_int(self.data[i], 0, 255)
    histogram[value] = histogram[value] + 1
    i = i + 1
  }
  histogram
}

///|
pub fn GrayImage::normalize(self : GrayImage) -> GrayImage {
  let result = GrayImage::new(self.width, self.height)
  if self.data.length() == 0 {
    return result
  }
  let mut low = 255
  let mut high = 0
  let mut i = 0
  while i < self.data.length() {
    let value = clamp_int(self.data[i], 0, 255)
    if value < low {
      low = value
    }
    if value > high {
      high = value
    }
    i = i + 1
  }
  if low == high {
    return result
  }
  let span = high - low
  i = 0
  while i < self.data.length() {
    let value = clamp_int(self.data[i], 0, 255)
    let mapped = ((value - low) * 255 + span / 2) / span
    result.data[i] = clamp_int(mapped, 0, 255)
    i = i + 1
  }
  result
}

///|
pub fn GrayImage::resize_nearest(
  self : GrayImage,
  width : Int,
  height : Int,
) -> GrayImage {
  let result = GrayImage::new(width, height)
  if result.width == 0 ||
    result.height == 0 ||
    self.width == 0 ||
    self.height == 0 {
    return result
  }
  let mut y = 0
  while y < result.height {
    let source_y = y * self.height / result.height
    let mut x = 0
    while x < result.width {
      let source_x = x * self.width / result.width
      result.set(x, y, self.get(source_x, source_y))
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn GrayImage::translate(
  self : GrayImage,
  dx : Int,
  dy : Int,
  border : BorderMode,
) -> GrayImage {
  let result = GrayImage::new(self.width, self.height)
  let mut y = 0
  while y < self.height {
    let mut x = 0
    while x < self.width {
      result.set(x, y, sample_index(self, x - dx, y - dy, border))
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn GrayImage::sample(
  self : GrayImage,
  x : Int,
  y : Int,
  border : BorderMode,
) -> Int {
  sample_index(self, x, y, border)
}

///|
fn floor_int(value : Double) -> Int {
  let truncated = value.to_int()
  if Double::from_int(truncated) > value {
    truncated - 1
  } else {
    truncated
  }
}

///|
fn approximate_sin_cos(angle : Double) -> (Double, Double) {
  let pi = 3.141592653589793
  let two_pi = 6.283185307179586
  let mut a = angle
  while a > pi {
    a = a - two_pi
  }
  while a < -pi {
    a = a + two_pi
  }
  let a2 = a * a
  let sin_a = a - a2 * a / 6.0 + a2 * a2 * a / 120.0 - a2 * a2 * a2 / 5040.0
  let cos_a = 1.0 - a2 / 2.0 + a2 * a2 / 24.0 - a2 * a2 * a2 / 720.0
  (sin_a, cos_a)
}

///|
pub fn GrayImage::sample_bilinear(
  self : GrayImage,
  x : Double,
  y : Double,
  border : BorderMode,
) -> Double {
  let x0 = floor_int(x)
  let y0 = floor_int(y)
  let x1 = x0 + 1
  let y1 = y0 + 1
  let fx = x - Double::from_int(x0)
  let fy = y - Double::from_int(y0)
  let p00 = Double::from_int(sample_index(self, x0, y0, border))
  let p10 = Double::from_int(sample_index(self, x1, y0, border))
  let p01 = Double::from_int(sample_index(self, x0, y1, border))
  let p11 = Double::from_int(sample_index(self, x1, y1, border))
  let top = p00 + (p10 - p00) * fx
  let bottom = p01 + (p11 - p01) * fx
  top + (bottom - top) * fy
}

///|
pub fn GrayImage::rotate_about(
  self : GrayImage,
  angle : Double,
  center : FloatPoint2,
  border : BorderMode,
) -> GrayImage {
  let result = GrayImage::new(self.width, self.height)
  let (sin_a, cos_a) = approximate_sin_cos(angle)
  let mut y = 0
  while y < self.height {
    let mut x = 0
    while x < self.width {
      let dx = Double::from_int(x) - center.x
      let dy = Double::from_int(y) - center.y
      let source_x = (cos_a * dx + sin_a * dy + center.x + 0.5).to_int()
      let source_y = (-sin_a * dx + cos_a * dy + center.y + 0.5).to_int()
      result.set(x, y, sample_index(self, source_x, source_y, border))
      x = x + 1
    }
    y = y + 1
  }
  result
}
