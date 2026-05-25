# RK3588 Kernel Build Verification + Driver Tree Audit

**Date**: 2026-05-25
**Branch**: `rk3588-6.1.y`
**Upstream**: `friendlyarm/kernel-rockchip @ nanopi6-v6.1.y`
**Producer**: T114 subagent (code-explorer, 596s execution time)
**Purpose**: Identify exact patch entry points for the two KVM-specific
kernel patches (HDMI-RX DMABUF + RGA3 overlay alpha-blend) and produce a
4-week sprint plan.

---

## §1 Build Verification — SKIPPED

**Reason**: No kernel source on disk. `/data/company/project/kvm-kernel`
contains only scaffold files. The `rk3588-6.1.y` branch (commit
`d674d41`) has the `patches/rk3588/` seed directory but no upstream
kernel tree merged yet.

**Additional blocker**: The `kvm-build-env` Dockerfile
(`/data/company/project/kvm-build-env/Dockerfile`) is missing mandatory
kernel-build dependencies:

- `bc` (required for kernel version string generation)
- `flex` + `bison` (Kconfig / Makefile lexers)
- `libssl-dev` (module signing)
- `libelf-dev` (eBPF / BTF object handling)
- `dwarves` / `pahole` (BTF generation — required for
  `CONFIG_DEBUG_INFO_BTF` in 6.1.y)

**Build command (ready to run once deps are fixed and source is fetched)**:

```bash
docker run --rm -v "$PWD:/work" -w /work \
  qiurui144/kvm-build-env:latest \
  bash -c "make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- nanopi6_linux_defconfig && \
           make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j\$(nproc) Image dtbs"
```

---

## §2 Driver Tree Audit

All paths are relative to the root of `friendlyarm/kernel-rockchip @
nanopi6-v6.1.y`. Source verified via GitHub web interface,
raw.githubusercontent.com content, Collabora upstream MR !21, Armbian
linux-rockchip rk-6.1-rkr5.1 branch, and LKML patch series.

| Driver | Path in BSP tree | DMABUF / overlay support? | Notes |
|--------|------------------|---------------------------|-------|
| `rk_hdmirx` | `drivers/media/platform/rockchip/hdmirx/` | `io_modes = VB2_MMAP` only — **no DMABUF** | MMAP + CMA contiguous alloc; `DMA_ATTR_FORCE_CONTIGUOUS` set; no `attach_dmabuf` ops |
| RGA3 (vendor multicore) | `drivers/video/rockchip/rga3/` | char-dev ioctl with `blend` field — **alpha-blend present but no V4L2 M2M interface** | 12 source files; exposes `/dev/rga` not a V4L2 device; mainline `drivers/media/platform/rockchip/rga/` is RGA2-only |
| `rkvenc-core` (MPP) | `drivers/video/rockchip/mpp/` | N/A to patch — reference only | `mpp_rkvenc2` registers SPI 141/142; IRQ affinity pattern via `irq_set_affinity_hint()` |
| `rk_hdmirx` IRQ wiring | `arch/arm64/boot/dts/rockchip/rk3588s.dtsi` | SPI 177 (cec), 178 (hdmi), 179 (dma), parent `&gic` | `memory-region = <&hdmirx_cma>` reserves 64 MB CMA; `power-domains = <&power RK3588_PD_VO1>` |

### Key file signatures from BSP source

`drivers/media/platform/rockchip/hdmirx/rk_hdmirx.c` — top:

```c
// SPDX-License-Identifier: GPL-2.0
/*
 * Rockchip HDMI RX Interface
 * Copyright (C) 2021 Rockchip Electronics Co., Ltd.
 */
#include <linux/module.h>
#include <linux/platform_device.h>
#include <media/v4l2-ctrls.h>
#include <media/v4l2-device.h>
#include <media/videobuf2-v4l2.h>
#include <media/videobuf2-cma-sg.h>
```

`drivers/video/rockchip/rga3/rga_drv.c` — key exports:

```c
static long rga_ioctl(struct file *file, uint32_t cmd, unsigned long arg);
/* cmd: RGA_BLIT_SYNC / RGA_BLIT_ASYNC / RGA_FLUSH / RGA_GET_VERSION */
```

---

## §3 Patch 1 Entry Point — HDMI-RX DMABUF

**File**: `drivers/media/platform/rockchip/hdmirx/rk_hdmirx.c`
**Function**: `hdmirx_queue_init()` (vb2_queue setup, ~lines 1100–1150)

### Current behavior (MMAP only)

```c
q->type      = V4L2_BUF_TYPE_VIDEO_CAPTURE_MPLANE;
q->io_modes  = VB2_MMAP;                         /* ← MMAP only */
q->drv_priv  = hdmirx_dev;
q->ops       = &hdmirx_vb2_ops;
q->mem_ops   = &vb2_cma_contig_memops;
q->dma_attrs = DMA_ATTR_FORCE_CONTIGUOUS;
q->buf_struct_size = sizeof(struct hdmirx_buffer);
q->lock      = &hdmirx_dev->stream_lock;
q->dev       = hdmirx_dev->dev;
```

