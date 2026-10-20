#!/bin/bash
# 让 wry 0.55 可以对着 WebKitGTK 2.38 编译（备用路线）
#
# 背景：wry 的 linux-body 特性打开了 webkit2gtk/v2_40，cargo 编译期就要求
# pkg-config >= 2.40；而 WebKit 2.40 需要 GCC >= 9.3，buster 只有 8.3（实测
# std::is_constant_evaluated 与 NEON vld1q_u8_x4 均不可用）。
# 因此退回 2.38：把 wry 里用到 2.40 新符号的两处摘掉。
# 代价：自定义协议的 POST 请求体读不到、cookie 读不到（文件管理器均不受影响）。
set -euxo pipefail

REPO="${REPO:-/work/src-repo}"
cd "${REPO}/src-tauri"

# 版本以 Cargo.lock 为准，避免和上游漂移
WVER="$(awk '/^name = "wry"$/{f=1} f&&/^version = /{gsub(/[",]/,"");print $3;exit}' Cargo.lock)"
[ -n "${WVER}" ] || { echo "Cargo.lock 中找不到 wry"; exit 1; }
echo "wry 版本: ${WVER}"

rm -rf vendor/wry && mkdir -p vendor
curl -fsSL -o /tmp/wry.crate "https://crates.io/api/v1/crates/wry/${WVER}/download"
tar xzf /tmp/wry.crate -C vendor
mv "vendor/wry-${WVER}" vendor/wry

# 1) 特性定义里去掉 webkit2gtk/v2_40
sed -i '/^linux-body = \[$/,/^\]/{/webkit2gtk\/v2_40/d}' vendor/wry/Cargo.toml

# 2) 关掉唯一使用 2.40 接口的代码块，保留 not(feature) 的空实现兜底
sed -i '0,/#\[cfg(feature = "linux-body")\]/s||#[cfg(feature = "linux-body-needs-webkit-2-40")]|' \
  vendor/wry/src/webkitgtk/web_context.rs
# 兜底分支原本是 not(feature="linux-body")，但该特性仍被上游开着，
# 两个分支都进不去会导致 body 未初始化，改成恒真
sed -i 's|#\[cfg(not(feature = "linux-body"))\]|#[cfg(all())]|' \
  vendor/wry/src/webkitgtk/web_context.rs

# 3) webkit_cookie_manager_get_all_cookies 也是 2.40 才有的符号，
#    2.38.6 里根本没有，链接期会报 undefined reference。
#    把整个 trait 方法体换成返回空集合（文件管理器用不到 cookie）。
python3 - <<'PY'
p = "vendor/wry/src/webkitgtk/mod.rs"
s = open(p, encoding="utf-8").read()
start_marker = "  pub trait CookieManageExt"
end_marker = "  impl CookieManageExt for CookieManager {}"
start = s.find(start_marker)
end = s.find(end_marker)
assert start != -1 and end != -1 and end > start, "cookie 补丁定位失败"
stub = '''  pub trait CookieManageExt: IsA<CookieManager> + 'static {
    fn all_cookies<P: FnOnce(std::result::Result<Vec<soup::Cookie>, glib::Error>) + 'static>(
      &self,
      _cancellable: Option<&impl IsA<Cancellable>>,
      callback: P,
    ) {
      // [kylin-patch] get_all_cookies 是 WebKitGTK 2.40 新增符号，
      // 目标环境只有 2.38.6，直接返回空集合（本应用不使用 cookie）
      callback(Ok(Vec::new()));
    }
  }

  impl CookieManageExt for CookieManager {}'''
s = s[:start] + stub + s[end + len(end_marker):]
open(p, "w", encoding="utf-8", newline="\n").write(s)
print("cookie 补丁已应用")
PY
# 校验：桩体里不能再出现任何 2.40 符号引用
! grep -q "webkit_cookie_manager_get_all_cookies(" <(sed -n '/pub trait CookieManageExt/,/impl CookieManageExt for CookieManager {}/p' vendor/wry/src/webkitgtk/mod.rs)

# 4) 指向本地副本
# 注意：上游 Cargo.toml 里已经有 [patch.crates-io]（patch 了 drag），
# 不能再追加一个同名表（TOML 重复表会报错），必须插到已有表的第一行之后。
if ! grep -q '^wry *= *{ *path' Cargo.toml; then
  grep -q '^\[patch\.crates-io\]$' Cargo.toml || printf '\n[patch.crates-io]\n' >> Cargo.toml
  sed -i '/^\[patch\.crates-io\]$/a wry = { path = "vendor/wry" }' Cargo.toml
fi

echo "== 检查补丁结果 =="
grep -n -A4 '^linux-body = \[' vendor/wry/Cargo.toml
grep -n 'linux-body' vendor/wry/src/webkitgtk/web_context.rs | sed -n '1,6p'
grep -n -A3 '^\[patch\.crates-io\]$' Cargo.toml
# 硬校验：patch 必须真的挂上，否则 cargo 会静默用 crates.io 的原版 wry
grep -q '^wry *= *{ *path *= *"vendor/wry" *}$' Cargo.toml || { echo "patch 未写入 Cargo.toml"; exit 1; }
! grep -q 'webkit2gtk/v2_40' vendor/wry/Cargo.toml || { echo "v2_40 依赖仍在"; exit 1; }
