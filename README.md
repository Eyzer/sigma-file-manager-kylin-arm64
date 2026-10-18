# Sigma File Manager — 银河麒麟 V10 SP1 / arm64 离线 deb

把上游 [sigma-file-manager](https://github.com/aleksey-hoffman/sigma-file-manager)（Tauri 2 + Vue）编译成 **自包含 arm64 deb**，目标环境：银河麒麟桌面 V10 SP1（glibc 2.28 / aarch64，纯内网）。

## 为什么需要这个仓库

上游 v2 是 Tauri 2 应用，wry 0.57 硬绑 `webkit2gtk-4.1` + `libsoup3`。麒麟 V10 SP1 官方源只有 `libwebkit2gtk-4.0-37`，没有 4.1，且 glibc 仅 2.28。
所以本仓库做两件事：

1. 在 **Debian 10（glibc 2.28）** 容器里从源码编译 `libsoup 3` + `WebKitGTK 2.38`（提供 4.1 API），使产物 ABI 与麒麟 V10 SP1 对齐；
2. 把这些库连同 GTK 全栈一起打进 deb 的 `/opt/sigma-file-manager/lib`，安装后不依赖任何额外软件包。

## 产物

`SigmaFileManager_<version>_arm64.deb`

| 项 | 值 |
|---|---|
| 架构 | arm64 |
| 硬依赖 | libc6 ≥ 2.28、libgl1/libegl1（Mesa 驱动栈，系统自带） |
| 自带 | WebKitGTK 4.1、libsoup3、GTK3、GLib、Pango、Cairo、HarfBuzz、ICU 等全部运行时 |
| 安装路径 | `/opt/sigma-file-manager`，启动器 `/usr/bin/sigma-file-manager` |

## 内网安装

```bash
sudo dpkg -i SigmaFileManager_2.2.0_arm64.deb
```

完成后应用菜单里出现「Sigma 文件管理器」。若缺中文字体导致方块，装 `fonts-noto-cjk`。

## 已知排查点

- 飞腾/景嘉微等 GPU 上若白屏，启动器已默认 `WEBKIT_DISABLE_COMPOSITING_MODE=1`；仍异常可再试 `LIBGL_ALWAYS_SOFTWARE=1`。
- 文件图标不显示：多为 gdk-pixbuf 加载器缓存与系统版本错配，可在启动器里追加 `GDK_PIXBUF_MODULE_FILE` 指向自带缓存。

## 构建

GitHub Actions：`Build Kylin V10 arm64 deb` → Run workflow。

- `stage=configure`：只校验依赖与 WebKit 配置（约 20 分钟，用来快速试错）
- `stage=full`：完整编译（WebKit 约 3–5 小时 + 应用约 30 分钟）

runner 为 `ubuntu-24.04-arm`（原生 arm64），容器 `debian:10`。
