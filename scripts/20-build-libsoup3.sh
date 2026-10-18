#!/bin/bash
# libsoup 3.0 —— 麒麟 V10 只有 libsoup2，WebKitGTK 4.1 必须 libsoup3
set -euxo pipefail

SOUP_VER=3.0.7
PREFIX=/usr/local
mkdir -p /tmp/src && cd /tmp/src

curl -fsSL -o libsoup.tar.xz "https://download.gnome.org/sources/libsoup/3.0/libsoup-${SOUP_VER}.tar.xz"
tar xf libsoup.tar.xz
cd "libsoup-${SOUP_VER}"

meson setup build \
  --prefix=${PREFIX} \
  --libdir=${PREFIX}/lib \
  --buildtype=release \
  -Dintrospection=disabled \
  -Dvapi=disabled \
  -Dgtk_doc=false \
  -Dtests=false \
  -Dsysprof=disabled
ninja -C build -j"$(nproc)"
ninja -C build install

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PREFIX}/lib/aarch64-linux-gnu/pkgconfig
pkg-config --modversion libsoup-3.0
echo "== libsoup3 完成 =="
