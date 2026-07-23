// MoonBit Feature Forge - Types Module
// Defines fundamental data structures for local feature detection and matching.

///|
pub(all) struct GrayImage {
  width : Int
  height : Int
  data : Array[Int]
}

///|
pub fn GrayImage::new(width : Int, height : Int) -> GrayImage {
  let size = width * height
  let data = Array::make(size, 0)
  { width, height, data }
}

///|
pub fn GrayImage::get(self : GrayImage, x : Int, y : Int) -> Int {
  if x < 0 || x >= self.width || y < 0 || y >= self.height {
    return 0
  }
  self.data[y * self.width + x]
}

///|
pub fn GrayImage::set(self : GrayImage, x : Int, y : Int, val : Int) -> Unit {
  if x >= 0 && x < self.width && y >= 0 && y < self.height {
    let clamped = if val < 0 { 0 } else if val > 255 { 255 } else { val }
    self.data[y * self.width + x] = clamped
  }
}

///|
pub(all) struct Keypoint {
  x : Int
  y : Int
  response : Double
  angle : Double
  octave : Int
  size : Int
}

///|
pub fn Keypoint::new(
  x : Int,
  y : Int,
  response : Double,
  angle : Double,
) -> Keypoint {
  { x, y, response, angle, octave: 0, size: 31 }
}

///|
pub(all) struct Descriptor {
  data : Array[Byte]
}

///|
pub fn Descriptor::new(size : Int) -> Descriptor {
  let data = Array::make(size, (0 : Byte))
  { data, }
}

///|
pub(all) struct Match {
  query_idx : Int
  train_idx : Int
  distance : Int
}

///|
pub fn Match::new(query_idx : Int, train_idx : Int, distance : Int) -> Match {
  { query_idx, train_idx, distance }
}
