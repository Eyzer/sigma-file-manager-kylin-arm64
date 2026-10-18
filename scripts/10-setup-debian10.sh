#!/bin/bash
# 基础环境：Debian 10 (glibc 2.28) —— 与银河麒麟 V10 SP1 ABI 锚点一致
set -euxo pipefail

export DEBIAN_FRONTEND=noninteractive

# buster 已 EOL，官方源迁到 archive
cat > /etc/apt/sources.list <<'EOF'
deb http://archive.debian.org/debian buster main contrib non-free
deb http://archive.debian.org/debian-security buster/updates main contrib non-free
EOF
rm -rf /etc/apt/sources.list.d/*
mkdir -p /etc/apt/apt.conf.d
echo 'Acquire::Check-Valid-Until "false";' > /etc/apt/apt.conf.d/99archive
echo 'Acquire::Retries "5";' >> /etc/apt/apt.conf.d/99archive

apt-get update -qq

apt-get install -y --no-install-recommends \
  build-essential pkg-config git curl wget xz-utils ca-certificates \
  python3 python3-pip python3-setuptools ruby perl gperf bison flex \
  libgtk-3-dev libglib2.0-dev libxml2-dev libxslt1-dev libsqlite3-dev \
  libjpeg62-turbo-dev libpng-dev libwebp-dev libharfbuzz-dev \
  libfreetype6-dev libfontconfig1-dev libcairo2-dev libpango1.0-dev \
  libatk1.0-dev libgcrypt20-dev libsecret-1-dev libhyphen-dev \
  libegl1-mesa-dev libgles2-mesa-dev libgl1-mesa-dev libdrm-dev libgbm-dev \
  libx11-dev libxcomposite-dev libxdamage-dev libxext-dev libxfixes-dev \
  libxrender-dev libxt-dev libxrandr-dev libseccomp-dev libsystemd-dev \
  libtasn1-6-dev libbrotli-dev libpsl-dev libnghttp2-dev liblzma-dev zlib1g-dev \
  libxdo-dev librsvg2-dev libappindicator3-dev libnotify-dev \
  dpkg-dev fakeroot

# 可选包，缺了不致命
apt-get install -y --no-install-recommends libwoff-dev libmanette-0.2-dev || true
apt-get install -y --no-install-recommends libenchant-2-dev || true

# 新版本 cmake / ninja / meson（buster 自带的 cmake 3.13 不满足 WebKit 要求）
pip3 install --no-cache-dir "cmake==3.27.9" ninja meson
hash -r

cmake --version | head -1
ninja --version
meson --version
gcc --version | head -1
ldd --version | head -1

echo "== 环境就绪 =="
