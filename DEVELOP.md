# DEVELOP

> Developer onboarding. Everything compiles inside `qiurui144/kvm-build-env`
> Docker image — **no host pollution** per the KVM derivative-repo standard.

## Quickstart

```bash
# Pull build env
docker pull qiurui144/kvm-build-env:latest

# Or build from kvm-build-env source
git clone https://github.com/qiurui144/kvm-build-env.git
cd kvm-build-env && docker build -t kvm-build-env:dev .

# Build this repo (from this repo's root)
docker run --rm \
  -v "$PWD:/work" \
  -w /work \
  --user $(id -u):$(id -g) \
  qiurui144/kvm-build-env:latest \
  make build
```

## Make targets

- `make build` — build artifacts into `./build/`
- `make test` — run unit + integration tests
- `make clean` — clear `./build/` (does NOT touch cargo/go caches)
- `make release` — produce distributable artifact (deb / img / npm tarball)

## Branch + commit conventions

Per parent KVM CLAUDE.md §git push 策略:
- Default branch: `main` (post-rename from `master`)
- Direct push to main allowed after test passes (this is a personal/private project)
- 分支极简: no feature branches; tags only for releases
- Commit msg: `<type>(<scope>): <subject>` — types: feat / fix / docs / test / chore / perf / build / ci

## License header

All source files in this repo: see `LICENSE` at repo root.

## Issues / contribution

Bug reports + feature requests via GitHub Issues at this repo.