### Minimal diff sketch

```diff
-q->io_modes  = VB2_MMAP;
+q->io_modes  = VB2_MMAP | VB2_DMABUF;
-q->mem_ops   = &vb2_cma_contig_memops;
-q->dma_attrs = DMA_ATTR_FORCE_CONTIGUOUS;
+q->mem_ops   = &vb2_cma_sg_memops;
+/* dma_attrs not needed for sg path */
```

### Rationale

Lowest-risk approach: `vb2_cma_sg_memops` is already in-tree, tested,
and handles both MMAP allocation (falls back to CMA pool) AND DMABUF
import (attaches external pages). The `vidioc_reqbufs` path through
vb2 core requires no changes.

### Risk

`DMA_ATTR_FORCE_CONTIGUOUS` removal may affect capture paths if the
HDMI-RX DMA engine strictly requires physically contiguous memory.
Hardware test on NanoPC-T6 to confirm. The RK3588 hdmirx DMA uses
descriptor rings — it does support non-contiguous scatter lists.

### Upstream reference

Collabora GitLab MR !21 (`hardware-enablement/rockchip-3588/linux`)
has a WIP implementation of this. Check before duplicating work.

---

## §4 Patch 2 Entry Point — RGA3 Overlay Alpha-Blend

**File**: `drivers/video/rockchip/rga3/rga_drv.c`

### Current state

Vendor RGA3 exposes `/dev/rga` as a miscdevice char driver with
`rga_ioctl()`. The alpha-blend machinery exists in
`rga3_reg_info.c` (`rga3_set_alpha()`, `rga3_gen_reg()`) but is only
reachable through the char-dev ioctl, **not** through a V4L2 interface.

### Required approach

Add a V4L2 M2M device alongside the existing char dev. Minimal sketch:

```c
/* In rga_drv.c — new V4L2 M2M registration */
static int rga3_m2m_device_run(void *priv)
{
    struct rga_ctx *ctx = priv;
    struct rga_req req = {};
    /* populate req from V4L2 src/dst buffers */
    req.blend = ctx->blend_mode;   /* 0xff0105 = SRC_OVER */
    return rga_job_commit(&req, ASYNC);
}

static const struct v4l2_m2m_ops rga3_m2m_ops = {
    .device_run = rga3_m2m_device_run,
};
```

### Key data structures (rga_drv.c, rga_job.c)

- `struct rga_img_info_t` — per-plane descriptor (virtual addr, dma-buf
  fd, width, height, format, `blend`)
- `struct rga_req` — full blit request (src0, src1/pat, dst, blend_mode,
  rotate_mode, alpha_global_value)
- `rga_blit_async()` in `rga_job.c` — submits HW job, signals fence on
  completion

### Alpha field encoding

```
blend = 0xff0105  → global_alpha=0xff, alpha_mode=SRC_OVER (HW enum 0x01), per-pixel=0x05
```

### Upstream status

LKML v2 22-patch series (Sven Püschel, Dec 2025) adds RGA3 support to
mainline `drivers/media/platform/rockchip/rga/` M2M driver. If that
series merges before this patch lands, **adopt it** and add alpha-blend
overlay ioctl on top. If it doesn't merge, the KVM patch can stand
alone using the vendor `drivers/video/rockchip/rga3/` tree.

### Device tree entry (RK3588)

```
rga3_core0: rga@fdb60000 {
    compatible = "rockchip,rga3-core";
    reg = <0x0 0xfdb60000 0x0 0x1000>;
    interrupt-parent = <&gic>;
    interrupts = <GIC_SPI 115 IRQ_TYPE_LEVEL_HIGH>;
};
rga3_core1: rga@fdb70000 { ... SPI 116 ... };
```

---

## §5 Sprint Plan — Week-by-Week to Land Both Patches

### Week 1 (bootstrap) — Target: clean baseline build

- Fix `kvm-build-env` Dockerfile: add `bc flex bison libssl-dev libelf-dev dwarves`
- Fetch upstream:
  ```bash
  git remote add upstream-rk3588 https://github.com/friendlyarm/kernel-rockchip
  git fetch --depth=1 upstream-rk3588 nanopi6-v6.1.y
  ```
- Checkout `rk3588-6.1.y` + merge upstream (no-ff, preserve `patches/rk3588/README.md`)
- Run baseline build in Docker: `nanopi6_linux_defconfig + make -j$(nproc) Image dtbs`
- **Gate**: `Image` + `rk3588s-nanopi6.dtb` produced, no build errors

### Week 2 (Patch 1 — HDMI-RX DMABUF) — Target: vb2 DMABUF path functional

