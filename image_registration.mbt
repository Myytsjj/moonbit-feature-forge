// Image warping and deterministic translation search built on the core image
// and geometry APIs. The module intentionally operates on grayscale buffers.

///|
pub(all) struct WarpOptions {
  border : BorderMode
  bilinear : Bool
}

///|
pub fn WarpOptions::default() -> WarpOptions {
  { border: BorderMode::Constant(0), bilinear: true }
}

///|
fn registration_det(transform : AffineTransform) -> Double {
  transform.a * transform.d - transform.b * transform.c
}

///|
fn inverse_affine(transform : AffineTransform) -> AffineTransform? {
  let determinant = registration_det(transform)
  if determinant < 0.000000001 && determinant > -0.000000001 {
    return None
  }
  let inverse = 1.0 / determinant
  let a = transform.d * inverse
  let b = -transform.b * inverse
  let c = -transform.c * inverse
  let d = transform.a * inverse
  Some({
    a,
    b,
    c,
    d,
    tx: -(a * transform.tx + b * transform.ty),
    ty: -(c * transform.tx + d * transform.ty),
  })
}

///|
pub fn warp_affine_image(
  img : GrayImage,
  transform : AffineTransform,
  width : Int,
  height : Int,
  options : WarpOptions,
) -> GrayImage {
  let result = GrayImage::new(width, height)
  match inverse_affine(transform) {
    None => result
    Some(inverse) => {
      let mut y = 0
      while y < result.height {
        let mut x = 0
        while x < result.width {
          let (source_x, source_y) = inverse.apply(
            Double::from_int(x),
            Double::from_int(y),
          )
          let value = if options.bilinear {
            img.sample_bilinear(source_x, source_y, options.border).to_int()
          } else {
            img.sample(source_x.to_int(), source_y.to_int(), options.border)
          }
          result.set(x, y, value)
          x = x + 1
        }
        y = y + 1
      }
      result
    }
  }
}

///|
pub fn warp_homography_image(
  img : GrayImage,
  model : Homography,
  width : Int,
  height : Int,
  options : WarpOptions,
) -> GrayImage {
  let result = GrayImage::new(width, height)
  match model.inverse() {
    None => result
    Some(inverse) => {
      let mut y = 0
      while y < result.height {
        let mut x = 0
        while x < result.width {
          let destination = FloatPoint2::new(
            Double::from_int(x),
            Double::from_int(y),
          )
          let source = inverse.project(destination)
          match source {
            None => result.set(x, y, 0)
            Some(point) => {
              let value = if options.bilinear {
                img.sample_bilinear(point.x, point.y, options.border).to_int()
              } else {
                img.sample(point.x.to_int(), point.y.to_int(), options.border)
              }
              result.set(x, y, value)
            }
          }
          x = x + 1
        }
        y = y + 1
      }
      result
    }
  }
}

///|
pub fn homography_from_affine(transform : AffineTransform) -> Homography {
  {
    h00: transform.a,
    h01: transform.b,
    h02: transform.tx,
    h10: transform.c,
    h11: transform.d,
    h12: transform.ty,
    h20: 0.0,
    h21: 0.0,
    h22: 1.0,
  }
}

///|
pub fn compose_homographies(
  left : Homography,
  right : Homography,
) -> Homography {
  {
    h00: left.h00 * right.h00 + left.h01 * right.h10 + left.h02 * right.h20,
    h01: left.h00 * right.h01 + left.h01 * right.h11 + left.h02 * right.h21,
    h02: left.h00 * right.h02 + left.h01 * right.h12 + left.h02 * right.h22,
    h10: left.h10 * right.h00 + left.h11 * right.h10 + left.h12 * right.h20,
    h11: left.h10 * right.h01 + left.h11 * right.h11 + left.h12 * right.h21,
    h12: left.h10 * right.h02 + left.h11 * right.h12 + left.h12 * right.h22,
    h20: left.h20 * right.h00 + left.h21 * right.h10 + left.h22 * right.h20,
    h21: left.h20 * right.h01 + left.h21 * right.h11 + left.h22 * right.h21,
    h22: left.h20 * right.h02 + left.h21 * right.h12 + left.h22 * right.h22,
  }
}

///|
pub fn transform_rect_corners(
  model : Homography,
  rect : Rect,
) -> Array[FloatPoint2] {
  let source : Array[FloatPoint2] = [
    FloatPoint2::new(Double::from_int(rect.x0), Double::from_int(rect.y0)),
    FloatPoint2::new(Double::from_int(rect.x1), Double::from_int(rect.y0)),
    FloatPoint2::new(Double::from_int(rect.x1), Double::from_int(rect.y1)),
    FloatPoint2::new(Double::from_int(rect.x0), Double::from_int(rect.y1)),
  ]
  transform_points(model, source)
}

