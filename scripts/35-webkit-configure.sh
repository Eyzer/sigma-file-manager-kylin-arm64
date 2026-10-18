#!/bin/bash
# WebKitGTK 4.1 配置校验：只跑 cmake 配置，不编译。用来提前暴露缺库/缺头文件
set -euxo pipefail

mkdir -p /tmp/src && cd /tmp/src
if [ ! -d webkitgtk-2.38.6 ]; then
  curl -fsSL -o webkitgtk.tar.xz "https://webkitgtk.org/releases/webkitgtk-2.38.6.tar.xz"
  tar xf webkitgtk.tar.xz
fi
cd webkitgtk-2.38.6

export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib/aarch64-linux-gnu/pkgconfig
echo "== pkg-config 校验 =="
pkg-config --modversion glib-2.0
pkg-config --modversion libsoup-3.0
pkg-config --modversion gtk+-3.0

cmake -S . -B build -G Ninja -DPORT=GTK -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr/local \
  -DENABLE_DOCUMENTATION=OFF \
  -DENABLE_INTROSPECTION=OFF \
  -DENABLE_MINIBROWSER=OFF \
  -DENABLE_SPELLCHECK=OFF \
  -DENABLE_GAMEPAD=OFF \
  -DENABLE_GEOLOCATION=OFF \
  -DENABLE_MEDIA_STREAM=OFF \
  -DENABLE_VIDEO=OFF \
  -DENABLE_WEB_AUDIO=OFF \
  -DENABLE_WEB_RTC=OFF \
  -DUSE_GSTREAMER=OFF \
  -DENABLE_BUBBLEWRAP_SANDBOX=OFF \
  -DENABLE_JIT=ON \
  -DUSE_SYSTEM_MALLOC=ON \
  -DENABLE_LTO=OFF \
  -DENABLE_X11_TARGET=ON \
  -DENABLE_WAYLAND_TARGET=OFF \
  -DENABLE_DATABASE_PROCESS=OFF

echo "== WebKit 配置通过 =="
grep -E "ENABLE_(JIT|VIDEO|WEB_RTC|SPELLCHECK)|USE_SOUP2|LIBEXEC_INSTALL_DIR" build/CMakeCache.txt | head -20
