# kvm-kernel

> Linux kernel for the KVM RK3588 IP-KVM appliance.
> Fork of [friendlyarm/kernel-rockchip](https://github.com/friendlyarm/kernel-rockchip)
> branch `nanopi6-v6.1.y` + KVM-specific patches.

## KVM patches on top of upstream

| Patch | Status | Upstream target |
|-------|--------|-----------------|
| HDMI-RX V4L2_MEMORY_DMABUF support (rk_hdmirx) | wip | LKML / media subsystem (drivers/media/platform/rockchip/) |
| RGA3 overlay alpha-blend driver | wip | LKML / DRM subsystem |
| NPU IRQ affinity hints | proposed | Rockchip BSP only (vendor specific) |

Each patch lives in `patches/` as a numbered series, applied via `git am`
during the build. See `BUILD.md` for the apply sequence.

## Build

Inside `kvm-build-env` Docker (per derivative-repo standard §7):

```bash
docker run --rm -v "$PWD:/work" -w /work \
  qiurui144/kvm-build-env:latest \
  make kernel-image kernel-headers
```

Outputs to `./build/`:
- `boot.img` — kernel + DTB packed for sd-fuse
- `kernel-headers-*.deb` — for `kvm-server` userspace builds

## Branch model

| Branch | Use |
|--------|-----|
| `main` | Stable — what `kvm-image-builder` consumes |
| `nanopi6-v6.1.y` | Mirror of upstream friendly-elec (sync periodically) |
| `kvm-patches/<topic>` | Per-feature patch dev branches |

## Upstream sync

```bash
git remote add upstream https://github.com/friendlyarm/kernel-rockchip.git
git fetch upstream nanopi6-v6.1.y
git checkout nanopi6-v6.1.y && git merge upstream/nanopi6-v6.1.y
# rebase main onto refreshed nanopi6-v6.1.y manually
```

## License

GPL-2.0 — see [LICENSE](./LICENSE). Inherits from Linux kernel.

## Related

- [KVM main repo](https://github.com/qiurui144/KVM) (private) — userspace
- [kvm-uboot](https://github.com/qiurui144/kvm-uboot) — bootloader
- [kvm-image-builder](https://github.com/qiurui144/kvm-image-builder) — image gen
- [kvm-build-env](https://github.com/qiurui144/kvm-build-env) — Docker build
