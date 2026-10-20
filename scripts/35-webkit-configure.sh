#!/bin/bash
# WebKitGTK 4.1 配置校验：只跑 cmake 配置，不编译。提前暴露缺库/缺头文件
set -euxo pipefail

. /work/scripts/versions.sh
. /work/scripts/common-webkit-flags.sh

mkdir -p "${SRC_DIR}" && cd "${SRC_DIR}"
if [ ! -d "webkitgtk-${WEBKIT_VER}" ]; then
  curl -fsSL -o "webkitgtk-${WEBKIT_VER}.tar.xz" "https://webkitgtk.org/releases/webkitgtk-${WEBKIT_VER}.tar.xz"
  tar xf "webkitgtk-${WEBKIT_VER}.tar.xz"
fi
cd "webkitgtk-${WEBKIT_VER}"

bash /work/scripts/25-patch-webkit.sh

export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib/aarch64-linux-gnu/pkgconfig
echo "== pkg-config 校验 =="
pkg-config --modversion glib-2.0
pkg-config --modversion libsoup-3.0
pkg-config --modversion gtk+-3.0
pkg-config --modversion libopenjp2

cmake -S . -B build -G Ninja -DCMAKE_INSTALL_PREFIX=/usr/local ${WEBKIT_CMAKE_FLAGS}

echo "== WebKit 配置通过 =="
grep -E "^(ENABLE_JIT|ENABLE_VIDEO|ENABLE_WEBGL|USE_SOUP2):" build/CMakeCache.txt || true
