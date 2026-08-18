# MoonBit Feature Forge Implementation Plan

> **For agentic workers:** Execute this plan task-by-task with test-first development and a verification checkpoint after every task.

**Goal:** 将 `Myytsjj/moonbit-feature-forge` 扩展为可复用的纯 MoonBit 2D 局部特征工具包，生产实现达到 8,000 行以上真实有效 MoonBit 源码，并具备可复现的基准、边界测试、README、跨平台 CI 和 Mooncakes 发布材料。

**Architecture:** 保持一个公共根包，公共类型归根包所有；按图像数据、预处理、尺度空间、特征、匹配、几何、鲁棒估计、pipeline 和指标拆分文件。CLI 位于 `cmd/main`，只调用根包 API。旧的三个便捷入口保留并转发到默认配置。

**Tech Stack:** MoonBit stable CLI；纯 MoonBit；无新增第三方依赖；稳定后端 `wasm`、`wasm-gc`、`js`、`native`；Apache-2.0。

## Global Constraints

- `project_proposal.md` 只读，绝不修改、删除或加入 README 的内部辩护内容。
- README 只面向使用者，必须包含：项目定位、核心能力、快速开始、CLI、架构、基准、测试、CI、许可证。
- 生产实现 `.mbt` 行数单独统计并达到 8,000 行以上；测试、CLI、生成接口和 `_build` 单独统计。
- 不用重复函数、空文件、生成物、注释堆叠、空提交或重复提交凑源码规模。
- 每个新增行为先写一个会失败的测试，运行确认失败原因，再写最小实现并运行全套相关测试。
- 新增文件使用 `///|` block style；公共类型和方法留在根包，不把公共类型藏在内部包。
- 最终 CI 覆盖 Linux、macOS、Windows，并执行官方安装脚本、`moon update`、格式洁净、`moon check --target all`、`moon test --target all`、`moon info` 和 CLI demo。
- 最终发布前必须用新鲜命令验证 `moon publish --dry-run` 或等价的本地发布检查，再执行实际发布；没有命令证据时不在 README 宣称已发布。

## File Map

- Modify `types.mbt`: `GrayImage`、点/矩形、采样和公共结果类型。
- Create `image_ops.mbt`: crop、fill、clone、直方图、归一化、边界采样和合成变换。
- Create `filters.mbt`: box/Gaussian 近似、Sobel、梯度和局部对比度。
- Create `pyramid.mbt`: 尺度层、坐标映射和多尺度图像构造。
- Modify `fast.mbt`: FAST 配置、响应排序、NMS 和最大特征数限制。
- Modify `orb.mbt`: 方向、描述子配置、多尺度坐标和 patch 边界处理。
- Modify `matcher.mbt`: 稳定 Top-K、ratio、cross-check、唯一性和描述子索引。
- Create `geometry.mbt`: 点集、仿射辅助、单应性、齐次投影和残差统计。
- Modify `ransac.mbt`: 统一诊断、退化处理、可配置种子、仿射/单应性鲁棒估计。
- Modify `moonbit-feature-forge.mbt`: 默认 pipeline 和兼容入口。
- Create `metrics.mbt`: 匹配质量、重投影统计和报告格式化。
- Modify `moonbit-feature-forge_test.mbt`: 现有测试迁移和公共行为回归。
- Create `image_ops_test.mbt`, `filters_test.mbt`, `pyramid_test.mbt`, `matcher_test.mbt`, `geometry_test.mbt`, `pipeline_edge_test.mbt`: 分层黑盒测试。
- Modify `cmd/main/main.mbt`: `demo`/`benchmark` 分支和阶段指标输出。
- Create `benchmarks/README.md`: 实测基准记录与复现命令，不写未经运行的数据。
- Modify `README.md`: 成熟开源项目结构和真实输出。
- Modify `.github/workflows/ci.yml`: 官方安装脚本、三平台矩阵、全目标检查。
- Create `.github/workflows/publish.yml`: 手动发布模板，使用仓库 secret，不在源码保存令牌。
- Modify `.gitignore`: `_build`、coverage、`.firecrawl` 和本地基准临时物。
- Modify `moon.mod`: 发布版本和准确的公共描述；保留 `Myytsjj/moonbit-feature-forge` 命名空间。

---

### Task 1: Establish the first failing contracts and measurement scripts

**Files:**
- Create: `scripts/count_moonbit_lines.ps1`
- Modify: `moonbit-feature-forge_test.mbt`
- Modify: `task_plan.md`
- Modify: `findings.md`

