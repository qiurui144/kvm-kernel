# kvm-kernel — AI Working Instructions

Per parent KVM project ([/data/company/project/KVM/CLAUDE.md](https://github.com/qiurui144/KVM/blob/master/CLAUDE.md)) + global ~/.claude/CLAUDE.md.

## Repo scope
Linux kernel for KVM (fork of friendlyarm/kernel-rockchip nanopi6-v6.1.y + KVM patches: HDMI-RX DMABUF + RGA3 overlay-blend)

## Build environment

**MANDATORY**: All builds run inside the kvm-build-env Docker image. No host
toolchain installation. See `DEVELOP.md` for the docker run incantation.

## Branch + push policy

Per parent KVM CLAUDE.md §git push 策略:
- Default branch `main` — direct push allowed after test passes
- 分支极简: no feature branches; tags only for releases

## License + attribution

This repo: see `LICENSE` at root.
Parent KVM main repo (private) maintains its own license.