///|
pub fn warp_valid_mask(
  model : Homography,
  source_width : Int,
  source_height : Int,
  width : Int,
  height : Int,
) -> GrayImage {
  let result = GrayImage::new(width, height)
  match model.inverse() {
    None => result
    Some(inverse) => {
      let mut y = 0
      while y < height {
        let mut x = 0
        while x < width {
          match
            inverse.project(
              FloatPoint2::new(Double::from_int(x), Double::from_int(y)),
            ) {
            None => ()
            Some(point) =>
              if point.x >= 0.0 &&
                point.x < Double::from_int(source_width) &&
                point.y >= 0.0 &&
                point.y < Double::from_int(source_height) {
                result.set(x, y, 255)
              }
          }
          x = x + 1
        }
        y = y + 1
      }
      result
    }
  }
}

///|
pub fn image_difference(left : GrayImage, right : GrayImage) -> GrayImage {
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
      let difference = left.get(x, y) - right.get(x, y)
      result.set(x, y, if difference < 0 { -difference } else { difference })
      x = x + 1
    }
    y = y + 1
  }
  result
}

///|
pub fn threshold_difference(
  left : GrayImage,
  right : GrayImage,
  threshold : Int,
) -> GrayImage {
  binary_threshold(image_difference(left, right), threshold)
}

///|
pub(all) struct TranslationSearchResult {
  dx : Int
  dy : Int
  score : Double
  evaluated : Int
}

///|
fn translation_before(dx : Int, dy : Int, best_dx : Int, best_dy : Int) -> Bool {
  dy < best_dy || (dy == best_dy && dx < best_dx)
}

///|
pub fn search_translation(
  reference : GrayImage,
  moving : GrayImage,
  maximum_dx : Int,
  maximum_dy : Int,
) -> TranslationSearchResult {
  let range_x = if maximum_dx < 0 { -maximum_dx } else { maximum_dx }
  let range_y = if maximum_dy < 0 { -maximum_dy } else { maximum_dy }
  let mut best_dx = 0
  let mut best_dy = 0
  let mut best_score = image_mse(reference, moving)
  let mut evaluated = 1
  let mut dy = -range_y
  while dy <= range_y {
    let mut dx = -range_x
    while dx <= range_x {
      if dx != 0 || dy != 0 {
        let shifted = moving.translate(dx, dy, BorderMode::Constant(0))
        let score = image_mse(reference, shifted)
        if score < best_score ||
          (score == best_score && translation_before(dx, dy, best_dx, best_dy)) {
          best_score = score
          best_dx = dx
          best_dy = dy
        }
        evaluated = evaluated + 1
      }
      dx = dx + 1
    }
    dy = dy + 1
  }
  { dx: best_dx, dy: best_dy, score: best_score, evaluated }
}

///|
pub fn translation_from_matches(
  matches : Array[Match],
  keypoints1 : Array[Keypoint],
  keypoints2 : Array[Keypoint],
) -> FloatPoint2 {
  median_match_displacement(matches, keypoints1, keypoints2)
}

///|
pub fn apply_translation(
  img : GrayImage,
  dx : Double,
  dy : Double,
) -> GrayImage {
  let transform = AffineTransform::{
    a: 1.0,
    b: 0.0,
    c: 0.0,
    d: 1.0,
    tx: dx,
    ty: dy,
  }
  warp_affine_image(
    img,
    transform,
    img.width,
    img.height,
    WarpOptions::default(),
  )
}

///|
pub(all) struct PatchSearchResult {
  x : Int
  y : Int
  score : Double
  evaluated : Int
}

///|
fn patch_mse(image : GrayImage, patch : GrayImage, x : Int, y : Int) -> Double {
  if patch.width <= 0 || patch.height <= 0 {
    return 0.0
  }
  let mut total = 0.0
  let mut row = 0
  while row < patch.height {
    let mut column = 0
    while column < patch.width {
      let difference = Double::from_int(
        image.get(x + column, y + row) - patch.get(column, row),
      )
      total = total + difference * difference
      column = column + 1
    }
    row = row + 1
  }
  total / Double::from_int(patch.width * patch.height)
}

///|
pub fn search_patch(
  image : GrayImage,
  patch : GrayImage,
  origin_x : Int,
  origin_y : Int,
  radius : Int,
) -> PatchSearchResult {
  let safe_radius = if radius < 0 { 0 } else { radius }
  if patch.width <= 0 || patch.height <= 0 {
    return { x: origin_x, y: origin_y, score: 0.0, evaluated: 0 }
  }
  let mut best_x = origin_x
  let mut best_y = origin_y
  let mut best_score = patch_mse(image, patch, origin_x, origin_y)
  let mut evaluated = 1
  let mut dy = -safe_radius
  while dy <= safe_radius {
    let mut dx = -safe_radius
    while dx <= safe_radius {
      if dx != 0 || dy != 0 {
        let x = origin_x + dx
        let y = origin_y + dy
        let score = patch_mse(image, patch, x, y)
        if score < best_score ||
          (score == best_score && translation_before(x, y, best_x, best_y)) {
          best_score = score
          best_x = x
          best_y = y
        }
        evaluated = evaluated + 1
      }
      dx = dx + 1
    }
    dy = dy + 1
  }
  { x: best_x, y: best_y, score: best_score, evaluated }
}