**Interfaces:**
- Produces a line-count command that excludes `_build`, `pkg.generated.mbti`, and `*_wbtest.mbt`, and reports production, tests, and CLI separately.
- Adds test names that describe the first new public contracts without implementing them yet.

- [ ] **Step 1: Add the line-count script and one first test.**

  Add `scripts/count_moonbit_lines.ps1` that walks tracked `.mbt` files, excludes `_build`, files ending in `_test.mbt`/`_wbtest.mbt`, and prints `production`, `tests`, `cli`, `total`. Add a test named `GrayImage rejects invalid dimensions with an empty image` that calls the planned constructor behavior.

- [ ] **Step 2: Run the targeted test and confirm the expected RED failure.**

  Run:

  ```powershell
  moon test --filter 'GrayImage rejects invalid dimensions*'
  ```

  Expected: failure because invalid-dimension behavior is not implemented; a compiler or test-name typo is not an acceptable RED result.

- [ ] **Step 3: Record the baseline count and test failure in `progress.md`.**

- [ ] **Step 4: Commit only the measurement/test-contract changes.**

  ```powershell
  git add scripts/count_moonbit_lines.ps1 moonbit-feature-forge_test.mbt task_plan.md findings.md progress.md
  git commit -m "test: establish feature forge expansion contracts"
  ```

---

### Task 2: Build image primitives, safe sampling, and synthetic transforms

**Files:**
- Modify: `types.mbt`
- Create: `image_ops.mbt`
- Create: `image_ops_test.mbt`

**Interfaces:**
- Produces `Point2`, `FloatPoint2`, `Rect`, `BorderMode`, and image methods for `clone`, `crop`, `fill`, `histogram`, `normalize`, `sample_nearest`, `sample_bilinear`, `translate`, `rotate_about`, and `resize_nearest`.
- Invalid dimensions produce an empty `GrayImage` with zero width and height; out-of-range writes are ignored; sampling follows the requested border mode.

- [ ] **Step 1: Write failing tests for invalid dimensions, crop clipping, histogram totals, and all border modes.**

  Include exact cases: `GrayImage::new(-2, 4)` has width/height zero; cropping a `4x3` image with `Rect(-2, -1, 5, 5)` returns the clipped `4x3` content; a histogram of a `2x2` image sums to four; constant, clamp, and reflect sampling return distinct expected values at `(-1, 0)`.

- [ ] **Step 2: Run `moon test --filter 'image*'` and confirm RED.**

- [ ] **Step 3: Implement the smallest safe data and sampling API.**

  Keep pixels clamped to `[0, 255]`; use explicit index checks; do not expose mutable internal arrays through new public APIs.

- [ ] **Step 4: Run targeted tests, then the existing six tests.**

  ```powershell
  moon check --deny-warn
  moon test --filter 'image*'
  moon test
  ```

- [ ] **Step 5: Add failing transform tests, implement nearest-neighbor resize and deterministic translate/rotate helpers, then rerun the same commands.**

- [ ] **Step 6: Commit the image layer.**

  ```powershell
  git add types.mbt image_ops.mbt image_ops_test.mbt
  git commit -m "feat: add safe image primitives and sampling"
  ```

---

### Task 3: Add filters, gradients, and image pyramids

**Files:**
- Create: `filters.mbt`
- Create: `pyramid.mbt`
- Create: `filters_test.mbt`
- Create: `pyramid_test.mbt`

**Interfaces:**
- Produces `box_blur`, `gaussian_blur`, `sobel_gradients`, `gradient_magnitude`, `gradient_orientation`, `local_contrast`, `ImagePyramid::build`, `ImagePyramid::level`, `ImagePyramid::to_original`, and `ImagePyramid::to_level`.
- Filter outputs preserve dimensions; pyramid levels have deterministic dimensions and explicit scale factors.

- [ ] **Step 1: Write failing tests for impulse blur, horizontal/vertical Sobel response, constant-image zero gradients, and a two-level pyramid coordinate round trip.**

- [ ] **Step 2: Run `moon test --filter 'filters*|pyramid*'` and confirm RED.**

- [ ] **Step 3: Implement separable integer/Double-safe filters with explicit border handling.**

  Start with a small normalized kernel and make the kernel size/radius part of the API so behavior is testable. Do not add a dependency for numerical routines.

- [ ] **Step 4: Implement pyramid construction by repeated blur and nearest-neighbor downsampling.**

