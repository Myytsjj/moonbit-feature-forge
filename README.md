# MoonBit Feature Forge

[![CI](https://github.com/Myytsjj/moonbit-feature-forge/actions/workflows/ci.yml/badge.svg)](https://github.com/Myytsjj/moonbit-feature-forge/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/license-Apache--2.0-blue.svg)](LICENSE)

MoonBit Feature Forge is a pure-MoonBit 2D local-feature toolkit for grayscale image analysis, descriptor matching, geometric registration, and deterministic diagnostics. It is designed as a small, composable building block for image alignment, tracking, inspection, and research prototypes without a native C/C++ dependency.

## Project positioning

The library covers the part of a vision workflow between a grayscale image buffer and a verified geometric correspondence. It keeps image storage explicit, makes border and degenerate-input behavior deterministic, and exposes both the core pipeline and the measurements needed to inspect a run.

## Core capabilities

- Safe `GrayImage` construction, sampling, cropping, resizing, translation, rotation, histograms, integral statistics, morphology, connected components, and texture summaries.
- Box, triangle, Gaussian-like, rank, Sobel, Laplacian, contrast, adaptive-threshold, and pyramid preprocessing.
- Configurable FAST keypoint detection, non-maximum suppression, orientation-aware ORB/BRIEF descriptors, and multiscale coordinate mapping.
- Hamming matching with KNN, ratio filtering, mutual matching, unique-train constraints, and an exact descriptor index.
- Affine and homography estimation, reprojection diagnostics, deterministic RANSAC, residual analysis, and model comparison.
- Image warping, translation and patch search, keypoint-grid indexing, frame-to-frame association, feature tracks, and quality dashboards.
- A runnable CLI demo and benchmark with machine-readable `key=value` output.

The package intentionally does not include codecs, GUI bindings, networking, or platform-specific native code. Applications can connect their own image decoder or camera layer to `GrayImage`.

## Quick start

Install the current stable MoonBit toolchain, then run the repository checks:

```powershell
moon version --all
moon update
moon fmt
moon check --deny-warn
moon test --deny-warn
moon run cmd/main
```

Use the library from another MoonBit package:

```moonbit
import {
  "Myytsjj/moonbit-feature-forge" @forge,
}

fn register(reference : @forge.GrayImage, moving : @forge.GrayImage) -> Unit {
  let result = @forge.run_pipeline(
    reference,
    moving,
    @forge.FeatureConfig::default(),
  )
  println(@forge.format_pipeline_summary(result))
}
```

Invalid dimensions produce an empty image, out-of-range writes are ignored, and sampling always follows the selected `BorderMode`.

## CLI

The default command builds a deterministic synthetic translation scene and runs the complete pipeline:

```powershell
moon run cmd/main
```

Measured demo output on the local toolchain:

```text
MoonBit Feature Forge
pipeline=demo size=120x120
features1=26 features2=25 matches=23
affine_inliers=23 homography_inliers=23
affine_ratio=1 homography_rms=0
features1=26 features2=25 matches=23 distance_mean=0 affine_inliers=23 homography_inliers=23
```

Run the benchmark workload with:

```powershell
moon run cmd/main -- benchmark
```

The CLI prints dimensions, iteration count, feature counts, match count, inlier ratio, total wall-clock time, target, and seed. See [benchmarks/README.md](benchmarks/README.md) for the recorded run and reproduction details.

## Architecture

```text
GrayImage
   │
   ├── sampling / filters / integral analysis / pyramid
   │
   ├── FAST ──► keypoints ──► ORB/BRIEF descriptors
   │                              │
   │                              ├── KNN / ratio / mutual / index matching
   │                              │
   │                              └── affine + homography RANSAC
   │                                         │
   └── warping / tracking / quality reports ◄┘
```

The public root package owns the data types and algorithms. The `cmd/main` package is a thin executable that constructs synthetic input and calls the public API. Analysis modules consume the same `GrayImage`, `Keypoint`, `Descriptor`, `Match`, and model types, so diagnostics do not require a second representation.

## API areas

| Area | Representative entry points |
| --- | --- |
| Image data | `GrayImage::new`, `sample`, `sample_bilinear`, `crop`, `resize_nearest` |
| Preprocessing | `box_blur`, `sobel_gradients`, `ImagePyramid::build`, `adaptive_threshold` |
| Features | `FastConfig`, `detect_fast_with_config`, `OrbConfig`, `compute_orb_descriptors_with_config` |
| Matching | `MatchPolicy`, `match_with_policy`, `mutual_match`, `DescriptorIndex::query` |
| Geometry | `estimate_homography`, `Homography::project`, `reprojection_stats`, `ransac_homography` |
| Pipeline | `FeatureConfig`, `run_pipeline`, `analyze_pipeline`, `build_quality_dashboard` |
| Tracking | `KeypointGridIndex`, `associate_keypoints`, `FeatureTrack`, `update_tracks` |

## Benchmarks

The checked-in benchmark uses a 160×160 synthetic scene, three complete pipeline iterations, default FAST/ORB and matching configuration, and seed `42`. A local run on 2026-08-18 with MoonBit `0.1.20260814`, `moonc v0.10.8+8606a5800`, Windows x64 produced:

| Workload | Size | Iterations | Features | Matches | Homography inlier ratio | Total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Synthetic translation | 160×160 | 3 | 32 / 31 | 29 | 1.0 | 26 ms |

`total_ms` is wall-clock time for all iterations and will vary with machine load. Feature, match, ratio, dimensions, and seed fields are the reproducibility signals; the full raw output is in [benchmarks/README.md](benchmarks/README.md).

## Tests

Run the complete test suite with:

```powershell
moon test --deny-warn
```

The suite includes 73 tests covering empty and invalid images, all border modes, clipped windows, filtering and morphology boundaries, deterministic keypoint ordering, descriptor length mismatches, empty indexes, stable ties, invalid match indices, collinear geometry, RANSAC outliers, pipeline determinism, warping, tracking, quality reports, and benchmark aggregation.

## CI

GitHub Actions runs the project on Linux, macOS, and Windows. Each job installs the stable MoonBit toolchain, updates dependencies, verifies formatting and generated interfaces, checks all targets, runs all tests, and executes the CLI demo. The workflow is [`.github/workflows/ci.yml`](.github/workflows/ci.yml).

Package publication is kept in a separate manually triggered workflow at [`.github/workflows/publish.yml`](.github/workflows/publish.yml); it expects a repository secret named `MOONCAKES_TOKEN` and never stores credentials in the repository.

## License

MoonBit Feature Forge is distributed under the [Apache License 2.0](LICENSE).