///|
pub fn normalized_correlation(left : GrayImage, right : GrayImage) -> Double {
  let width = if left.width < right.width { left.width } else { right.width }
  let height = if left.height < right.height {
    left.height
  } else {
    right.height
  }
  let count = width * height
  if count <= 0 {
    return 0.0
  }
  let mut sum_left = 0.0
  let mut sum_right = 0.0
  let mut y = 0
  while y < height {
    let mut x = 0
    while x < width {
      sum_left = sum_left + Double::from_int(left.get(x, y))
      sum_right = sum_right + Double::from_int(right.get(x, y))
      x = x + 1
    }
    y = y + 1
  }
  let mean_left = sum_left / Double::from_int(count)
  let mean_right = sum_right / Double::from_int(count)
  let mut numerator = 0.0
  let mut square_left = 0.0
  let mut square_right = 0.0
  y = 0
  while y < height {
    let mut x = 0
    while x < width {
      let left_delta = Double::from_int(left.get(x, y)) - mean_left
      let right_delta = Double::from_int(right.get(x, y)) - mean_right
      numerator = numerator + left_delta * right_delta
      square_left = square_left + left_delta * left_delta
      square_right = square_right + right_delta * right_delta
      x = x + 1
    }
    y = y + 1
  }
  let denominator = square_left * square_right
  if denominator <= 0.000000000001 {
    if image_mse(left, right) == 0.0 {
      1.0
    } else {
      0.0
    }
  } else {
    let mut estimate = if denominator > 1.0 { denominator } else { 1.0 }
    let mut i = 0
    while i < 20 {
      estimate = (estimate + denominator / estimate) / 2.0
      i = i + 1
    }
    numerator / estimate
  }
}

///|
pub fn brightness_normalize(img : GrayImage, target_mean : Double) -> GrayImage {
  let result = GrayImage::new(img.width, img.height)
  if img.data.length() == 0 {
    return result
  }
  let mean = image_mean(img)
  let offset = target_mean - mean
  let mut i = 0
  while i < img.data.length() {
    result.data[i] = filter_clamp(Double::from_int(img.data[i]) + offset)
    i = i + 1
  }
  result
}

///|
pub fn blend_registered(
  reference : GrayImage,
  moving : GrayImage,
  model : Homography,
  weight : Double,
) -> GrayImage {
  let warped = warp_homography_image(
    moving,
    model,
    reference.width,
    reference.height,
    WarpOptions::default(),
  )
  image_blend(reference, warped, weight)
}

///|
pub fn registration_score(reference : GrayImage, moving : GrayImage) -> Double {
  normalized_correlation(reference, moving)
}

///|
pub fn registration_error(reference : GrayImage, moving : GrayImage) -> Double {
  image_mse(reference, moving)
}

///|
pub fn pyramid_translation_search(
  reference : GrayImage,
  moving : GrayImage,
  levels : Int,
  radius : Int,
) -> TranslationSearchResult {
  let pyramid_reference = ImagePyramid::build(reference, levels)
  let pyramid_moving = ImagePyramid::build(moving, levels)
  if pyramid_reference.level_count() == 0 || pyramid_moving.level_count() == 0 {
    return { dx: 0, dy: 0, score: 0.0, evaluated: 0 }
  }
  let level = if pyramid_reference.level_count() < pyramid_moving.level_count() {
    pyramid_reference.level_count() - 1
  } else {
    pyramid_moving.level_count() - 1
  }
  let result = search_translation(
    pyramid_reference.level(level),
    pyramid_moving.level(level),
    radius,
    radius,
  )
  let scale = pyramid_reference.scale(level)
  if scale <= 0.0 {
    result
  } else {
    {
      dx: (Double::from_int(result.dx) / scale).to_int(),
      dy: (Double::from_int(result.dy) / scale).to_int(),
      score: result.score,
      evaluated: result.evaluated,
    }
  }
}

///|
pub fn crop_registered_pair(
  reference : GrayImage,
  moving : GrayImage,
  rect : Rect,
) -> (GrayImage, GrayImage) {
  (reference.crop(rect), moving.crop(rect))
}

///|
pub fn image_overlap_mask(left : GrayImage, right : GrayImage) -> GrayImage {
  let width = if left.width < right.width { left.width } else { right.width }
  let height = if left.height < right.height {
    left.height
  } else {
    right.height
  }
  let result = GrayImage::new(width, height)
  result.fill(255)
  result
}
