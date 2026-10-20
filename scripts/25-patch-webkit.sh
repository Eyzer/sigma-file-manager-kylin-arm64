#!/bin/bash
# WebKit 2.38 在 gcc 下有两个已知的头文件顺序问题，上游 2.42 才修。
# 这里前向移植两条补丁，避免编译到 JavaScriptCore 才失败。
set -euxo pipefail

WK=/tmp/src/webkitgtk-2.38.6
ARG="$WK/Source/JavaScriptCore/runtime/ArgList.h"

if [ ! -f "$ARG" ]; then
  echo "找不到 $ARG"
  exit 1
fi

if grep -q '#include "JSCast.h"' "$ARG"; then
  echo "补丁已存在，跳过"
else
  # 定位定义 jsCast 的头文件
  JSCAST_REL=$(grep -rl "jsCast" "$WK/Source/JavaScriptCore/runtime" --include="*.h" | grep -E "JSCast\.h|JSObject\.h" | head -1)
  if [ -n "$JSCAST_REL" ]; then
    JSCAST_INC=$(basename "$JSCAST_REL")
  else
    JSCAST_INC="JSObject.h"
  fi
  echo "使用 $JSCAST_INC 提供 jsCast"
  sed -i "s|#include \"CallFrame.h\"|#include \"CallFrame.h\"\n#include \"$JSCAST_INC\"|" "$ARG"
  sed -n '20,30p' "$ARG"
fi

grep -n "jsCast" "$ARG" | head -3
echo "== WebKit 补丁完成 =="