- [ ] **Step 5: Run targeted tests, coverage, and all tests.**

  ```powershell
  moon check --deny-warn
  moon test --filter 'filters*|pyramid*'
  moon coverage analyze -- -f summary
  moon test
  ```

- [ ] **Step 6: Commit the preprocessing layer.**

  ```powershell
  git add filters.mbt pyramid.mbt filters_test.mbt pyramid_test.mbt
  git commit -m "feat: add image filters and scale pyramids"
  ```

---

### Task 4: Make FAST and ORB configurable and multi-scale

**Files:**
- Modify: `fast.mbt`
- Modify: `orb.mbt`
- Modify: `moonbit-feature-forge.mbt`
- Create: `feature_config_test.mbt`

**Interfaces:**
- Produces `FastConfig`, `OrbConfig`, `detect_fast_with_config`, `compute_orb_descriptors_with_config`, and `extract_multiscale_features`.
- Default convenience functions preserve existing output shape and remain callable by current tests and CLI.

- [ ] **Step 1: Write failing tests for uniform images, custom NMS radius, max-keypoint truncation, patch-border filtering, deterministic ordering, and a two-level translated synthetic scene.**

- [ ] **Step 2: Run the new feature tests and confirm RED.**

- [ ] **Step 3: Implement configuration defaults and stable keypoint ordering without changing the existing public entry points.**

- [ ] **Step 4: Implement multi-scale extraction using `ImagePyramid` and map keypoints back to original coordinates.**

- [ ] **Step 5: Verify descriptor length, angle normalization, no out-of-bounds patch reads, and identical output for identical inputs.**

  ```powershell
  moon check --deny-warn
  moon test --filter 'feature*|ORB*|FAST*'
  moon test
  ```

- [ ] **Step 6: Commit the feature extraction layer.**

  ```powershell
  git add fast.mbt orb.mbt moonbit-feature-forge.mbt feature_config_test.mbt
  git commit -m "feat: add configurable multiscale feature extraction"
  ```

---

### Task 5: Strengthen descriptor matching and diagnostics

**Files:**
- Modify: `matcher.mbt`
- Create: `matcher_test.mbt`

**Interfaces:**
- Produces `MatchPolicy`, `MatchStats`, `match_with_policy`, `enforce_unique_train_matches`, `DescriptorIndex`, `DescriptorIndex::build`, `DescriptorIndex::query`, and stable distance statistics.
- Empty inputs, unequal descriptor lengths, `k <= 0`, and duplicate descriptors have documented deterministic results.

- [ ] **Step 1: Write failing tests for stable ties, ratio rejection, mutual matching, uniqueness, unequal lengths, empty train arrays, and index-vs-brute-force equivalence.**

- [ ] **Step 2: Run `moon test --filter 'matcher*'` and confirm RED.**

- [ ] **Step 3: Implement policy-based matching and statistics while preserving the old functions as wrappers.**

- [ ] **Step 4: Implement a fixed-prefix bucket index with brute-force fallback; test that it never loses the exact brute-force nearest neighbor.**

- [ ] **Step 5: Run targeted tests and the complete suite.**

- [ ] **Step 6: Commit the matching layer.**

  ```powershell
  git add matcher.mbt matcher_test.mbt
  git commit -m "feat: add robust descriptor matching policies"
  ```

---

### Task 6: Add homography, reprojection metrics, and robust estimation

**Files:**
- Create: `geometry.mbt`
- Modify: `ransac.mbt`
- Create: `geometry_test.mbt`

**Interfaces:**
- Produces `Homography`, `GeometryModel`, `ReprojectionStats`, `estimate_affine_from_points`, `estimate_homography`, `project`, `inverse`, `reprojection_error`, `ransac_homography`, and a diagnostic-bearing RANSAC result.
- Degenerate samples, invalid thresholds, insufficient matches, and out-of-range match indices return an explicit non-success status and never divide by a near-zero determinant.

- [ ] **Step 1: Write failing tests for identity/translation homography, four-point square mapping, inverse round trip, collinear rejection, residual statistics, and RANSAC with two outliers.**

- [ ] **Step 2: Run `moon test --filter 'geometry*|RANSAC*'` and confirm RED.**

- [ ] **Step 3: Implement homogeneous point projection and stable four-point solver with determinant/normalization checks.**

- [ ] **Step 4: Implement affine estimate/refinement and refactor existing RANSAC to use explicit seed/config/diagnostics.**

- [ ] **Step 5: Implement homography RANSAC with early stopping and final inlier re-estimation.**

