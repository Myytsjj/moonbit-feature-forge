# MoonBit Feature Forge (局部特征引擎)

[![CI](https://github.com/lyjttio/moonbit-feature-forge/actions/workflows/ci.yml/badge.svg)](https://github.com/lyjttio/moonbit-feature-forge/actions/workflows/ci.yml)
[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](LICENSE)
[![MoonBit Version](https://img.shields.io/badge/MoonBit-v0.10.4+-brightgreen)](https://www.moonbitlang.cn/)

**`moonbit-feature-forge`** 是一个完全基于 **MoonBit** 原生构建的高性能 2D 局部特征提取、描述与鲁棒匹配引擎。该引擎专为 WebAssembly 跨平台计算与高性能图像处理设计，无需外部原生 C/C++ 依赖，实现了包括 FAST-9 角点检测、强度质心法方向计算、旋转 BRIEF 256 位二进制描述子 (ORB)、Hamming 距离高效匹配以及 RANSAC 2D 仿射变换估计等全套计算机视觉核心算法。

---

## 🌟 核心特性 (Key Features)

- ⚡ **FAST-9 角点检测 (FAST-9 Corner Detector)**
  - 基于 16 像素 Bresenham 环与 9 连续像素快速筛选机制。
  - 支持 $3 \times 3$ 邻域非极大值抑制 (Non-Maximum Suppression, NMS)。
- 🎯 **ORB 描述子引擎 (Oriented FAST & Rotated BRIEF)**
  - 基于圆形 Patch 强度质心法 (Intensity Centroid Method) 自动计算特征点主方向 $\theta$。
  - 支持 256 对可转动采样点的 32 字节 (256-bit) 二进制描述子生成。
- 🔍 **高效匹配器与多级过滤 (Matching & Filtering Engine)**
  - 位运算优化 (Popcount) 的 Hamming 距离快速计算。
  - 支持 Top-$k$ KNN 邻近匹配、Lowe's Ratio Test 比例筛选以及 Cross-check 交叉验证。
- 🛡️ **RANSAC 仿射模型拟合 (RANSAC Outlier Rejection)**
  - 基于 3 点对 Cramer 法则估计 2D 仿射变换矩阵 $\begin{bmatrix} a & b & tx \\ c & d & ty \end{bmatrix}$。
  - 迭代剔除误匹配点 (Outliers)，精确输出局内点 (Inliers) 与变换参数。

---

## 🏗️ 架构与设计 (Architecture)

```
                       +-----------------------+
                       |    GrayImage Input    |
                       +-----------+-----------+
                                   |
                                   v
                       +-----------------------+
                       |  FAST-9 Corner Detect |
                       | (Bresenham + NMS Nbr) |
                       +-----------+-----------+
                                   |
                                   v
                       +-----------------------+
                       |  Intensity Centroid   |
                       | Orientation Calculation|
                       +-----------+-----------+
                                   |
                                   v
                       +-----------------------+
                       |  Rotated BRIEF 256bit |
                       | Descriptor Extraction |
                       +-----------+-----------+
                                   |
                                   v
                       +-----------------------+
                       | Hamming Match & Ratio |
                       |   Cross-Check Filter  |
                       +-----------+-----------+
                                   |
                                   v
                       +-----------------------+
                       | RANSAC Affine Model   |
                       | Outlier Rejection Fit |
                       +-----------------------+
```

---

## 🚀 快速开始 (Quick Start)

### 1. 环境准备 (Prerequisites)

确保本地已安装最新的 MoonBit 工具链：

```bash
moon version
```

### 2. 编译与检查 (Build & Check)

```bash
# 格式化代码
moon fmt

# 严格类型检查 (无 Warning)
moon check --deny-warn

# 导出接口检查
moon info --deny-warn
```

### 3. 运行测试 (Run Tests)

```bash
moon test
```

### 4. 运行演示程序 (Run Demo Benchmark)

```bash
moon run cmd/main
```

示例输出：
```text
==========================================================
   MoonBit Feature Forge: High Performance Feature Engine 
==========================================================
Initializing synthetic images (120x120 pixels)...
Step 1: Extracting FAST keypoints & ORB 256-bit descriptors...
 -> Image 1 detected 36 keypoints & descriptors.
 -> Image 2 detected 36 keypoints & descriptors.

Step 2: Performing Hamming distance matching & ratio test...
 -> Found 36 valid feature match pairs.

Step 3: Executing RANSAC 2D affine model fitting & inlier filtering...
 -> RANSAC Inlier Count: 36
 -> Inlier Ratio: 100%
 -> Estimated Affine Matrix: [a: 1, b: 0, tx: 4]
                            [c: 0, d: 1, ty: 3]
==========================================================
Pipeline execution finished successfully!
```

---

## 📖 API 用法示例 (Usage Example)

```moonbit
import @Myyafa/moonbit-feature-forge as forge

fn example() {
  // 1. 创建灰度图像
  let img1 = @forge.GrayImage::new(100, 100)
  let img2 = @forge.GrayImage::new(100, 100)
  
  // 2. 提取特征点与 ORB 描述子
  let (kps1, descs1) = @forge.extract_features(img1, 25)
  let (kps2, descs2) = @forge.extract_features(img2, 25)
  
  // 3. 特征匹配与 Ratio Test 筛选
  let good_matches = @forge.match_and_filter(descs1, descs2, 0.8)
  
  // 4. RANSAC 几何拟合
  let result = @forge.ransac_affine(good_matches, kps1, kps2, 100, 3.0)
  println("Found \{result.inliers.length()} robust inlier matches.")
}
```

---

## 📄 开源许可证 (License)

本项目基于 [Apache License 2.0](LICENSE) 许可证开源。
