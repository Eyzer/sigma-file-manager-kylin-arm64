#!/bin/bash
# WebKitGTK 2.38 —— 提供 Tauri 2 强依赖的 webkit2gtk-4.1 (含 libsoup3 后端)
# 关键：在 glibc 2.28 锚点上编译，产物可直接跑在麒麟 V10 SP1
set -euxo pipefail

WEBKIT_VER=2.38.6
PREFIX=/usr/local
JOBS="$(nproc)"

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PREFIX}/lib/aarch64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}
export LD_LIBRARY_PATH=${PREFIX}/lib:${PREFIX}/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH:-}

# WebKit 的 Rust 组件
if ! command -v rustc >/dev/null 2>&1; then
  curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain 1.88.0
  . "$HOME/.cargo/env"
fi
rustc --version

mkdir -p /tmp/src && cd /tmp/src
curl -fsSL -o webkitgtk.tar.xz "https://webkitgtk.org/releases/webkitgtk-${WEBKIT_VER}.tar.xz"
tar xf webkitgtk.tar.xz
cd "webkitgtk-${WEBKIT_VER}"

. /work/scripts/common-webkit-flags.sh

cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=${PREFIX} ${WEBKIT_CMAKE_FLAGS}

ninja -C build -j"${JOBS}"
ninja -C build install

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PREFIX}/lib/aarch64-linux-gnu/pkgconfig
pkg-config --modversion webkit2gtk-4.1
pkg-config --modversion javascriptcoregtk-4.1
ls -la ${PREFIX}/libexec/webkit2gtk-4.1/ 2>/dev/null || ls -la ${PREFIX}/libexec/webkit2gtk-4.0/ || true
echo "== WebKitGTK 4.1 完成 =="
