# kvm-kernel

> Linux kernel for KVM appliances. **Two platforms, two separate branches**
> (never merged) — RK3588 on 6.1.y LTS, SpacemiT K3 on 6.18 OEM.

## ⚠️ Branch policy — DO NOT MERGE BETWEEN PLATFORMS

Per parent spec [`docs/specs/2026-05-25-derivative-repo-standard.md`](https://github.com/qiurui144/KVM/blob/master/docs/specs/2026-05-25-derivative-repo-standard.md) §0-bis:

| Branch | Hardware | Kernel | Upstream | Status |
|--------|----------|--------|----------|--------|
| **`main`** | (defaults to RK3588) | — | — | tracking pointer |
| **`rk3588-6.1.y`** | NanoPC-T6 (RK3588) | **6.1.y** LTS | [friendlyarm/kernel-rockchip](https://github.com/friendlyarm/kernel-rockchip) `nanopi6-v6.1.y` | **active** |
| **`k3-6.18.y`** | SpacemiT K1/K3 (RISC-V) | **6.18** OEM | SpacemiT BSP (TBD) | **planning** |
| **`upstream-sync`** | (mirror only) | — | 2-remote tracking helper | bookkeeping |

**Hard rules** (per spec §0-bis):
- ❌ Never `git merge` between `rk3588-6.1.y` and `k3-6.18.y` — incompatible kernel versions, different driver trees
- ❌ Never share a single `.patch` file across both unless the underlying code already exists in both upstreams
- ✅ Cross-branch porting must go via `git cherry-pick` + manual review + per-branch test

## KVM patches by branch

### rk3588-6.1.y (active)

| Patch | Status | Upstream target |
|-------|--------|-----------------|
| HDMI-RX V4L2_MEMORY_DMABUF support (rk_hdmirx) | wip | LKML / media subsystem |
| RGA3 overlay alpha-blend driver | wip | LKML / DRM subsystem |
| NPU IRQ affinity hints | proposed | Rockchip BSP only |

### k3-6.18.y (planning)

Pending hardware. Likely candidates once SpacemiT BSP is reviewed:
- SpacemiT NPU (IME2) driver integration with V4L2 capture
- K3-specific IRQ affinity for RISC-V cluster topology

## Branch-specific build

```bash
docker run --rm -v "$PWD:/work" -w /work \
  qiurui144/kvm-build-env:latest \
  bash -c "git checkout rk3588-6.1.y && make kernel-image kernel-headers"
# Outputs ./build/rk3588/boot.img + ./build/rk3588/kernel-headers-*.deb

docker run --rm -v "$PWD:/work" -w /work \
  qiurui144/kvm-build-env:latest \
  bash -c "git checkout k3-6.18.y && make kernel-image kernel-headers"
# Outputs ./build/k3/boot.img + ./build/k3/kernel-headers-*.deb
```

`make` Makefile auto-detects current branch and routes to the matching
`arch/<arch>` defconfig + cross-compile target.

## Tag policy

```
v<KVM-version>-rk3588-kernel    # e.g. v2.0.4-rk3588-kernel
v<K3-version>-k3-kernel         # e.g. v0.1.0-k3-kernel
```

Releases drive `kvm-image-builder` artifact selection by tag prefix.

## Upstream sync workflow

```bash
# RK3588 side
git remote add upstream-rk3588 https://github.com/friendlyarm/kernel-rockchip.git
git checkout rk3588-6.1.y
git fetch upstream-rk3588 nanopi6-v6.1.y
git merge upstream-rk3588/nanopi6-v6.1.y
# Resolve conflicts in KVM patches; CI must stay green

# K3 side
git remote add upstream-spacemit <url-when-published>
git checkout k3-6.18.y
git fetch upstream-spacemit <branch>
git merge upstream-spacemit/<branch>
```

## License

GPL-2.0 — inherits from Linux kernel. See [LICENSE](./LICENSE).

## Related

- [KVM main](https://github.com/qiurui144/KVM) — userspace consumer
- [kvm-uboot](https://github.com/qiurui144/kvm-uboot) — bootloader (also dual-branch)
- [kvm-image-builder](https://github.com/qiurui144/kvm-image-builder) — `make build PLATFORM=rk3588|k3`
- [kvm-build-env](https://github.com/qiurui144/kvm-build-env) — Docker cross-compile
