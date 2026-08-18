# Benchmarks

The command below runs the deterministic synthetic registration workload used by the CLI:

```powershell
moon run cmd/main -- benchmark
```

Measured locally on 2026-08-18 with MoonBit `0.1.20260814` / `moonc v0.10.8+8606a5800`, Windows x64, target `default`:

```text
benchmark=feature_pipeline size=160x160 iterations=3 features1=32 features2=31 matches=29 inlier_ratio=1 total_ms=26
target=default seed=42
```

The workload constructs a translated 160×160 grayscale scene, extracts configurable FAST/ORB features, applies policy-based Hamming matching, and evaluates deterministic affine and homography RANSAC. `total_ms` is wall-clock time for all three iterations and will vary with CPU load; feature, match, ratio, dimensions, and seed fields are the reproducibility checks.
