#!/bin/bash
# 编译 Sigma File Manager（Tauri 2）arm64 二进制 + 前端
set -euxo pipefail

UPSTREAM=https://github.com/aleksey-hoffman/sigma-file-manager.git
REF="${SFM_REF:-v2.2.0}"
PREFIX=/usr/local
WORK=/work

export PKG_CONFIG_PATH=${PREFIX}/lib/pkgconfig:${PREFIX}/lib/aarch64-linux-gnu/pkgconfig:${PKG_CONFIG_PATH:-}
export LD_LIBRARY_PATH=${PREFIX}/lib:${PREFIX}/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH:-}

# tauri 自己的 wry 特性里硬编码了 webkit2gtk/v2_40，特性合并后 cargo 一定要求
# pkg-config >= 2.40；而 2.40 需要 GCC >= 9.3，buster 只有 8.3。我们实际编的是
# 2.38.6，v2_40 相对它只是多一批 extern 声明（未引用的符号不进链接），
# 2.40 唯一被用到的 http_body 已由 45-patch-wry.sh 摘掉。
# 因此把 .pc 的版本号抬到 2.40.5 以满足 cargo 的版本断言。
for pc in $(find "${PREFIX}" -name 'webkit2gtk-4.1.pc' -print); do
  sed -i -E 's/^Version:.*/Version: 2.40.5/' "${pc}"
  echo "bumped ${pc}"
done
pkg-config --modversion webkit2gtk-4.1

# Node 24（package.json engines 要求）
if ! command -v node >/dev/null 2>&1; then
  NODE_VER=24.16.0
  curl -fsSL -o /tmp/node.tar.xz "https://nodejs.org/dist/v${NODE_VER}/node-v${NODE_VER}-linux-arm64.tar.xz"
  mkdir -p /opt/node && tar xf /tmp/node.tar.xz -C /opt/node --strip-components=1
  export PATH=/opt/node/bin:$PATH
fi
node -v && npm -v

if ! command -v cargo >/dev/null 2>&1; then
  # 上游没有锁死依赖版本，glib-sys 0.22 起要求 rustc 1.92+，所以用最新 stable
  curl -fsSL https://sh.rustup.rs | sh -s -- -y --profile minimal --default-toolchain stable
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

# 备用路线：目标 WebKit 只有 2.38 时，把 wry 对 2.40 接口的依赖摘掉
if [ "${PATCH_WRY_238:-0}" = "1" ]; then
  REPO="$(pwd)" bash /work/scripts/45-patch-wry.sh
fi

# 只编二进制，deb 由 50 脚本自己组（完全掌控依赖与自带库）
# 不做 --target 交叉指定：runner 本身是 aarch64，走原生路径避免 pkg-config 被 sysroot 化
npx tauri build --no-bundle --verbose 2>&1 | tail -60

RAW="$(find src-tauri/target -maxdepth 3 -type f -name sigma-file-manager -perm -u+x -print -quit)"
[ -n "${RAW}" ] || { echo "未找到编译产物"; ls -R src-tauri/target 2>/dev/null | head -40; exit 1; }
BIN="$(readlink -f "${RAW}")"
file "${BIN}" || true
ls -lh "${BIN}"
echo "BIN=${BIN}" > /tmp/app-bin.env
echo "== 应用编译完成 =="
