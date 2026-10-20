#!/bin/bash
# 只编 JavaScriptCore：这是 WebKit 里最早暴露编译器兼容问题的一大块（约 5500 个目标的一半）
# 用来在 15 分钟内判定补丁是否有效，不必等 4 小时的完整编译
set -euxo pipefail

WK=/tmp/src/webkitgtk-2.38.6
cd "$WK"

export PKG_CONFIG_PATH=/usr/local/lib/pkgconfig:/usr/local/lib/aarch64-linux-gnu/pkgconfig
export LD_LIBRARY_PATH=/usr/local/lib:/usr/local/lib/aarch64-linux-gnu:${LD_LIBRARY_PATH:-}

ninja -C build -j"$(nproc)" JavaScriptCore

echo "== JavaScriptCore 编译通过 =="
ls -la build/lib/libjavascriptcoregtk-4.1.so* 2>/dev/null || find build -name "libjavascriptcoregtk*" | head