- [ ] **Step 6: Run all geometry and full-suite tests, including native target when supported.**

  ```powershell
  moon check --deny-warn --target all
  moon test --filter 'geometry*|RANSAC*'
  moon test --target all
  ```

- [ ] **Step 7: Commit the geometry layer.**

  ```powershell
  git add geometry.mbt ransac.mbt geometry_test.mbt
  git commit -m "feat: add projective geometry and robust model diagnostics"
  ```

---

### Task 7: Integrate pipeline reports and a real benchmark CLI

**Files:**
- Modify: `moonbit-feature-forge.mbt`
- Create: `metrics.mbt`
- Modify: `cmd/main/main.mbt`
- Create: `benchmarks/README.md`
- Create: `pipeline_edge_test.mbt`

**Interfaces:**
- Produces `FeatureConfig`, `FeatureSet`, `MatchReport`, `PipelineResult`, `run_pipeline`, `summarize_matches`, `summarize_reprojection`, `run_demo`, and `run_benchmark`.
- CLI prints phase labels and machine-readable `key=value` measurements; default invocation remains a runnable demo.

- [ ] **Step 1: Write failing pipeline tests for empty images, no descriptors, deterministic runs, translation recovery, and quality-report consistency.**

- [ ] **Step 2: Run pipeline tests and confirm RED.**

- [ ] **Step 3: Implement config-driven pipeline by composing the earlier modules; keep old wrappers as defaults.**

- [ ] **Step 4: Implement metrics with stable formatting and no hidden global state.**

- [ ] **Step 5: Add CLI command selection using the locally verified MoonBit argument API; avoid assuming an API name before `moon ide doc` confirms it.**

- [ ] **Step 6: Run the benchmark on the actual local toolchain and record only its output in `benchmarks/README.md`, including date, OS, target, command, dimensions, feature counts, timings, and seed.**

- [ ] **Step 7: Run the demo, benchmark, tests, and line count.**

  ```powershell
  moon run cmd/main
  moon run cmd/main -- benchmark
  moon test
  ./scripts/count_moonbit_lines.ps1
  ```

- [ ] **Step 8: Commit the pipeline and benchmark.**

  ```powershell
  git add moonbit-feature-forge.mbt metrics.mbt cmd/main/main.mbt benchmarks/README.md pipeline_edge_test.mbt
  git commit -m "feat: add reproducible pipeline reports and benchmarks"
  ```

---

### Task 8: Expand boundary coverage and refactor for maintainability

**Files:**
- Modify: `moonbit-feature-forge_test.mbt`
- Modify: `image_ops_test.mbt`
- Modify: `filters_test.mbt`
- Modify: `pyramid_test.mbt`
- Modify: `feature_config_test.mbt`
- Modify: `matcher_test.mbt`
- Modify: `geometry_test.mbt`
- Modify: `pipeline_edge_test.mbt`

**Interfaces:**
- No new public API; tests demonstrate the documented behavior and guard all core branches.

- [ ] **Step 1: Run coverage and list uncovered branches by file.**

  ```powershell
  moon test --enable-coverage
  moon coverage analyze -- -f summary
  moon coverage analyze -- -f caret
  ```

- [ ] **Step 2: For each uncovered core branch, add one focused test before changing implementation.**

  Required cases include negative/zero dimensions, all border modes, constant image gradients, invalid filter radius, pyramid with one level, max feature count zero, descriptor length mismatch, no train descriptors, stable ties, invalid ratio, invalid RANSAC threshold, out-of-range match indices, collinear samples, zero inliers, and repeated deterministic seeds.

- [ ] **Step 3: Run the new test first to verify RED when it exposes missing behavior.**

- [ ] **Step 4: Implement only the minimal branch behavior and rerun the affected test.**

- [ ] **Step 5: Run the complete suite and inspect coverage improvement.**

- [ ] **Step 6: Use `moon fmt`, `moon info`, and `moon ide outline` to split any file over 2,000 lines or function over 200 lines without changing behavior.**

- [ ] **Step 7: Commit the boundary and maintainability pass.**

  ```powershell
  git add *.mbt
  git commit -m "test: cover feature forge boundary and degenerate cases"
  ```

---

### Task 9: Rewrite documentation, CI, ignore rules, and package metadata

**Files:**
- Modify: `README.md`
- Modify: `.github/workflows/ci.yml`
- Create: `.github/workflows/publish.yml`
- Modify: `.gitignore`
- Modify: `moon.mod`

