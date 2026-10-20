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
  python3 python3-pip python3-setuptools ruby perl gperf bison flex unifdef \
  libgtk-3-dev libglib2.0-dev libxml2-dev libxslt1-dev libsqlite3-dev \
  libjpeg62-turbo-dev libpng-dev libwebp-dev libharfbuzz-dev \
  libfreetype6-dev libfontconfig1-dev libcairo2-dev libpango1.0-dev \
  libatk1.0-dev libgcrypt20-dev libsecret-1-dev libhyphen-dev \
  libegl1-mesa-dev libgles2-mesa-dev libgl1-mesa-dev libdrm-dev libgbm-dev \
  libx11-dev libxcomposite-dev libxdamage-dev libxext-dev libxfixes-dev \
  libxrender-dev libxt-dev libxrandr-dev libseccomp-dev libsystemd-dev \
  libtasn1-6-dev libbrotli-dev libpsl-dev libnghttp2-dev liblzma-dev zlib1g-dev \
  libopenjp2-7-dev libjpeg-dev liblcms2-dev \
  libxdo-dev librsvg2-dev libappindicator3-dev libnotify-dev \
  dpkg-dev fakeroot libffi-dev libpcre2-dev libmount-dev gettext

# 可选包，缺了不致命
apt-get install -y --no-install-recommends libwoff-dev libmanette-0.2-dev || true

# buster 自带 pip 18，识别不了 manylinux2014 wheel，先升级
python3 -m pip install --no-cache-dir --upgrade "pip==21.3.1" "setuptools<60" wheel

# cmake：Kitware 官方 aarch64 预编译包，绕开 pip 轮子标签问题
curl -fsSL -o /tmp/cmake.tar.gz "https://github.com/Kitware/CMake/releases/download/v3.27.9/cmake-3.27.9-linux-aarch64.tar.gz"
mkdir -p /opt/cmake && tar xf /tmp/cmake.tar.gz -C /opt/cmake --strip-components=1
ln -sf /opt/cmake/bin/cmake /usr/local/bin/cmake
ln -sf /opt/cmake/bin/ctest /usr/local/bin/ctest

apt-get install -y --no-install-recommends ninja-build
pip3 install --no-cache-dir "meson==0.63.3"
hash -r

# 版本自检：用 sed 读完整流，避免 head 提前关闭管道触发 SIGPIPE（pipefail 下会直接 141 失败）
cmake --version 2>&1 | sed -n '1p'
ninja --version
meson --version
gcc --version 2>&1 | sed -n '1p'
ldd --version 2>&1 | sed -n '1p'

echo "== 环境就绪 =="
