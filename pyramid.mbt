// Deterministic image scale-space construction.

///|
pub(all) struct ImagePyramid {
  levels : Array[GrayImage]
  scales : Array[Double]
}

///|
pub fn ImagePyramid::build(img : GrayImage, level_count : Int) -> ImagePyramid {
  let levels : Array[GrayImage] = []
  let scales : Array[Double] = []
  if level_count <= 0 {
    return { levels, scales }
  }
  let mut current = img.clone()
  let mut scale = 1.0
  let mut level = 0
  while level < level_count {
    levels.push(current.clone())
    scales.push(scale)
    if level + 1 < level_count {
      let blurred = box_blur(current, 1)
      let next_width = (current.width + 1) / 2
      let next_height = (current.height + 1) / 2
      current = blurred.resize_nearest(next_width, next_height)
      scale = scale * 0.5
    }
    level = level + 1
  }
  { levels, scales }
}

///|
pub fn ImagePyramid::level_count(self : ImagePyramid) -> Int {
  self.levels.length()
}

///|
pub fn ImagePyramid::level(self : ImagePyramid, index : Int) -> GrayImage {
  if index < 0 || index >= self.levels.length() {
    GrayImage::new(0, 0)
  } else {
    self.levels[index]
  }
}

///|
pub fn ImagePyramid::scale(self : ImagePyramid, index : Int) -> Double {
  if index < 0 || index >= self.scales.length() {
    0.0
  } else {
    self.scales[index]
  }
}

///|
pub fn ImagePyramid::to_level(
  self : ImagePyramid,
  point : FloatPoint2,
  level : Int,
) -> FloatPoint2 {
  let factor = self.scale(level)
  if factor <= 0.0 {
    point
  } else {
    FloatPoint2::new(point.x * factor, point.y * factor)
  }
}

///|
pub fn ImagePyramid::to_original(
  self : ImagePyramid,
  point : FloatPoint2,
  level : Int,
) -> FloatPoint2 {
  let factor = self.scale(level)
  if factor <= 0.0 {
    point
  } else {
    FloatPoint2::new(point.x / factor, point.y / factor)
  }
}
