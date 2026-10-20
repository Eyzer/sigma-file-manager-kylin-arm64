#!/bin/bash
# 依赖版本单一来源：所有脚本 source 本文件，避免各处硬编码漂移
#
# WebKit 2.40.5 是被迫的下限：上游 wry 0.55 的 linux-body 特性打开了
# webkit2gtk/v2_40，cargo 因此在 build 时断言 pkg-config >= 2.40。
# 2.38.6 能编过但编不出应用，已被替换。
export WEBKIT_VER=2.40.5
export GLIB_VER=2.72.4
export SOUP_VER=3.0.7
export SRC_DIR=/tmp/src
export PREFIX=/usr/local
