#!/bin/bash
# 依赖版本单一来源：所有脚本 source 本文件，避免各处硬编码漂移
#
# 上游 wry 0.55 的 linux-body 特性会要求 webkit2gtk >= 2.40，但 WebKit 2.40
# 需要 GCC >= 9.3，buster 只有 8.3（std::is_constant_evaluated、NEON
# vld1q_u8_x4 均不可用）。因此固定 2.38.6，并用 45-patch-wry.sh 把 wry 对
# 2.40 接口的依赖摘掉（PATCH_WRY_238=1）。
export WEBKIT_VER=2.38.6
export GLIB_VER=2.72.4
export SOUP_VER=3.0.7
export SRC_DIR=/tmp/src
export PREFIX=/usr/local
