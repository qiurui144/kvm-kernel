# SpacemiT K3 KVM patches (kernel 6.18 OEM)

Status: **planning**. Awaiting K3 hardware + SpacemiT OEM BSP review.

## Planned series

| # | File | Description |
|---|------|-------------|
| (TBD) | SpacemiT NPU integration | IME2 driver glue for V4L2 |
| (TBD) | K3 IRQ affinity | RISC-V cluster topology hints |

## Apply

```bash
# Once SpacemiT BSP is forked here, apply via git am
git am patches/k3/*.patch
```

## CI (when active)

- `make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- spacemit_k3_defconfig`
- `make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j$(nproc) Image dtbs`

## DO NOT mix with rk3588-6.1.y

Different kernel version (6.18 vs 6.1), different driver tree
(SpacemiT vs Rockchip), different arch (RISC-V vs ARM64). Even when
upstream merges a feature into mainline, port via cherry-pick + manual
review, not branch merge.
