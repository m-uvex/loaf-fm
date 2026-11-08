# Loaf Performance Benchmarks

Cross-platform benchmark notes, methodology, and performance evaluations for Loaf across large directories (12,000+ files), comparing refactored builds against prior releases and GNOME Nautilus.

---

## Executive Summary

| Test Environment | Metric | Previous Loaf | Refactored Loaf | GNOME Nautilus | Delta (Loaf vs Nautilus) |
| --- | --- | --- | --- | --- | --- |
| **Arch Linux / Niri** *(i3-1115G4)* | Cold Start (Median) | 538 ms | **364 ms** | — | **~32% faster** vs old Loaf |
| **NixOS / Hyprland** *(i5-8265U)* | Cold Start (Median) | — | **1,147 ms** | 2,098 ms | **~1.83x faster** (45.3% reduction) |
| **In-Process Micro-ops** | 20k Refilter (×10) | 70 ms | **7 ms** | — | **~10x faster** |
| **In-Process Micro-ops** | 30k Natural Sort | 19 ms | **16 ms** | — | **~15% faster** |

---

## Standard Test Fixture

All tests share the identical non-tmpfs dataset located at `~/loaf-bench/big` (12,020 total entries):

* **4,000** valid 1×1 PNG files (`photo_NNNNN.png`) stressing natural sorting and thumbnail pipelines.
* **6,000** text files (`IMG_2026-01-NN_NNNN.jpg.txt`).
* **1,000** Cyrillic-named UTF-8 files.
* **1,000** digit-prefixed Markdown files (`-report-N.md`).
* **20** subdirectories.

---

## Benchmark Suite 1: NixOS 26.11 / Hyprland

* **Tester**: m-uvex
* **Date**: 2026-11-08
* **Focus**: Release Candidate (v0.3.0) vs. System Release (v0.2.0) vs. Nautilus 50.2.2

### Machine Specifications

| Component | Specification |
| --- | --- |
| **Hardware** | HP Laptop 15-da1xxx (`lt-hp15-nix`) |
| **OS / Kernel** | NixOS 26.11 (Zokor), Linux kernel 6.18.58 |
| **CPU** | Intel Core i5-8265U (4C/8T, 1.60 GHz base, boost to 3.90 GHz) |
| **Memory** | 24 GiB DDR4 (~11 GiB available during run) |
| **GPU** | Intel UHD Graphics 620 + NVIDIA GeForce MX150 (2 GiB VRAM) |
| **Graphics Stack** | Mesa 26.2.5, OpenGL 4.6 (Compatibility Profile) |
| **Storage** | Micron 2210 512GB PCIe 3.0 NVMe SSD (`/dev/nvme0n1p3`) |
| **Display Server** | Wayland, Hyprland 0.56.2 (1920×1080 @ 60 Hz) |

### Cold Start to Rendered Folder (`bench-open.sh`)

Measures elapsed time from execution with `--new-window` to Hyprland IPC reporting the window mapped and populated with the directory title:

| Target | Samples (ms) | Median | Fastest | Relative Performance |
| --- | --- | --- | --- | --- |
| **Loaf 0.3.0 (New)** | 1042, 1147, 1256, 1129, 1393 | **1,147 ms** | **1,042 ms** | **1.83x faster** vs Nautilus (+22% vs v0.2.0) |
| **Loaf 0.2.0 (Old)** | 1471, 1405, 2028, 1384, 1867 | **1,471 ms** | **1,384 ms** | **1.43x faster** vs Nautilus |
| **Nautilus 50.2.2** | 1956, 1886, 2482, 3679, 2098 | **2,098 ms** | **1,886 ms** | Baseline |

---

## Benchmark Suite 2: Arch Linux / Niri

* **Tester**: SpikyGames123
* **Date**: 2026-10-28
* **Focus**: Directory model refactor validation (`src/listing.rs`, `src/pane.rs`, `qml/FilePane.qml`)

### Machine Specifications

| Component | Specification |
| --- | --- |
| **OS / Kernel** | Arch Linux, Linux kernel 7.2.11-arch1-1 |
| **CPU** | Intel Core i3-1115G4 (2C/4T, 3.00 GHz), active scaling governor |
| **Memory** | 7.5 GiB DDR4 (~3.4 GiB available during run) |
| **GPU** | Intel UHD Graphics (Tiger Lake GT2), Mesa 26.2.5, OpenGL 4.6 |
| **Display Server** | Wayland, Niri compositor (1920×1080) |
| **Input Daemon** | `ydotoold` |