**Interfaces:**
- No runtime API change; documentation and automation must describe only verified commands and outputs.

- [ ] **Step 1: Write README sections from the public API and actual CLI output.**

  Include installation through MoonBit, a minimal build/test/demo block, `benchmark` invocation, the data-flow diagram, API usage, the measured result table, CI commands, and Apache-2.0 license. Remove internal contest, applicant, completion, and contributor-account language.

- [ ] **Step 2: Replace the single-platform workflow with the three-platform matrix.**

  Use official Unix/PowerShell installers, `persist-credentials: false`, `contents: read`, `moon version --all`, `moon update`, `moon fmt` plus `git diff --exit-code`, `moon check --deny-warn --target all`, `moon test --deny-warn --target all`, `moon info` plus `git diff --exit-code`, and `moon run cmd/main`.

- [ ] **Step 3: Add a manual publish workflow with a required `MOONCAKES_TOKEN` secret.**

  The workflow must fail clearly when the secret is missing, write credentials only during the publish step, run check/test first, and remove the temporary credential file in an always-style cleanup path supported by the shell.

- [ ] **Step 4: Update `.gitignore` and module version after checking the installed `moon` publish metadata requirements.**

- [ ] **Step 5: Run local README commands, YAML syntax inspection, `moon info`, and the line-count script.**

- [ ] **Step 6: Commit the documentation and CI pass.**

  ```powershell
  git add README.md .github/workflows/ci.yml .github/workflows/publish.yml .gitignore moon.mod
  git commit -m "docs: prepare feature forge for release and CI"
  ```

---

### Task 10: Run final verification, self-review, push GitHub, and publish Mooncakes

**Files:**
- Modify: `progress.md`
- Modify: `findings.md`
- Do not modify: `project_proposal.md`

**Interfaces:**
- Produces fresh command evidence and a final self-review report; no implementation behavior changes are allowed in this task.

- [ ] **Step 1: Verify proposal immutability and repository cleanliness.**

  Compare the proposal hash with the pre-implementation hash, inspect `git status`, confirm no `_build` or temporary research files are tracked, and inspect the staged diff.

- [ ] **Step 2: Run the complete local verification set.**

  ```powershell
  moon version --all
  moon fmt
  git diff --exit-code
  moon check --deny-warn --target all
  moon build --target all
  moon test --deny-warn --target all
  moon coverage analyze -- -f summary
  moon info
  git diff --exit-code
  moon run cmd/main
  moon run cmd/main -- benchmark
  ./scripts/count_moonbit_lines.ps1
  ```

- [ ] **Step 3: Verify remote default branch and meaningful history.**

  Use `git ls-remote --symref github HEAD`, `git log --oneline --decorate -12`, and `git log --since=2026-07-13 --oneline` without assuming the branch name.

- [ ] **Step 4: Run the local self-check against repository structure, README, LICENSE, history, default branch, source scale, CI, and Mooncakes metadata.**

  Record facts, inferences, and any unresolved external status separately; never claim remote CI or package publication succeeded without checking it.

- [ ] **Step 5: Run `moon publish --dry-run`; if it succeeds, run the authorized `moon publish` command and capture the package/version output.**

- [ ] **Step 6: Push the verified commits to the GitHub default branch.**

  ```powershell
  git push github main
  ```

  If the default branch check returns a different branch, push the actual default branch instead and report it.

- [ ] **Step 7: Update `progress.md` and `findings.md` with exact final evidence, commit the evidence-only change, and push it.**

- [ ] **Step 8: Perform a final diff review and report only verified results, including any blocked remote CI or publication step.**

## Plan Self-Review

- Spec coverage: image primitives (Task 2), filters/pyramid (Task 3), feature extraction (Task 4), matching (Task 5), geometry/RANSAC (Task 6), pipeline/benchmark (Task 7), boundary coverage (Task 8), README/CI/release (Task 9), and acceptance evidence (Task 10).
- Placeholder scan: plan contains no unresolved placeholder or generic implementation step; every task names files, interfaces, commands, and expected checks.
- Type consistency: `FeatureConfig`/`FeatureSet`/`MatchReport`/`PipelineResult` are introduced in Task 7 and consumed only by Task 7; geometry result types are introduced in Task 6 and consumed by Tasks 7 and 8; line-count output is introduced in Task 1 and used by Tasks 7–10.
- Scope: all changes serve the approved 2D vision toolkit boundary; no unrelated UI, networking, or language-runtime work is included.
