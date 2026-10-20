#!/bin/bash
# 上游 ArgList.h 使用 jsCast 却没有包含定义它的头文件，只有靠包含顺序才碰巧编过。
# gcc 8 会直接报 "jsCast was not declared"。WebKit 官方到 2.42 才补上这条 include。
# 这里做前向移植，并且对已修复的版本自动跳过。
set -euxo pipefail

. /work/scripts/versions.sh

WK="${SRC_DIR}/webkitgtk-${WEBKIT_VER}"
ARG="$WK/Source/JavaScriptCore/runtime/ArgList.h"

[ -d "$WK" ] || { echo "找不到源码目录 $WK"; exit 1; }
[ -f "$ARG" ] || { echo "找不到 $ARG"; exit 1; }

if ! grep -q 'jsCast' "$ARG"; then
  echo "本版本未使用 jsCast，无需补丁"
  exit 0
fi

if grep -q '#include "JSCast.h"' "$ARG"; then
  echo "上游已自带 JSCast.h 包含，无需补丁"
  exit 0
fi

[ -f "$WK/Source/JavaScriptCore/runtime/JSCast.h" ] || {
  echo "源码中缺少 JSCast.h，无法定位 jsCast 定义"
  exit 1
}

# 插在第一条 #include 之后，保证 jsCast 在使用前已声明
sed -i '0,/#include/s||#include "JSCast.h"\n&|' "$ARG"

echo "== 补丁结果 =="
sed -n '1,40p' "$ARG" | grep -n '#include' | head -20
