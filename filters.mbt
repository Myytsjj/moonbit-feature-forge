// Grayscale preprocessing and gradient analysis.

///|
pub(all) struct GradientField {
  width : Int
  height : Int
  gx : Array[Double]
  gy : Array[Double]
}

///|
fn abs_double(value : Double) -> Double {
  if value < 0.0 {
    -value
  } else {
    value
  }
}

///|
pub fn box_blur(img : GrayImage, radius : Int) -> GrayImage {
  if radius <= 0 {
    return img.clone()
  }
  let result = GrayImage::new(img.width, img.height)
  let diameter = radius * 2 + 1
  let area = diameter * diameter
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      let mut sum = 0
      let mut dy = -radius
      while dy <= radius {
        let mut dx = -radius
        while dx <= radius {
          sum = sum + img.sample(x + dx, y + dy, BorderMode::Clamp)
          dx = dx + 1
        }
        dy = dy + 1
      }
      result.set(x, y, (sum + area / 2) / area)
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn gaussian_blur(img : GrayImage, radius : Int) -> GrayImage {
  if radius <= 0 {
    return img.clone()
  }
  box_blur(box_blur(img, radius), radius)
}

///|
pub fn sobel_gradients(img : GrayImage) -> GradientField {
  let gx = Array::make(img.width * img.height, 0.0)
  let gy = Array::make(img.width * img.height, 0.0)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      let left = img.sample(x - 1, y, BorderMode::Clamp)
      let right = img.sample(x + 1, y, BorderMode::Clamp)
      let top = img.sample(x, y - 1, BorderMode::Clamp)
      let bottom = img.sample(x, y + 1, BorderMode::Clamp)
      let index = y * img.width + x
      gx[index] = Double::from_int(right - left) / 2.0
      gy[index] = Double::from_int(bottom - top) / 2.0
      x = x + 1
    }
    y = y + 1
  }
  { width: img.width, height: img.height, gx, gy }
}

///|
pub fn gradient_magnitude(field : GradientField) -> GrayImage {
  let result = GrayImage::new(field.width, field.height)
  let mut i = 0
  while i < field.gx.length() {
    let magnitude = (abs_double(field.gx[i]) + abs_double(field.gy[i])) / 2.0
    result.data[i] = if magnitude > 255.0 { 255 } else { magnitude.to_int() }
    i = i + 1
  }
  result
}

///|
fn approximate_direction(y : Double, x : Double) -> Double {
  let pi = 3.141592653589793
  if x == 0.0 && y == 0.0 {
    0.0
  } else if abs_double(x) >= abs_double(y) {
    let ratio = y / x
    let mut angle = ratio - ratio * ratio * ratio / 3.0
    if x < 0.0 {
      angle = if y >= 0.0 { angle + pi } else { angle - pi }
    }
    angle
  } else {
    let ratio = x / y
    let mut angle = ratio - ratio * ratio * ratio / 3.0
    if y >= 0.0 {
      angle = 1.5707963267948966 - angle
    } else {
      angle = -1.5707963267948966 - angle
    }
    angle
  }
}

///|
pub fn gradient_orientation(field : GradientField) -> Array[Double] {
  let result = Array::make(field.gx.length(), 0.0)
  let mut i = 0
  while i < result.length() {
    result[i] = approximate_direction(field.gy[i], field.gx[i])
    i = i + 1
  }
  result
}

///|
pub fn local_contrast(img : GrayImage, radius : Int) -> GrayImage {
  if radius <= 0 {
    return GrayImage::new(img.width, img.height)
  }
  let result = GrayImage::new(img.width, img.height)
  let mut y = 0
  while y < img.height {
    let mut x = 0
    while x < img.width {
      let mut low = 255
      let mut high = 0
      let mut dy = -radius
      while dy <= radius {
        let mut dx = -radius
        while dx <= radius {
          let value = img.sample(x + dx, y + dy, BorderMode::Clamp)
          if value < low {
            low = value
          }
          if value > high {
            high = value
          }
          dx = dx + 1
        }
        dy = dy + 1
      }
      result.set(x, y, high - low)
      x = x + 1
    }
    y = y + 1
  }
  result
}
