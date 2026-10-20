#!/bin/bash
# WebKit 2.38 在 gcc 8 下 ArgList.h 使用 jsCast 但没包含定义它的头文件（上游 2.42 才补）。
# 这里前向移植那条 include，避免编译到 JavaScriptCore 才失败。
set -euxo pipefail

WK=/tmp/src/webkitgtk-2.38.6
ARG="$WK/Source/JavaScriptCore/runtime/ArgList.h"

[ -f "$ARG" ] || { echo "找不到 $ARG"; exit 1; }

# 先清理可能存在的错误补丁（历史版本插入过 JSObject.h，会造成循环包含）
sed -i '/#include "JSObject.h"/d' "$ARG"
if grep -q '#include "JSCast.h"' "$ARG"; then
  echo "补丁已存在"
else
  if [ -f "$WK/Source/JavaScriptCore/runtime/JSCast.h" ]; then
    JSCAST_INC="JSCast.h"
  else
    echo "源码中缺少 JSCast.h，无法打补丁"
    exit 1
  fi
  sed -i "s|#include \"CallFrame.h\"|#include \"CallFrame.h\"\n#include \"$JSCAST_INC\"|" "$ARG"
fi

sed -n '20,32p' "$ARG"
grep -c "jsCast" "$ARG"
echo "== WebKit 补丁完成 =="
