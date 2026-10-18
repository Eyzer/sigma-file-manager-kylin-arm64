#!/bin/bash
# libsoup 3.0 —— 麒麟 V10 只有 libsoup2，WebKitGTK 4.1 必须 libsoup3
set -euxo pipefail

SOUP_VER=3.0.7
PREFIX=/usr/local
mkdir -p /tmp/src && cd /tmp/src

curl -fsSL -o libsoup.tar.xz "https://download.gnome.org/sources/libsoup/3.0/libsoup-${SOUP_VER}.tar.xz"
tar xf libsoup.tar.xz
cd "libsoup-${SOUP_VER}"

# gcc 8 在 -O3 内联 skip 路径时把 gsize 当指针，误报 strncmp 参数为 NULL。
# meson 会把项目警告参数排在后面，所以用包装器把抑制参数追加到命令行末尾。
mkdir -p /tmp/ccwrap
cat > /tmp/ccwrap/cc <<'EOF'
#!/bin/sh
exec /usr/bin/cc "$@" -Wno-nonnull -Wno-error=nonnull -Wno-maybe-uninitialized -Wno-error=maybe-uninitialized -Wno-stringop-overflow -Wno-array-bounds
EOF
chmod +x /tmp/ccwrap/cc
cp /tmp/ccwrap/cc /tmp/ccwrap/c++
export CC=/tmp/ccwrap/cc
export CXX=/tmp/ccwrap/c++

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
