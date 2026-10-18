#!/bin/bash
# 组装完全自包含的 deb：只依赖 libc 与 GPU 驱动栈，其余全部装进 /opt
set -euxo pipefail

PREFIX=/usr/local
WORK=/work
REPO=${WORK}/src-repo
OUT=/out
PKG=${OUT}/pkg
APPDIR=${PKG}/opt/sigma-file-manager
LIBS=${APPDIR}/lib

rm -rf "${PKG}"
mkdir -p "${APPDIR}/bin" "${LIBS}" "${APPDIR}/libexec" \
         "${PKG}/usr/bin" "${PKG}/usr/share/applications" \
         "${PKG}/usr/share/icons/hicolor/128x128/apps" "${PKG}/DEBIAN"

BIN="${REPO}/src-tauri/target/aarch64-unknown-linux-gnu/release/sigma-file-manager"
test -x "${BIN}"
cp -a "${BIN}" "${APPDIR}/bin/sigma-file-manager"
strip --strip-unneeded "${APPDIR}/bin/sigma-file-manager" || true

# WebKit 独立子进程（WebProcess / NetworkProcess）
WEBKIT_EXEC_SRC=""
for d in ${PREFIX}/libexec/webkit2gtk-4.1 ${PREFIX}/libexec/webkit2gtk-4.0; do
  [ -d "$d" ] && WEBKIT_EXEC_SRC="$d" && break
done
test -n "${WEBKIT_EXEC_SRC}"
mkdir -p "${APPDIR}/libexec/webkit2gtk-4.1"
cp -a "${WEBKIT_EXEC_SRC}/." "${APPDIR}/libexec/webkit2gtk-4.1/"
find "${APPDIR}/libexec" -type f -exec strip --strip-unneeded {} \; 2>/dev/null || true

# ---- 递归收集动态库 ----
is_excluded() {
  case "$(basename "$1")" in
    ld-linux*|libc.so*|libm.so*|libmvec*|libpthread*|libdl*|librt*|libresolv*|libnss_*|libutil*|libanl*|libcrypt.so*)
      return 0 ;;
    libGL.so*|libGLX*|libEGL*|libGLES*|libOpenGL*|libGLdispatch*|libgbm*|libdrm*|libvulkan*)
      return 0 ;;
  esac
  return 1
}

scan_deps() {
  while IFS= read -r f; do
    [ -f "$f" ] || continue
    ldd "$f" 2>/dev/null | awk '{for(i=1;i<=NF;i++) if($i ~ /^\//) print $i}' || true
  done
}

IN=/tmp/scan_in.txt
COL=/tmp/collected.txt
{ echo "${APPDIR}/bin/sigma-file-manager"; find "${APPDIR}/libexec" -type f; } > "${IN}"
: > "${COL}"

for _ in $(seq 1 15); do
  scan_deps < "${IN}" | sort -u > /tmp/deps.txt
  sort -u "${COL}" > /tmp/col.sorted
  comm -23 /tmp/deps.txt /tmp/col.sorted > /tmp/new.txt
  [ -s /tmp/new.txt ] || break
  cat /tmp/new.txt >> "${COL}"
  cp /tmp/new.txt "${IN}"
done

COUNT=0
while IFS= read -r lib; do
  is_excluded "${lib}" && continue
  cp -Lf "${lib}" "${LIBS}/$(basename "${lib}")" 2>/dev/null || true
  COUNT=$((COUNT+1))
done < <(sort -u "${COL}")
echo "自带动态库 ${COUNT} 个"

# ---- 启动器 ----
cat > "${PKG}/usr/bin/sigma-file-manager" <<'LAUNCHER'
#!/bin/sh
APPDIR=/opt/sigma-file-manager
export LD_LIBRARY_PATH="$APPDIR/lib${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"
export WEBKIT_EXEC_PATH="$APPDIR/libexec/webkit2gtk-4.1"
export WEBKIT_DISABLE_COMPOSITING_MODE="${WEBKIT_DISABLE_COMPOSITING_MODE:-1}"
export GDK_BACKEND="${GDK_BACKEND:-x11}"
exec "$APPDIR/bin/sigma-file-manager" "$@"
LAUNCHER
chmod 0755 "${PKG}/usr/bin/sigma-file-manager"

# ---- desktop / 图标 ----
cat > "${PKG}/usr/share/applications/sigma-file-manager.desktop" <<'DESKTOP'
[Desktop Entry]
Type=Application
Name=Sigma File Manager
Name[zh_CN]=Sigma 文件管理器
Comment=Modern file manager
Comment[zh_CN]=现代化文件管理器
Exec=/usr/bin/sigma-file-manager %U
Icon=sigma-file-manager
Terminal=false
Categories=System;FileTools;FileManager;Utility;
MimeType=inode/directory;
StartupNotify=true
StartupWMClass=sigma-file-manager
DESKTOP

ICON_SRC="${REPO}/src-tauri/icons/128x128.png"
[ -f "${ICON_SRC}" ] || ICON_SRC="$(find "${REPO}/src-tauri/icons" -name '128x128*.png' | head -1)"
cp -f "${ICON_SRC}" "${PKG}/usr/share/icons/hicolor/128x128/apps/sigma-file-manager.png"

# ---- control ----
VERSION=$(grep -m1 '"version"' "${REPO}/package.json" | sed 's/[^0-9.]//g')
SIZE_KB=$(du -sk "${PKG}" | cut -f1)
cat > "${PKG}/DEBIAN/control" <<CONTROL
Package: sigma-file-manager
Version: ${VERSION}
Section: utils
Priority: optional
Architecture: arm64
Installed-Size: ${SIZE_KB}
Maintainer: Eyzer <eyzer@qq.com>
Depends: libc6 (>= 2.28), libgl1, libegl1, libgbm1, libdrm2, libx11-6, libxext6, libxrender1, libsm6, libice6
Recommends: fonts-noto-cjk
Description: Sigma File Manager for Kylin V10 SP1 (arm64)
 Modern, self-contained file manager built with Tauri 2.
 WebKitGTK 4.1 runtime and all GTK dependencies are bundled
 inside /opt/sigma-file-manager, so no extra packages are
 required on an offline Kylin V10 SP1 system.
CONTROL

cat > "${PKG}/DEBIAN/postinst" <<'POSTINST'
#!/bin/sh
set -e
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database -q || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -q -t /usr/share/icons/hicolor || true
fi
exit 0
POSTINST
chmod 0755 "${PKG}/DEBIAN/postinst"

mkdir -p "${OUT}/dist"
DEB="${OUT}/dist/SigmaFileManager_${VERSION}_arm64.deb"
dpkg-deb --build --root-owner-group -Zxz "${PKG}" "${DEB}"
ls -lh "${DEB}"
dpkg-deb -I "${DEB}"
echo "== deb 打包完成 =="
