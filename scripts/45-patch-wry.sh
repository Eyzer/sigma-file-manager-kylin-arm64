#!/bin/bash
# 让 wry 0.55 可以对着 WebKitGTK 2.38 编译（备用路线）
#
# 背景：wry 的 linux-body 特性打开了 webkit2gtk/v2_40，cargo 编译期就要求
# pkg-config >= 2.40。2.40 需要 GCC >= 9.3，buster 只有 8.3。
# 若 2.40 走不通，就把 wry 里唯一用到的 2.40 接口（自定义协议请求体）关掉，
# 退回 v2_38。代价：自定义协议的 POST 请求体拿不到（文件管理器基本不用）。
set -euxo pipefail

REPO="${REPO:-/work/src-repo}"
cd "${REPO}"

# 拉齐依赖源码，registry 里才有 wry 的完整包
( cd src-tauri && cargo fetch )

CARGO_SRC="${CARGO_HOME:-$HOME/.cargo}/registry/src"
W="$(find "${CARGO_SRC}" -maxdepth 2 -type d -name 'wry-0.55.*' -print -quit)"
[ -n "${W}" ] || { echo "registry 中找不到 wry-0.55.x"; exit 1; }
echo "vendor 源: ${W}"

rm -rf src-tauri/vendor/wry
mkdir -p src-tauri/vendor
cp -a "${W}" src-tauri/vendor/wry

# 1) 特性定义里去掉 webkit2gtk/v2_40
sed -i '/^linux-body = \[$/,/^\]/{/webkit2gtk\/v2_40/d}' src-tauri/vendor/wry/Cargo.toml

# 2) 关掉唯一使用 2.40 接口的代码块（保留 not(feature) 的兜底分支）
sed -i '0,/#\[cfg(feature = "linux-body")\]/s||#[cfg(feature = "linux-body-needs-webkit-2-40")]|' \
  src-tauri/vendor/wry/src/webkitgtk/web_context.rs

# 3) 指向本地副本
if ! grep -q '^\[patch.crates-io\]' src-tauri/Cargo.toml; then
  printf '\n[patch.crates-io]\nwry = { path = "vendor/wry" }\n' >> src-tauri/Cargo.toml
fi

echo "== 检查补丁结果 =="
grep -n -A4 '^linux-body = \[' src-tauri/vendor/wry/Cargo.toml
grep -n 'linux-body' src-tauri/vendor/wry/src/webkitgtk/web_context.rs | head
tail -4 src-tauri/Cargo.toml