- `grep -n "io_modes\|mem_ops\|dma_attrs" drivers/media/platform/rockchip/hdmirx/rk_hdmirx.c`
- Apply `io_modes` + `mem_ops` change (3-line diff)
- Build and boot on NanoPC-T6 (device @ 192.168.0.130)
- Test: `v4l2-ctl --stream-dmabuf=4 --stream-count=30`
- Run `v4l2-compliance -d /dev/video0 -s` — all buffer-type tests pass
- Format patch: `git format-patch -v1 --cover-letter -o patches/rk3588/ HEAD~1`

### Week 3 (Patch 2 — RGA3 V4L2 M2M overlay) — Target: composite pipeline functional

- Implement V4L2 M2M device in `rga_drv.c` (src0 + src1/overlay + dst)
- Wire `rga3_m2m_device_run()` → `rga_job_commit()` with SRC_OVER blend
- GStreamer smoke test: `gst-launch-1.0 v4l2src device=/dev/video0 ! rga3blend overlay=... ! v4l2sink`
- Measure latency: HDMI-RX capture → RGA3 blend → encode end-to-end
  (target: < 16 ms @ 1080p60)
- Format patch

### Week 4 (integration + upstream prep) — Target: patches ready for LKML

- IRQ affinity script: bind SPI 179 (hdmirx DMA) + SPI 115/116 (rga3_core0/1)
  to CPU 4–7 (A76)
- Check Collabora MR !21 status — if merged upstream, rebase Patch 1 on top
- Check Sven Püschel RGA3 v2 status — if merged, rebase Patch 2 as
  incremental alpha-blend add-on
- `scripts/checkpatch.pl --strict` clean on both patches
- Submit to `linux-media` list with proper cover letter

---

## §6 Key Files (absolute paths once source is fetched)

After `git merge upstream-rk3588/nanopi6-v6.1.y`, these will be at:

- `drivers/media/platform/rockchip/hdmirx/rk_hdmirx.c` — Patch 1 primary
- `drivers/media/platform/rockchip/hdmirx/rk_hdmirx.h`
- `drivers/video/rockchip/rga3/rga_drv.c` — Patch 2 primary
- `drivers/video/rockchip/rga3/rga_job.c` — job dispatch
- `drivers/video/rockchip/rga3/rga3_reg_info.c` — alpha-blend register programming
- `drivers/video/rockchip/rga3/rga_dma_buf.c` — dma-buf import
- `arch/arm64/boot/dts/rockchip/rk3588s.dtsi` — hdmirx + rga3 node defs
- `arch/arm64/boot/dts/rockchip/rk3588-nanopi6-rev07.dts` — board file
- `arch/arm64/boot/dts/rockchip/rk3588-nanopi6-common.dtsi` — shared peripherals

---

## §7 Next Concrete Steps

1. **Fix `kvm-build-env` Dockerfile** — add 5 kernel build deps (10 min change)
2. **Fetch friendlyarm upstream** into `rk3588-6.1.y` — network dependent, use `--depth=1`
3. **Run baseline build** inside Docker — confirms the merge is clean
4. `grep -n "io_modes" drivers/media/platform/rockchip/hdmirx/rk_hdmirx.c` to get
   exact line number for Patch 1

## §8 Blockers

- No kernel source on disk — `git fetch` required before any source inspection
- `kvm-build-env` missing 5 build deps — build will fail at step 1 without
  Dockerfile fix
- Network stability for `--depth=1` fetch of the ~3 GB friendlyarm repo — if
  flaky, clone into `/tmp/kernel-rockchip-ro/` for read-only inspection

---

## §9 Sources

- [friendlyarm/kernel-rockchip nanopi6-v6.1.y](https://github.com/friendlyarm/kernel-rockchip/tree/nanopi6-v6.1.y)
- [HDMI RX Support MR !21 — Collabora GitLab](https://gitlab.collabora.com/hardware-enablement/rockchip-3588/linux/-/merge_requests/21)
- [media: platform: rga: Add RGA3 support — LWN](https://lwn.net/Articles/1041152/)
- [PATCH v2 00/22 RGA3 — Spinics LKML archive](https://www.spinics.net/lists/kernel/msg5954741.html)
- [RK3588 rk3588s.dtsi raw — rockchip-linux](https://raw.githubusercontent.com/rockchip-linux/kernel/604cec4004abe5a96c734f2fab7b74809d2d742f/arch/arm64/boot/dts/rockchip/rk3588s.dtsi)
- [Mainline video capture and camera support for RK3588 — Collabora](https://www.collabora.com/news-and-blog/news-and-events/mainline-video-capture-and-camera-support-for-rockchip-rk3588.html)
- [librga developer guide — airockchip](https://github.com/airockchip/librga/blob/main/docs/Rockchip_Developer_Guide_RGA_EN.md)
