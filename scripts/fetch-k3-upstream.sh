#!/usr/bin/env bash
# Fetch SpacemiT K3 upstream kernel into a sibling work tree.
# Per patches/k3/README.md — we don't mirror the full BSP into kvm-kernel;
# upstream lives in /data/company/project/linux-6.18-spacemit-work/.
#
# Usage: ./scripts/fetch-k3-upstream.sh [<dest-dir>]

set -euo pipefail

DEST="${1:-/data/company/project/linux-6.18-spacemit-work}"
UPSTREAM="https://github.com/spacemit-com/linux-6.18.git"
BRANCH="k3-br-v1.0.y"

if [ -d "$DEST/.git" ]; then
    echo "[fetch-k3] existing tree at $DEST — pulling latest"
    cd "$DEST"
    git remote set-url origin "$UPSTREAM"
    git fetch --depth=1 origin "$BRANCH"
    git checkout "$BRANCH"
    git reset --hard "origin/$BRANCH"
else
    echo "[fetch-k3] shallow clone $UPSTREAM @ $BRANCH → $DEST"
    git clone --depth=1 --branch "$BRANCH" "$UPSTREAM" "$DEST"
fi

echo
echo "Work tree ready at: $DEST"
echo "Apply KVM patches:"
echo "  cd $DEST"
echo "  git am /data/company/project/kvm-kernel/patches/k3/*.patch"
echo
echo "Build (inside kvm-build-env Docker):"
echo "  docker run --rm -v \"$DEST:/work\" -w /work qiurui144/kvm-build-env:latest \\"
echo "    bash -c \"make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- spacemit_k3_defconfig \\"
echo "             && make ARCH=riscv CROSS_COMPILE=riscv64-linux-gnu- -j\$(nproc) Image dtbs\""
