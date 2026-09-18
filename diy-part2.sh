#!/bin/bash
#
# https://github.com/P3TERX/Actions-OpenWrt
# File name: diy-part2.sh
# Description: OpenWrt DIY script part 2 (After Update feeds)
#
# Copyright (c) 2019-2024 P3TERX <https://p3terx.com>
#
# This is free software, licensed under the MIT License.
# See /LICENSE for more information.
#


# 修复 helloworld/dev 新版 GN 在 Ubuntu 22.04 的 host 编译兼容问题
# GN Linux 默认使用 clang++；Ubuntu 22.04 runner 的 clang 14 会在新版 GN 的 std::ranges 处失败。
# runner 默认 g++ 是 11.4，也不足以稳定编译当前要求 C++23 的 GN。
# 仅让 GN 自身改用 gcc-12/g++-12，不全局修改 OpenWrt 的 CC/CXX，避免影响其他包和目标工具链。
GN_MAKEFILE="feeds/helloworld/gn/Makefile"
if [ -f "$GN_MAKEFILE" ]; then
    python3 - "$GN_MAKEFILE" <<'PY_GN'
from pathlib import Path
import re
import sys

path = Path(sys.argv[1])
text = path.read_text()

# 给 Host/Configure 中调用 build/gen.py 的命令局部注入 GCC 工具链。
# 用正则而不是写死整段 Makefile，降低 helloworld 轻微改版导致补丁失效的概率。
pattern = r'^(\s*)(?:CC=[^ ]+\s+CXX=[^ ]+\s+AR=[^ ]+\s+)?(\$\(PYTHON\)[^\n]*build/gen\.py[^\n]*)$'
replacement = r'\1CC=gcc-12 CXX=g++-12 AR=ar \2' 
new_text, count = re.subn(pattern, replacement, text, count=1, flags=re.MULTILINE)

if count == 0:
    if 'CC=gcc-12 CXX=g++-12 AR=ar' in text and 'build/gen.py' in text:
        print('GN Makefile already patched for gcc-12/g++-12, skip.')
        raise SystemExit(0)
    raise SystemExit('ERROR: 未找到 GN Host/Configure 中的 build/gen.py 调用，请检查 feeds/helloworld/gn/Makefile')

path.write_text(new_text)
print('Patched GN Host/Configure to use gcc-12/g++-12.')
PY_GN

    echo "===== GN Host/Configure after patch ====="
    grep -n -A6 -B2 'build/gen.py' "$GN_MAKEFILE" || true
else
    echo "ERROR: $GN_MAKEFILE 不存在"
    exit 1
fi

# Modify default IP
#sed -i 's/192.168.1.1/192.168.50.5/g' package/base-files/files/bin/config_generate

# Modify default theme
#sed -i 's/luci-theme-bootstrap/luci-theme-argon/g' feeds/luci/collections/luci/Makefile

# Modify hostname
#sed -i 's/OpenWrt/P3TERX-Router/g' package/base-files/files/bin/config_generate

# 移除 openwrt feeds 自带的核心包
rm -rf feeds/packages/net/{xray-core,xray-plugin,v2ray-core,v2ray-plugin,v2ray-geodata,sing-box,hysteria,naiveproxy,shadowsocks-rust,shadow-tls,tuic-client,microsocks,chinadns-ng,dns2socks,ipt2socks}
rm -rf feeds/luci/applications/{luci-app-passwall,luci-app-ssr-plus}
cp -r feeds/passwall_packages/{xray-core,xray-plugin,v2ray-plugin,v2ray-geodata,sing-box,hysteria,naiveproxy,shadowsocks-rust,shadow-tls,tuic-client,microsocks,chinadns-ng,dns2socks,ipt2socks} feeds/packages/net/
cp -r feeds/helloworld/v2ray-core feeds/packages/net/
cp -r feeds/passwall/luci-app-passwall feeds/luci/applications
cp -r feeds/helloworld/luci-app-ssr-plus feeds/luci/applications

# 修改golang源码以编译xray26.9.9+版本
rm -rf feeds/packages/lang/golang
git clone https://github.com/sbwml/packages_lang_golang -b 27.x feeds/packages/lang/golang

# 修改frp版本为官网最新v0.68.1 https://github.com/fatedier/frp 格式：https://codeload.github.com/fatedier/frp/tar.gz/v${PKG_VERSION}?
rm -rf feeds/packages/net/frp
wget https://github.com/coolsnowwolf/packages/archive/0f7be9fc93d68986c179829d8199824d3183eb60.zip -O OldPackages.zip
unzip OldPackages.zip
cp -r packages-0f7be9fc93d68986c179829d8199824d3183eb60/net/frp feeds/packages/net/
rm -rf OldPackages.zip packages-0f7be9fc93d68986c179829d8199824d3183eb60
sed -i 's/PKG_VERSION:=0.53.2/PKG_VERSION:=0.68.1/' feeds/packages/net/frp/Makefile
sed -i 's/PKG_HASH:=ff2a4f04e7732bc77730304e48f97fdd062be2b142ae34c518ab9b9d7a3b32ec/PKG_HASH:=44ed7107bf35e4f68dc0e77cd5805102effa5301528b89ee5ab0ab379088edc6/' feeds/packages/net/frp/Makefile

# 升级zerotier到官方最新版本1.14.2
sed -i 's/PKG_VERSION:=1.14.1/PKG_VERSION:=1.14.2/' feeds/packages/net/zerotier/Makefile
sed -i 's/PKG_HASH:=4f9f40b27c5a78389ed3f3216c850921f6298749e5819e9f2edabb2672ce9ca0/PKG_HASH:=c2f64339fccf5148a7af089b896678d655fbfccac52ddce7714314a59d7bddbb/' feeds/packages/net/zerotier/Makefile
