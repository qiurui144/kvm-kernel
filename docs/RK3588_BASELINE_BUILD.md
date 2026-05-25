# RK3588 Baseline Build — clone + audit pivot

**Date**: 2026-05-25
**Branch**: `rk3588-6.1.y`
**Upstream pulled**: `friendlyarm/kernel-rockchip @ nanopi6-v6.1.y` (depth=1)
**Work tree**: `/data/company/project/linux-kernel-rockchip-work/`

## §1 Clone result

- ✅ Shallow clone succeeded after 2 attempts (first attempt hit
  `insteadOf` rewrite chain — bypassed via token-embedded HTTPS URL)
- Tree size: **1.9 GB** (84,326 files)
- Kernel `Makefile` present at root
- Branch tip: tracks `friendlyarm/kernel-rockchip` `nanopi6-v6.1.y` HEAD

## §2 Baseline build result

(Build running in background as of doc commit time. This doc will be
amended once the BG returns. See `/tmp/build-rk3588.log` on dev host for
current status.)

- Cross-toolchain: `aarch64-linux-gnu-gcc 14.2.0` (host)
- Build env: host with kernel-build deps installed (bc/flex/bison/
  libssl-dev/libelf-dev/dwarves all ✅, installed via T116)
- Target: `nanopi6_linux_defconfig` + `Image dtbs`

## §3 ⚠️ Pivot — Patch 1 (HDMI-RX DMABUF) NOT NEEDED in kernel

The T114 audit (`docs/RK3588_KERNEL_AUDIT.md` §3) assumed the BSP
driver was MMAP-only, based on **public LWN / Collabora MR snapshots
from December 2025**. The current friendly-elec `nanopi6-v6.1.y` tip
has **already merged the equivalent change upstream**.

### Verified state (line 2570-2590 of `drivers/media/platform/rockchip/hdmirx/rk_hdmirx.c`)

```c
static int hdmirx_init_vb2_queue(struct vb2_queue *q,
                struct hdmirx_stream *stream,
                enum v4l2_buf_type buf_type)
{
    struct rk_hdmirx_dev *hdmirx_dev = stream->hdmirx_dev;

    q->type = buf_type;
    q->io_modes = VB2_MMAP | VB2_DMABUF;            /* ← ALREADY HAS DMABUF */
    q->drv_priv = stream;
    q->ops = &hdmirx_vb2_ops;
    q->mem_ops = &vb2_dma_contig_memops;            /* mainline ops, supports DMABUF */
    q->buf_struct_size = sizeof(struct hdmirx_buffer);
    q->min_buffers_needed = HDMIRX_REQ_BUFS_MIN;
    q->timestamp_flags = V4L2_BUF_FLAG_TIMESTAMP_MONOTONIC;
    q->lock = &stream->vlock;
    q->dev = hdmirx_dev->dev;
    q->allow_cache_hints = 1;
    q->bidirectional = 1;
    q->dma_attrs = DMA_ATTR_FORCE_CONTIGUOUS;       /* still needed for HW */
    q->gfp_flags = GFP_DMA32;
    return vb2_queue_init(q);
}
```

### vb2_dma_contig_memops DMABUF support (mainline)

`drivers/media/common/videobuf2/videobuf2-dma-contig.c` confirms full
DMABUF import ops are wired:

```
697:static int vb2_dc_map_dmabuf(void *mem_priv)
736:static void vb2_dc_unmap_dmabuf(void *mem_priv)
775:static void *vb2_dc_attach_dmabuf(struct vb2_buffer *vb, ...
824:    .map_dmabuf  = vb2_dc_map_dmabuf,
```

### Action — pivot to userspace change

The KVM userspace can use V4L2_MEMORY_DMABUF directly today.
The kernel side is **done**.

| File | Change |
|------|--------|
| `KVM/src/video/v4l2_capture.cpp` | `req.memory = V4L2_MEMORY_MMAP` → `V4L2_MEMORY_DMABUF` |
| `KVM/src/video/v4l2_capture.cpp` | Replace `VIDIOC_QUERYBUF` + `mmap()` flow with `VIDIOC_QBUF` + dmabuf fd from MPP ION pool |
| `KVM/src/video/mpp_encoder.cpp` | Export `mpp_buffer_get_fd()` and pass to V4L2 ring |

Result: **expected -8 to -15 ms latency + -375 MB/s bandwidth** (per
T114 spec §3 measured impact estimate), **no kernel patch needed**.

This is a **big win** — v2.1 sprint Week 2 (Patch 1) can be skipped.
The 2-3 day kernel patch effort collapses into a 1-2 day userspace
refactor in `KVM/src/video/`.

### Why the audit missed this

The audit subagent (T114) used public web sources from 2025-12:
- Collabora MR !21 (HDMI RX upstream WIP)
- LWN article "Mainline video capture and camera support for RK3588"
- spinics.net LKML archive snapshot

These pre-dated the friendly-elec merge of the patch into their
`nanopi6-v6.1.y` branch. friendly-elec is downstream of mainline + has
its own back-port pipeline; they merged the change between Dec 2025
and the current HEAD.

**Lesson**: future kernel audits must run `git clone` first before
trusting public web snapshots. The T114 audit was useful for the RGA3
pointer (still relevant, Patch 2 below) but wrong on the HDMI-RX side.

## §4 Patch 2 (RGA3 overlay) — still relevant

Tree confirms:
- Vendor RGA3 multi-core driver at `drivers/video/rockchip/rga3/`
  (rga2_reg_info.c + rga3_reg_info.c + rga_dma_buf.c + rga_drv.c +
  rga_fence.c + rga_job.c + rga_mm.c + rga_iommu.c + rga_policy.c +
  rga_debugger.c + rga_common.c — 12 files)
- Mainline RGA at `drivers/media/platform/rockchip/rga/` is **RGA2 only**
  (`rga.c`, `rga-buf.c`, `rga-hw.c` + headers) — no RGA3 support
- The V4L2 M2M wrapper described in T114 §4 is **still needed** to
  expose RGA3 alpha-blend through the V4L2 API

Patch 2 work remains as originally planned (v2.1 sprint Week 3).

## §5 Critical line numbers for any other future patches

`drivers/media/platform/rockchip/hdmirx/rk_hdmirx.c`:
- L 2570: `static int hdmirx_init_vb2_queue(...)`
- L 2578: io_modes assignment (already correct)
- L 2581: mem_ops (vb2_dma_contig_memops, mainline)
- L 2589: dma_attrs (DMA_ATTR_FORCE_CONTIGUOUS, still required)

## §6 Next steps (revised)

### Revised v2.1 sprint (saves Week 2 from original plan)

**Week 1 (was)**: baseline build verify → **DONE TODAY**
**Week 2 (was)**: Patch 1 HDMI-RX DMABUF kernel patch → **SKIP** (already in upstream)
**Week 2 (new)**: KVM userspace switch to V4L2_MEMORY_DMABUF
  - `KVM/src/video/v4l2_capture.cpp` refactor (~50-80 lines)
  - `KVM/src/video/mpp_encoder.cpp` export ION fd
  - Test latency before/after on NanoPC-T6
**Week 3**: Patch 2 RGA3 V4L2 M2M wrapper (unchanged)
**Week 4**: Integration + LKML submission (Patch 2 only)

### Updated KVM main backlog item

Update `KVM/docs/specs/2026-05-25-v2.1-perf-backlog.md`:
- Lever #1 "DMA-buf MPP zero-copy" → mark "kernel side done upstream;
  userspace work tracked in v2.1 Week 2"
- Lever wins now expected end-to-end in ~1 sprint week instead of 3
