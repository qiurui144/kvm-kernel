# K3 Baseline Build — SpacemiT BSP clone + riscv64 cross-compile

**Date**: 2026-05-25
**Branch**: `k3-6.18.y`
**Upstream pulled**: `spacemit-com/linux-6.18 @ k3-br-v1.0.y` (depth=1)
**Work tree**: `/data/company/project/linux-6.18-spacemit-work/`

## §1 Clone result

- ✅ Shallow clone succeeded with token-embedded HTTPS URL
- Tree size: **2.2 GB** (93,350 files — slightly larger than RK3588 BSP)
- Kernel `Makefile` present
- Helper script confirmed: `scripts/fetch-k3-upstream.sh` (in kvm-kernel)

## §2 Baseline build result

- ✅ `make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- k3_bianbu_defconfig`
- ✅ `make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc) Image dtbs`
- **Image**: `arch/riscv/boot/Image` = **33,817,600 bytes (32.3 MB)**
- **DTBs produced (sample)**:
  - `k3_deb1.dtb` ← **our K3 device** (hostname `qiurui-spacemitk3deb1`)
  - `k3_evb.dtb`, `k3_evb2-1.dtb`, `k3_evb2-2.dtb` (eval boards)
  - `k3_fpga_1x1.dtb` (FPGA dev)
  - `k3_BS01DCMA.dtb`, `k3_com260.dtb`, `k3_com260_ifx.dtb`,
    `k3_com260_kit_v02.dtb`, `k3_dc_board.dtb` (form factor variants)
- **Build time**: ~16 minutes wall-clock (host parallel make)
- **Warnings**: none in tail; full log at `/tmp/build-k3.log`

## §3 K3 SoC driver inventory

```
drivers/pinctrl/spacemit/
drivers/soc/spacemit/             ← K3 SoC core helpers
drivers/soc/spacemit/v2d/         ← 2D engine (vendor-specific; SpacemiT's equivalent to RGA)
drivers/soc/spacemit/pm_domain/   ← power domain
drivers/soc/spacemit/suspend/     ← suspend / S2RAM
drivers/mailbox/spacemit/         ← inter-cluster mailbox (NPU communication)
drivers/clk/spacemit/             ← clock framework
drivers/phy/spacemit/             ← USB/Ethernet PHY
drivers/gpu/drm/spacemit/         ← DRM/KMS GPU driver
drivers/net/ethernet/spacemit/    ← onboard Ethernet
```

### Notable findings

1. **v2d** = SpacemiT's analog of Rockchip RGA — vendor-specific 2D
   accelerator. If we ever need hardware watermark on K3 (currently
   K3 image is `nas-only`, no video pipeline) we'd target this.
2. **mailbox/spacemit** = the AIDMA NPU access primitive verified live
   on K3 device (`pMSI-soc:aidma-dev@0` in /proc/interrupts).
3. **Camera sensors plenty**: IMX219 / IMX415 / OV5647 / OV2735 + GMSL2
   (MAX96724 + MAX9295) — confirms K3 was designed for vision/camera
   board variants, **not** the HDMI-RX pattern KVM uses on RK3588.

### Defconfig key options (k3_bianbu_defconfig)

```
CONFIG_SPACEMIT_K3_CPUFREQ=y      ← cpufreq driver (governor support)
CONFIG_SPACEMIT_K1_WATCHDOG=y     ← watchdog driver (shared with K1)
CONFIG_SPACEMIT_K3_CCIC=y         ← camera input controller
CONFIG_SPACEMIT_K3_CCIC_IOMMU=y   ← + IOMMU
CONFIG_SPACEMIT_K3_CAM_*=y        ← 5 camera sensor drivers
```

## §4 K3 dtsi structure

`arch/riscv/boot/dts/spacemit/`:

```
k3.dtsi                       ← SoC core (CPUs, interrupts, memory)
k3-cpus.dtsi                  ← X100 cluster definitions
k3-pinctrl.dtsi               ← pin muxing
k3-camera.dtsi                ← CSI camera bindings
k3-camera-sensor-fpga.dtsi    ← FPGA stand-in
k3-dp0.dtsi / k3-dp1.dtsi     ← DisplayPort outputs
k3-edp0.dtsi                  ← embedded DisplayPort
k3-rdomain.dtsi               ← reset domain framework
k3_opp_table.dtsi             ← OPP voltage/frequency table
```

Our K3 device boots `k3_deb1.dts` — Bianbu dev board variant.

## §5 KVM use case for K3 — pivot to NAS-only

Confirms the §"Patch candidates" assessment in `patches/k3/README.md`:

- ❌ **No HDMI-RX in K3 dtb** — `k3.dtsi` has DP/eDP outputs (display
  side) but **no HDMI-RX input**. The KVM appliance video capture
  pattern from RK3588 cannot be ported.
- ✅ **K3 fits NAS-only image variant** (per kvm-image-builder spec)
- ✅ **K3 NPU can fast-tier the AI Home Assistant** — via aidma /
  mailbox + SpacemiT user-space NPU SDK (out of scope for kernel; in
  scope for `ai-home-assistant` platform adapter `src/ai_ha/platform/k3.py`)

### Decision

K3 image variant matrix:
- `kvm-only` on K3: **N/A** (no HDMI-RX hardware path)
- `nas-only` on K3: ✅ default — OMV + Docker + HA + ai-home-assistant
- `kvm-nas-dual` on K3: **N/A** (no KVM appliance role)

`kvm-image-builder` should reject `--variant kvm-only --platform k3`
combo with a clear error message in v0.2+ (currently silent
non-implementation).

## §6 Next steps

1. **kvm-image-builder** — add platform×variant compatibility check
   (reject `kvm-only/k3` + `kvm-nas-dual/k3`)
2. **ai-home-assistant** — implement `platform/k3.py` adapter wrapping
   the SpacemiT NPU SDK (when SpacemiT releases the user-space SDK
   header set)
3. **Cross-test**: build NAS-only K3 image via image-builder pipeline
   once Phase 1 image-builder is functional (currently scaffolded but
   never executed end-to-end)
4. **K3 IRQ affinity script** — adapt `scripts/kvm-irq-affinity.sh` to
   match K3 IRQ naming (`hdma` `mailbox` `ufs` etc instead of `hdmirx`
   `rkvenc` etc.) — track in kvm-image-builder issues

## §7 Lesson reaffirmed

Same lesson as RK3588 audit (§3 of `RK3588_BASELINE_BUILD.md`):
**clone first, trust web sources second**. Both audits found the
real-tree state was different from public snapshots. For RK3588 the
delta was "feature already merged"; for K3 the delta is "no HDMI-RX
peripheral exists" — neither was obvious from public docs.
