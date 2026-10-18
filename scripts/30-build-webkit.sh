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

cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=${PREFIX} \
  -DPORT=GTK \
  -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ \
  -DENABLE_DOCUMENTATION=OFF \
  -DENABLE_GTK_DOC=OFF \
  -DENABLE_INTROSPECTION=OFF \
  -DENABLE_MINIBROWSER=OFF \
  -DENABLE_SPELLCHECK=OFF \
  -DENABLE_GAMEPAD=OFF \
  -DENABLE_GEOLOCATION=OFF \
  -DENABLE_MEDIA_STREAM=OFF \
  -DENABLE_VIDEO=OFF \
  -DENABLE_WEB_AUDIO=OFF \
  -DENABLE_WEB_RTC=OFF \
  -DENABLE_WEBGL=ON \
  -DUSE_GSTREAMER=OFF \
  -DENABLE_BUBBLEWRAP_SANDBOX=OFF \
  -DENABLE_SANDBOXED_SPEECH=OFF \
  -DENABLE_JIT=ON \
  -DUSE_SYSTEM_MALLOC=ON \
  -DENABLE_LTO=OFF \
  -DENABLE_X11_TARGET=ON \
  -DENABLE_WAYLAND_TARGET=OFF \
  -DUSE_LIBHYPHEN=ON \
  -DUSE_WOFF2=ON \
  -DENABLE_DATABASE_PROCESS=OFF \
  -DENABLE_SERVICE_WORKER=ON \
  -DENABLE_PDF_JS=OFF \
  -DENABLE_MALLOC_HEAP_BREAKDOWN=OFF

ninja -C build -j"${JOBS}"
ninja -C build install

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PREFIX}/lib/aarch64-linux-gnu/pkgconfig
pkg-config --modversion webkit2gtk-4.1
pkg-config --modversion javascriptcoregtk-4.1
ls -la ${PREFIX}/libexec/webkit2gtk-4.1/ 2>/dev/null || ls -la ${PREFIX}/libexec/webkit2gtk-4.0/ || true
echo "== WebKitGTK 4.1 完成 =="