### Results

#### 1. Cold Start to Visible Folder (`bench-open.sh`)

* **Loaf (Refactored 0.2.0)**: 364 ms, 345 ms, 435 ms (**Median: 364 ms**)
* **Loaf (System 0.2.1)**: 563 ms, 538 ms, 497 ms (**Median: 538 ms**)
* **Delta**: ~32% reduction in cold startup time.

#### 2. In-Process Micro-Benchmarks

* **Refilter (20,000 entries × 10 passes)**: Decreased from 70 ms to **7 ms** (~10x faster). Uses pre-lowercased name caches and `Arc` refcounting instead of deep clones on keystrokes and file events.
* **Natural Sort (30,000 digit-heavy names)**: Decreased from 19 ms to **16 ms** (~15% faster) using allocation-free chunk parsing.

#### 3. Interaction Smoke Test (`bench-scroll.sh`)

* **Loaf**: 30 keypresses, 1,135 ms wall time, 32 ms CPU, RSS 189,452 → 192,776 kB.
* **Nautilus**: 10 keypresses, 377 ms wall time, 18 ms CPU, RSS 166,692 → 169,220 kB.

---

## Methodology & Verification

Benchmark automation scripts are maintained in `docs/bench/`:

1. **Cold Start Validation (`bench-open.sh`)**:
* Terminates active instances (`pkill -x loaf` / `nautilus -q`) to guarantee single-instance D-Bus handoffs do not skew timings.
* Spawns the process targeting `~/loaf-bench/big` with `--new-window`.
* Polls compositor IPC every 10 ms for window creation and matching folder title:
* **Hyprland**: `hyprctl clients -j | jq -e '.[] | select(.title | contains(...))'`
* **Niri**: `niri msg --json windows | jq -e '.[] | select(.title | contains(...))'`


* Records elapsed time, kills the process, and pauses for compositor teardown.


2. **Scroll & Interaction Test (`bench-scroll.sh`)**:
* Focuses the target window via compositor IPC (`hyprctl dispatch focuswindow` or `niri msg action focus-window`).
* Injects down-arrow events via `ydotool` at fixed intervals.
* Samples `/proc/$PID/stat` (`utime` + `stime`) and `/proc/$PID/status` (`VmRSS`) before and after interaction to isolate CPU utilization from input daemon wall latency.


3. **Renderer Parity**:
* Evaluated with `QSG_INFO=1` to confirm hardware-accelerated QRhi OpenGL context initialization (`vsync 16.67 ms`).
* Nautilus evaluated with `GSK_RENDERER=ngl`.



---

## Reproducing Benchmarks

### 1. Build Fixture & Release Binary

```bash
# Generate the 12,020-file test directory
bash docs/bench/loaf-bench-fixture.sh

# Compile optimized release binary
cargo build --release

```

### 2. Run Direct Cold Start Tests

```bash
# Test local release build
bash docs/bench/bench-open.sh target/release/loaf loaf ~/loaf-bench/big

# Test system-installed Loaf
bash docs/bench/bench-open.sh $(which loaf) loaf ~/loaf-bench/big

# Test system GNOME Nautilus
bash docs/bench/bench-open.sh $(which nautilus) nautilus ~/loaf-bench/big

```

### 3. Automated Sampling with Hyperfine

```bash
hyperfine --warmup 2 --runs 10 \
  --export-markdown bench-summary.md \
  'bash docs/bench/bench-open.sh target/release/loaf loaf ~/loaf-bench/big' \
  'bash docs/bench/bench-open.sh $(which loaf) loaf ~/loaf-bench/big' \
  'bash docs/bench/bench-open.sh $(which nautilus) nautilus ~/loaf-bench/big'

```

### 4. Frame Pacing & VSync Audit

Inspect per-frame sync, render, and swap times against the 16.6 ms (60 Hz) window budget:

```bash
QSG_RENDER_TIMING=1 target/release/loaf --new-window ~/loaf-bench/big

```
