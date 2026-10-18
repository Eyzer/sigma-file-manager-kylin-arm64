#!/bin/bash
# glib 2.72 —— libsoup3 要求 glib >= 2.69.1，buster 只有 2.58，必须自带
set -euxo pipefail

GLIB_VER=2.72.4
PREFIX=/usr/local
mkdir -p /tmp/src && cd /tmp/src

curl -fsSL -o glib.tar.xz "https://download.gnome.org/sources/glib/2.72/glib-${GLIB_VER}.tar.xz"
tar xf glib.tar.xz
cd "glib-${GLIB_VER}"

meson setup build \
  --prefix=${PREFIX} \
  --libdir=${PREFIX}/lib \
  --buildtype=release \
  -Dselinux=disabled \
  -Dlibmount=enabled \
  -Dman=false \
  -Dgtk_doc=false \
  -Dtests=false \
  -Dinstalled_tests=false \
  -Dnls=disabled \
  -Dsysprof=disabled
ninja -C build -j"$(nproc)"
ninja -C build install

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PREFIX}/lib/aarch64-linux-gnu/pkgconfig
pkg-config --modversion glib-2.0
pkg-config --modversion gio-2.0
ls ${PREFIX}/share/glib-2.0/schemas/ | head
echo "== glib 2.72 完成 =="
