#!/bin/bash
# 编译 Sigma File Manager（Tauri 2）arm64 二进制 + 前端
set -euxo pipefail

UPSTREAM=https://github.com/aleksey-hoffman/sigma-file-manager.git
REF="${SFM_REF:-v2.2.0}"
PREFIX=/usr/local
WORK=/work

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PREFIX}/lib/aarch64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}
export LD_LIBRARY_PATH=${PREFIX}/lib:${PREFIX}/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH:-}

# Node 24（package.json engines 要求）
if ! command -v node >/dev/null 2>&1; then
  NODE_VER=24.16.0
  curl -fsSL -o /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VER}/node-v${NODE_VER}-linux-arm64.tar.xz"
  mkdir -p /opt/node && tar xf /tmp/node.tar.xz -C /opt/node --strip-components=1
  export PATH=/opt/node/bin:$PATH
fi
node -v && npm -v

if ! command -v cargo >/dev/null 2>&1; then
  curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain 1.88.0
  . "$HOME/.cargo/env"
fi
export PATH="$HOME/.cargo/bin:$PATH"
cargo --version

mkdir -p "${WORK}" && cd "${WORK}"
rm -rf src-repo
git clone --depth 1 --branch "${REF}" "${UPSTREAM}" src-repo
cd src-repo
git log --oneline -1
node -e "console.log('app version', require('./package.json').version)"

npm ci --no-audit --no-fund

# 只编二进制，deb 由 50 脚本自己组（完全掌控依赖与自带库）
npx tauri build --no-bundle --target aarch64-unknown-linux-gnu --verbose 2>&1 | tail -60

BIN="src-tauri/target/aarch64-unknown-linux-gnu/release/sigma-file-manager"
test -x "${BIN}"
file "${BIN}" || true
ls -lh "${BIN}"
echo "== 应用编译完成 =="
