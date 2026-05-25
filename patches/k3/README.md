# SpacemiT K3 KVM patches (kernel 6.18)

> **Upstream**: https://github.com/spacemit-com/linux-6.18 (branch `k3-br-v1.0.y`)
> **Device**: SpacemiT K3 (Key Stone), riscv64, 16 cores (X100 cluster + secondary)
> **Distro**: Bianbu 4.0rc1 (kernel `6.18.3-generic`)
> **Hardware status (2026-05-25)**: ssh-verified at `root@192.168.100.215` pw `bianbu`

## Status

Hardware **available**. KVM patch series **not yet written** — driver
tree audit done (see §"Driver tree highlights"); patch candidates
identified (see §"Patch candidates").

## Upstream + patch workflow

We do **not** mirror the full SpacemiT BSP into this repo (it's a full
Linux kernel tree, ~1 GB). Instead:

1. KVM patches live as `.patch` files in this directory
2. Build / develop using a sibling work tree:

   ```bash
   # On dev host (NOT on the K3 device — device only runs kernel):
   git clone --depth=1 -b k3-br-v1.0.y https://github.com/spacemit-com/linux-6.18.git \
       /data/company/project/linux-6.18-spacemit-work
   cd /data/company/project/linux-6.18-spacemit-work
   git am /data/company/project/kvm-kernel/patches/k3/*.patch
   ```

3. CI (when active) builds inside kvm-build-env Docker with the riscv64
   cross-compile toolchain (per `kvm-build-env/Dockerfile`)

## K3 hardware inventory (2026-05-25 ssh verify)

```
Architecture: riscv64
CPU: SpacemiT A100 (X100 cluster), 16 cores total
  cores 0-7  — primary cluster (active load: 350M+ timer ticks)
  cores 8-15 — secondary cluster (low load: ~80K ticks)
IRQ controller: APLIC-MSI + RISC-V INTC
Kernel: 6.18.3-generic (Bianbu 4.0rc1 = SpacemiT custom build)
linux-headers-6.18.3-generic installed at /usr/src/
```

## Driver tree highlights (from /proc/interrupts + lsmod)

| Subsystem | Resource | Notes |
|-----------|----------|-------|
| HDMA (8-channel DMA) | d8804000-d880b000 | 8 channels, currently idle |
| Mailbox | cac90000-cac90800 (3 controllers) | k3-mailbox driver |
| UFS HCD | irq 24 — heavy CPU4 use (42M counts) | onboard storage |
| USB | xhci ports USB1/2/4 | active |
| AIDMA (NPU access) | pMSI-soc:aidma-dev@0 | SpacemiT NPU primitive |
| RISC-V KVM | irq 12 | hypervisor (NOT our KVM product) |

NPU access through **AIDMA + mailbox** pattern (no `/dev/npu*` device
node visible — driver exposes via SpacemiT user-space SDK).

## Patch candidates (planning — NOT yet implemented)

### Candidate 1 — NPU OpenAI-compat shim

SpacemiT NPU runs through SDK + aidma device. To use as fast-tier LLM
for KVM Agent (per AI Home Assistant spec §0.5):
- Need user-space wrapper exposing `/v1/chat/completions` HTTP endpoint
- Either patch SpacemiT runtime or write a thin proxy
- **Out-of-scope** for kernel patches; tracked in kvm-rknn-models / AI HA repos

### Candidate 2 — IRQ affinity hints for cluster topology

Mirror the RK3588 approach (per `scripts/kvm-irq-affinity.sh`):
- Pin HDMA / mailbox / video IRQs to **cores 0-7** (primary X100 cluster)
- Keep cores 8-15 for background tasks (NAS / userspace)

This is a **userspace script** (not a kernel patch) — lives in
kvm-image-builder, not here.

### Candidate 3 — Video capture path (if K3 image ever does KVM appliance)

K3 has NO HDMI-RX equivalent in current dtb (no `hdmirx` IRQ visible).
For dual-role kvm-nas-dual on K3 hardware, would need:
- HDMI-RX SoC capability (TBD — K3 spec review needed)
- OR forgo video capture; K3 image = NAS-only variant

→ **Decision pending hardware spec review**. For now K3 image-builder
likely supports `nas-only` variant only.

## Build & deploy notes

- Dev host: cross-compile inside kvm-build-env (needs riscv64-linux-gnu-gcc)
- K3 device: install via `dpkg -i linux-image-*.deb` (Bianbu apt model);
  alternatively kvm-image-builder produces a full SD image for `nas-only`
  variant on K3
- Device has `/dev/kvm` (RISC-V hypervisor) — **NOT** our KVM project's
  KVM (just a name collision; ignore)

## Tag policy

```
v<X>-k3-kernel    e.g. v0.1.0-k3-kernel
```

## DO NOT merge with rk3588-6.1.y

- Different kernel version (6.18 vs 6.1)
- Different arch (riscv64 vs arm64)
- Different driver tree (SpacemiT vs Rockchip)
- Different upstream (spacemit-com/linux-6.18 vs friendlyarm/kernel-rockchip)

Per KVM main spec §0-bis: cross-branch port via `git cherry-pick` only,
never `git merge`.
