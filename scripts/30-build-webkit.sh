#!/bin/bash
# WebKitGTK 4.1 —— Tauri 2 (wry 0.55) 硬依赖 webkit2gtk-4.1 ≥ 2.40 且走 libsoup3 后端
# 关键：在 glibc 2.28 锚点上编译，产物可直接跑在麒麟 V10 SP1
set -euxo pipefail

. /work/scripts/versions.sh
JOBS="$(nproc)"

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PREFIX}/lib/aarch64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}
export LD_LIBRARY_PATH=${PREFIX}/lib:${PREFIX}/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH:-}

# WebKit 的 Rust 组件
if ! command -v rustc >/dev/null 2>&1; then
  curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal
  . "$HOME/.cargo/env"
fi
rustc --version

mkdir -p "${SRC_DIR}" && cd "${SRC_DIR}"
[ -f "webkitgtk-${WEBKIT_VER}.tar.xz" ] || curl -fsSL -o "webkitgtk-${WEBKIT_VER}.tar.xz" "https://webkitgtk.org/releases/webkitgtk-${WEBKIT_VER}.tar.xz"
[ -d "webkitgtk-${WEBKIT_VER}" ] || tar xf "webkitgtk-${WEBKIT_VER}.tar.xz"
cd "webkitgtk-${WEBKIT_VER}"

bash /work/scripts/25-patch-webkit.sh

. /work/scripts/common-webkit-flags.sh

cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=${PREFIX} ${WEBKIT_CMAKE_FLAGS}

ninja -C build -j"${JOBS}"
ninja -C build install

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PREFIX}/lib/aarch64-linux-gnu/pkgconfig
pkg-config --modversion webkit2gtk-4.1
pkg-config --modversion javascriptcoregtk-4.1
ls -la ${PREFIX}/libexec/webkit2gtk-4.1/ 2>/dev/null || ls -la ${PREFIX}/libexec/webkit2gtk-4.0/ || true
echo "== WebKitGTK 4.1 完成 =="
