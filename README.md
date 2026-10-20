# Sigma File Manager — 银河麒麟 V10 / arm64 离线 deb

把上游 [sigma-file-manager](https://github.com/aleksey-hoffman/sigma-file-manager) v2.2.0（Tauri 2 + Vue）编译成 **自包含 arm64 deb**，目标环境：银河麒麟桌面 V10（SP1 起的 glibc 2.28 / aarch64，纯内网）。

## 下载

**[Releases → v2.2.0-kylin-arm64](https://github.com/Eyzer/sigma-file-manager-kylin-arm64/releases/tag/v2.2.0-kylin-arm64)**

```
SigmaFileManager_2.2.0_arm64.deb   57 MB（安装后 207 MB）
```

## 内网安装

```bash
sudo dpkg -i SigmaFileManager_2.2.0_arm64.deb
```

装完应用菜单里出现「Sigma 文件管理器」，或命令行执行 `sigma-file-manager`。
不需要联网、不需要补装依赖。中文界面若显示方块，装 `fonts-noto-cjk`。

## 包内容

| 项 | 值 |
|---|---|
| 架构 | arm64 |
| 硬依赖 | `libc6 (>= 2.28)`, `libgl1`, `libegl1`, `libgbm1`, `libdrm2`, `libx11-6`, `libxext6`, `libxrender1`, `libsm6`, `libice6` |
| 自带运行时 | 92 个 .so：WebKitGTK 2.38.6（4.1 API）、libsoup3、glib 2.72、GTK3、Pango、Cairo、HarfBuzz、ICU、WebP、OpenJPEG 等 |
| 安装路径 | `/opt/sigma-file-manager`（`bin` / `lib` / `libexec` / `share`） |
| 启动器 | `/usr/bin/sigma-file-manager`（设 `LD_LIBRARY_PATH`、`WEBKIT_EXEC_PATH`、`WEBKIT_INJECTED_BUNDLE_PATH`、`GSETTINGS_SCHEMA_DIR`） |

GPU 相关库（`libGL`/`libEGL`/`libgbm`/`libdrm`/`libvulkan`）**故意不打包**，必须用目标机的驱动栈。

## 为什么要这么绕

三件事卡在一起：

1. 上游 Tauri 2 的 wry 硬绑 `webkit2gtk-4.1` + `libsoup3`，麒麟 V10 SP1 官方源只有 `libwebkit2gtk-4.0-37`，soname 不同不能替代；
2. `libsoup3` 要求 `glib >= 2.69`，麒麟 SP1 只有 2.56；
3. Tauri 2 的 `tauri` 与 `wry` 都声明 `webkit2gtk/v2_40`，而 WebKit 2.40 的 CMake 硬性要求 `GCC >= 9.3`（用到 `std::is_constant_evaluated` 与 NEON `vld1q_u8_x4`），Debian 10 / 麒麟 SP1 只有 GCC 8.3，buster-backports 也没有更高版本。

所以：Debian 10 容器（glibc 2.28 锚点）里自编 `glib 2.72` + `libsoup 3.0.7` + `WebKitGTK 2.38.6`，应用侧对 wry 打两处兼容补丁（见下）。

## 补丁清单

| 脚本 | 作用 |
|---|---|
| `scripts/15-build-glib.sh` | 自编 glib 2.72.4（libsoup3 的下限） |
| `scripts/20-build-libsoup3.sh` | 自编 libsoup 3.0.7，用编译器包装器压掉 gcc8 对 skip 路径的 `-Wnonnull` 误报 |
| `scripts/25-patch-webkit.sh` | 前移 WebKit 2.42 的 `ArgList.h` 补丁（2.38 缺 `JSCast.h` 引用），并把 GCC 9.3 门槛放宽到 8.0 |
| `scripts/30-build-webkit.sh` | 编 WebKitGTK 2.38.6，关 GStreamer/拼写检查/沙箱/AVIF/JXL 压编译时间 |
| `scripts/40-build-app.sh` | Node 24 + Rust stable 编 Tauri 应用；把 `webkit2gtk-4.1.pc` 的 `Version:` 抬到 2.40.5 以过 cargo 的版本断言 |
| `scripts/45-patch-wry.sh` | 摘掉 wry 对两个 2.40 新符号的依赖：`http_body()`（自定义协议 POST body）与 `all_cookies()`（返回空集合） |
| `scripts/50-package-deb.sh` | 递归 `ldd` 收全部 .so、打入 WebKit 子进程与注入包、组 control/postinst、启动器 |

补丁代价：**自定义协议的 POST 请求体读不到、cookie 读不到**。文件管理器的浏览 / 打开 / 复制 / 预览主流程不受影响。

## 构建

GitHub Actions → `Build Kylin V10 arm64 deb` → Run workflow：

| stage | 内容 | 耗时 |
|---|---|---|
| `configure` | 只校验依赖与 WebKit cmake 配置 | ≈5 分钟 |
| `jsc` | 只编 JavaScriptCore，验证补丁与编译器可行性 | ≈20 分钟 |
| `full` | glib + libsoup + WebKit 全量 + 应用 + deb | ≈1.5 小时 |

另有 `Build app deb (reuse webkit artifact)`：直接复用某次 `full` 的 WebKit sysroot 产物只编应用（≈11 分钟），改应用层补丁时用它。
以及 `Publish deb to Release`：把指定 run 的 deb 发布到 Releases。

runner 为 `ubuntu-24.04-arm`（原生 arm64），容器 `debian:10`，全部版本号集中在 `scripts/versions.sh`。

## 已知排查点

- 飞腾 / 景嘉微等 GPU 上白屏：启动器默认已设 `WEBKIT_DISABLE_COMPOSITING_MODE=1`，仍异常可再 `LIBGL_ALWAYS_SOFTWARE=1 sigma-file-manager`。
- 文件图标缺失：多为 gdk-pixbuf 加载器与系统版本错配，可用系统自带加载器（`GDK_PIXBUF_MODULE_FILE=/usr/lib/aarch64-linux-gnu/gdk-pixbuf-2.0/2.10.0/loaders.cache`）验证。
- 起不来时先看缺什么：`LD_LIBRARY_PATH=/opt/sigma-file-manager/lib ldd /opt/sigma-file-manager/bin/sigma-file-manager | grep "not found"`。
