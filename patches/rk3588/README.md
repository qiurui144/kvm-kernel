# RK3588 KVM patches (kernel 6.1.y)

Patch series applied on top of friendlyarm/kernel-rockchip @ nanopi6-v6.1.y.

## Series

| # | File | Description | Upstream target |
|---|------|-------------|-----------------|
| 1 | `0001-hdmirx-dmabuf.patch` | (TBD) HDMI-RX V4L2_MEMORY_DMABUF support | LKML / media subsystem |
| 2 | `0002-rga3-overlay-blend.patch` | (TBD) RGA3 hardware alpha-blend overlay | LKML / DRM |

## Apply

```bash
git apply patches/rk3588/0001-*.patch
# or
git am patches/rk3588/*.patch
```

## CI verifies

- `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- rockchip_defconfig`
- `make ARCH=arm64 CROSS_COMPILE=aarch64-linux-gnu- -j$(nproc) Image dtbs`
