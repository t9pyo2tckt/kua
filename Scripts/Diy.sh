#!/bin/bash
# AutoBuild Module by Hyy2001 <https://github.com/Hyy2001X/AutoBuild-Actions-BETA>
# AutoBuild DiyScript
# Git稀疏克隆，只克隆指定目录到本地
# 参数1是分支名, 参数2是仓库地址, 参数3是子目录，同一个仓库下载多个文件夹直接在后面跟文件名或路径，空格分开
function git_sparse_clone() {
  branch="$1" repourl="$2" && shift 2
  git clone --depth=1 -b $branch --single-branch --filter=blob:none --sparse $repourl
  repodir=$(echo $repourl | awk -F '/' '{print $(NF)}')
  cd $repodir && git sparse-checkout set $@
  mv -f $@ ../
  cd .. && rm -rf $repodir
}

echo "开始 DIY 配置..."
echo "===================="
# golang 26.x
rm -rf feeds/packages/lang/golang
git clone --depth=1 https://github.com/sbwml/packages_lang_golang -b 26.x feeds/packages/lang/golang

# 移除 openwrt feeds 自带的核心库
rm -rf feeds/packages/net/{xray-core,v2ray-geodata,sing-box,chinadns-ng,dns2socks,hysteria,ipt2socks,microsocks,naiveproxy,shadowsocks-rust,shadowsocksr-libev,simple-obfs,tcping,v2ray-plugin,xray-plugin,geoview,shadow-tls}
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall-packages package/passwall-packages

# 移除 openwrt feeds 过时的luci版本
rm -rf feeds/luci/applications/luci-app-passwall
git clone --depth=1 https://github.com/Openwrt-Passwall/openwrt-passwall package/openwrt-passwall

# 集客 AC 控制器
rm -rf package/luci-app-gecoosac
git clone --depth=1 https://github.com/laipeng668/luci-app-gecoosac package/luci-app-gecoosac

# Harbor File
rm -rf package/luci-app-harbor-file
git clone --depth=1 https://github.com/destan19/luci-app-harbor-file package/luci-app-harbor-file

# luci-app-openclash
rm -rf feeds/luci/applications/luci-app-openclash
git clone --depth=1 https://github.com/vernesong/OpenClash  package/OpenClash

# OpenClash 主动探测补丁:让 url-test/fallback/load-balance/smart 组默认 lazy:false
# 内核启动即主动测速并按 interval 定时测速,自动优选最低延迟节点,无需打开面板手动点闪电图标
cp -f "$GITHUB_WORKSPACE/Scripts/openclash-patch/groups-config.lua" "package/OpenClash/luci-app-openclash/luasrc/model/cbi/openclash/groups-config.lua"
cp -f "$GITHUB_WORKSPACE/Scripts/openclash-patch/yml_groups_set.sh" "package/OpenClash/luci-app-openclash/root/usr/share/openclash/yml_groups_set.sh"

# RUN插件小工具
rm -rf package/luci-app-run
git clone --depth=1 https://github.com/wukongdaily/luci-app-run package/luci-app-run

# luci-app-autoupdate 在线更新插件
rm -rf feeds/luci/themes/luci-theme-argon
rm -rf feeds/luci/applications/luci-app-adguardhome
git clone --depth=1 https://github.com/t9pyo2tckt/luci-app-adguardhome package/luci-app-AAAAA
git clone --depth=1 https://github.com/jerrykuku/luci-theme-argon package/luci-theme-argon

# # 下载luci-app-quickstart安装包
# git_sparse_clone main https://github.com/linkease/nas-packages-luci luci/luci-app-quickstart
# mv luci-app-quickstart package/luci-app-quickstart

# # 下载quickstart后端包
# git_sparse_clone master https://github.com/linkease/nas-packages network/services/quickstart
# mv quickstart package/quickstart

# sed -i 's/+luci-app-store//' ./package/luci-app-quickstart/Makefile

# # store
# git clone --depth=1 https://github.com/linkease/istore-ui package/luci-app-store-ui
# git clone --depth=1 https://github.com/linkease/istore package/luci-app-store

./scripts/feeds update -a
./scripts/feeds install -a


# 写入插件配置到 .config（必须在 feeds install 之后）
echo "写入插件配置到 .config..."
cat >> .config << 'EOF'

EOF

# ttyd 自动登录 root
sed -i 's|/bin/login|/bin/login -f root|g' feeds/packages/utils/ttyd/files/ttyd.config

# openwrt 地址
sed -i "s/192.168.1.1/${OP_IP}/" package/base-files/files/bin/config_generate

######################
# 1. 根据 target_arch 匹配 AdGuard Home 架构
case "${target_arch}" in
    x86_64)
        ADG_ARCH="_linux_amd64"
        OC_ARCH="amd64-v1"
        ;;
    armv7 | armv7l)
        ADG_ARCH="_linux_armv7"
        OC_ARCH="armv7"
        ;;
    *)
        echo "❌ 不支持的架构: ${{ matrix.target_arch }}"
        exit 1
        ;;
esac

# 内置AdGuardHome内核
ADG_VERSION="v0.107.78";ADG_URL="https://github.com/AdguardTeam/AdGuardHome/releases/download/${ADG_VERSION}/AdGuardHome${ADG_ARCH}.tar.gz";mkdir -p /tmp/agh && wget -qO- $ADG_URL | tar xz -C /tmp/agh --strip-components=1;mkdir -p files/usr/bin;mv /tmp/agh/AdGuardHome/AdGuardHome files/usr/bin/;chmod 0755 files/usr/bin/AdGuardHome;rm -rf /tmp/agh

# 内置X86-clash内核
OC_URL="https://raw.githubusercontent.com/vernesong/OpenClash/core/master/meta/clash-linux-${OC_ARCH}.tar.gz";mkdir -p files/etc/openclash/core;wget -qO- $OC_URL|tar xOvz>files/etc/openclash/core/clash_meta;chmod +x files/etc/openclash/core/clash*


# 1. 统一根据仓库名称，确定目标配置文件的路径
if [[ "${REPO_NAME}" == "immortalwrt" ]]; then
    ZZZ="package/emortal/default-settings/files/99-default-settings"
elif [[ "${REPO_NAME}" == "lede" ]]; then
    ZZZ="package/lean/default-settings/files/zzz-default-settings"
else
    echo "警告: 未知的 REPO_NAME (${REPO_NAME})，跳过默认配置修改"
    ZZZ=""
fi

# 2. 如果路径有效，先统一执行替换操作
if [[ -n "${ZZZ}" ]]; then
    # 替换掉原有的 exit 0 为注释
    sed -i '/.*exit 0*/c\# 自定义配置' "${ZZZ}"
fi

# 3. 分别针对不同仓库，写入各自特有的配置内容，主路由注释，旁路由按需取消注释
if [[ "${REPO_NAME}" == "immortalwrt" ]]; then
    cat >> "${ZZZ}" <<-EOF
# 这里写入 immortalwrt 仓库特有的配置内容
# /etc/config/network
#uci set network.lan.gateway='192.168.9.1' # 网关
uci add_list network.lan.dns='${OP_IP}' # DNS(多个DNS要用空格分开)
uci del network.lan.ip6assign # IPv6 前缀分配长度

# 添加wan口拨号信息
uci set network.wan.proto='pppoe'
uci set network.wan.username='039605681396'
uci set network.wan.password='123456'
uci set network.wan.ipv6='auto'
uci set network.wan.norelease='1'
uci set network.wan.macaddr='06:2A:58:85:66:66'
uci add_list network.@device[0].ports='eth0'
uci add_list network.@device[0].ports='eth2'
uci add_list network.@device[0].ports='eth3'
uci add_list network.@device[0].ports='eth4'
uci add_list network.@device[0].ports='eth5'
uci commit network

# /etc/config/dhcp
uci set dhcp.lan.leasetime='168h'
uci del dhcp.lan.ignore #忽略此接口 
#uci set dhcp.lan.dynamicdhcp='0' # 动态 DHCP
uci del dhcp.lan.ra # RA 服务

# DHCP/DNS
#uci del dhcp.@dnsmasq[0].authoritative # 唯一授权
#uci del dhcp.@dnsmasq[0].dns_redirect # DNS 重定向
uci set dhcp.@dnsmasq[0].port='1166' # DNS端口1166
uci add_list dhcp.lan.dhcp_option='6,${OP_IP}'
uci set dhcp.@dnsmasq[0].sequential_ip='1'

uci add dhcp host
uci set dhcp.@host[-1].mac='00:88:01:41:28:40'
uci set dhcp.@host[-1].ip='192.168.9.70'
uci set dhcp.@host[-1].name='static_01'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='F8:6F:B0:49:E9:8C'
uci set dhcp.@host[-1].ip='192.168.9.71'
uci set dhcp.@host[-1].name='static_02'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='64:6E:97:D1:19:86'
uci set dhcp.@host[-1].ip='192.168.9.72'
uci set dhcp.@host[-1].name='static_03'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='64:6E:97:D1:18:B8'
uci set dhcp.@host[-1].ip='192.168.9.73'
uci set dhcp.@host[-1].name='static_04'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='28:D1:27:90:88:89'
uci set dhcp.@host[-1].ip='192.168.9.80'
uci set dhcp.@host[-1].name='static_05'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='30:B2:37:9F:6C:47'
uci set dhcp.@host[-1].ip='192.168.9.81'
uci set dhcp.@host[-1].name='static_06'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='32:F9:58:BF:30:13'
uci set dhcp.@host[-1].ip='192.168.9.82'
uci set dhcp.@host[-1].name='static_07'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='34:FA:1C:D3:2F:7B'
uci set dhcp.@host[-1].ip='192.168.9.83'
uci set dhcp.@host[-1].name='static_08'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='3C:0B:59:20:BA:BB'
uci set dhcp.@host[-1].ip='192.168.9.84'
uci set dhcp.@host[-1].name='static_09'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='3C:0B:59:20:BC:E4'
uci set dhcp.@host[-1].ip='192.168.9.85'
uci set dhcp.@host[-1].name='static_10'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='3C:BC:D0:BA:19:40'
uci set dhcp.@host[-1].ip='192.168.9.86'
uci set dhcp.@host[-1].name='static_11'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='50:FE:39:F2:1F:46'
uci set dhcp.@host[-1].ip='192.168.9.87'
uci set dhcp.@host[-1].name='static_12'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='54:2B:76:1D:20:D0'
uci set dhcp.@host[-1].ip='192.168.9.88'
uci set dhcp.@host[-1].name='static_13'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='58:B6:23:97:02:52'
uci set dhcp.@host[-1].ip='192.168.9.89'
uci set dhcp.@host[-1].name='static_14'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='5C:E5:0C:39:BA:2C'
uci set dhcp.@host[-1].ip='192.168.9.90'
uci set dhcp.@host[-1].name='static_15'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='74:39:89:88:83:20'
uci set dhcp.@host[-1].ip='192.168.9.91'
uci set dhcp.@host[-1].name='static_16'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='88:51:F2:A0:7A:F3'
uci set dhcp.@host[-1].ip='192.168.9.92'
uci set dhcp.@host[-1].name='static_17'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='BC:35:1E:EC:18:49'
uci set dhcp.@host[-1].ip='192.168.9.93'
uci set dhcp.@host[-1].name='static_18'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='CA:CE:C6:43:B6:B0'
uci set dhcp.@host[-1].ip='192.168.9.94'
uci set dhcp.@host[-1].name='static_19'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='CC:15:31:7A:64:30'
uci set dhcp.@host[-1].ip='192.168.9.95'
uci set dhcp.@host[-1].name='static_20'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='D4:27:87:FA:6D:E0'
uci set dhcp.@host[-1].ip='192.168.9.96'
uci set dhcp.@host[-1].name='static_21'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='D4:50:EE:98:2B:D0'
uci set dhcp.@host[-1].ip='192.168.9.97'
uci set dhcp.@host[-1].name='static_22'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='F8:E4:E3:7B:B3:BC'
uci set dhcp.@host[-1].ip='192.168.9.98'
uci set dhcp.@host[-1].name='static_23'
uci set dhcp.@host[-1].leasetime='infinite'
uci commit dhcp

# /etc/config/luci
uci set luci.main.lang='zh_cn' # 调整语言为简体中文
uci set luci.diag.ping=www.baidu.com # 调整网络诊断地址到www.baidu.com
uci set luci.diag.route=www.baidu.com # 调整网络诊断地址到www.baidu.com
uci set luci.diag.dns=www.baidu.com # 调整网络诊断地址到www.baidu.com
uci commit luci

# /etc/config/dropbear
uci set dropbear.main.DirectInterface='lan'
uci set dropbear.main.Port='2222' # SSH端口设置为'2222'
uci set dropbear.main.PasswordAuth='on'
uci set dropbear.main.RootPasswordAuth='on'
uci commit dropbear

# 设置防火墙-旁路由模式
uci set firewall.@defaults[0].synflood_protect='0' # 禁用 SYN-flood 防御
uci set firewall.@defaults[0].fullcone='0' # 禁用 FullCone NAT
uci set firewall.@defaults[0].fullcone6='0' # 禁用 FullCone NAT6
uci set firewall.@defaults[0].input='ACCEPT' # 入站数据接受
uci set firewall.@defaults[0].forward='ACCEPT' # 转发数据接受

# /etc/config/firewall
uci set firewall.@zone[0].masq='1' # 启用LAN口 IP 动态伪装
uci set firewall.@zone[0].input='ACCEPT' # 防火墙输入数据
uci set firewall.@zone[0].forward='ACCEPT' # 防火墙转发数据
uci set firewall.@zone[1].input='ACCEPT' # 防火墙输入数据
uci set firewall.@zone[1].forward='ACCEPT' # 防火墙转发数据
uci commit firewall

grep -q 'openwrt_menu_zh' /etc/profile || echo '[ -x /usr/bin/openwrt_menu_zh.sh ] && [ -t 0 ] && /usr/bin/openwrt_menu_zh.sh' >> /etc/profile
grep -q "alias menu" /etc/profile || echo "alias menu='/usr/bin/openwrt_menu_zh.sh'" >> /etc/profile
chmod +x /usr/share/AdGuardHome/addhost.sh
chmod +x /root/ipv6_notify.sh
(crontab -l 2>/dev/null; echo "0 */12 * * * /root/ipv6_notify.sh") | crontab -

EOF
elif [[ "${REPO_NAME}" == "lede" ]]; then
    cat >> "${ZZZ}" <<-EOF
# 这里写入 LEDE 仓库特有的配置内容
# /etc/config/network
#uci set network.lan.gateway='192.168.9.1' # 网关
uci add_list network.lan.dns='${OP_IP}' # DNS(多个DNS要用空格分开)
uci del network.lan.ip6assign # IPv6 前缀分配长度

# 添加wan口拨号信息
uci set network.wan.proto='pppoe'
uci set network.wan.username='039605681396'
uci set network.wan.password='123456'
uci set network.wan.ipv6='auto'
uci set network.wan.norelease='1'
uci set network.wan.macaddr='06:2A:58:85:66:66'
uci add_list network.@device[0].ports='eth0'
uci add_list network.@device[0].ports='eth2'
uci add_list network.@device[0].ports='eth3'
uci add_list network.@device[0].ports='eth4'
uci add_list network.@device[0].ports='eth5'
uci commit network

# /etc/config/dhcp
uci set dhcp.lan.leasetime='168h'
uci del dhcp.lan.ignore # 忽略此接口
#uci set dhcp.lan.dynamicdhcp='0' # 动态 DHCP
#uci set dhcp.lan.dhcpv4='disabled' # DHCPv4 服务
uci del dhcp.lan.ra # RA 服务
uci del dhcp.lan.dhcpv6 # DHCPv6 服务

# DHCP/DNS
#uci del dhcp.@dnsmasq[0].dns_redirect # DNS 重定向
uci set dhcp.@dnsmasq[0].port='1166' # DNS端口1166
uci add_list dhcp.lan.dhcp_option='6,${OP_IP}'
uci set dhcp.@dnsmasq[0].sequential_ip='1'

uci add dhcp host
uci set dhcp.@host[-1].mac='00:88:01:41:28:40'
uci set dhcp.@host[-1].ip='192.168.9.70'
uci set dhcp.@host[-1].name='static_01'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='F8:6F:B0:49:E9:8C'
uci set dhcp.@host[-1].ip='192.168.9.71'
uci set dhcp.@host[-1].name='static_02'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='64:6E:97:D1:19:86'
uci set dhcp.@host[-1].ip='192.168.9.72'
uci set dhcp.@host[-1].name='static_03'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='64:6E:97:D1:18:B8'
uci set dhcp.@host[-1].ip='192.168.9.73'
uci set dhcp.@host[-1].name='static_04'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='28:D1:27:90:88:89'
uci set dhcp.@host[-1].ip='192.168.9.80'
uci set dhcp.@host[-1].name='static_05'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='30:B2:37:9F:6C:47'
uci set dhcp.@host[-1].ip='192.168.9.81'
uci set dhcp.@host[-1].name='static_06'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='32:F9:58:BF:30:13'
uci set dhcp.@host[-1].ip='192.168.9.82'
uci set dhcp.@host[-1].name='static_07'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='34:FA:1C:D3:2F:7B'
uci set dhcp.@host[-1].ip='192.168.9.83'
uci set dhcp.@host[-1].name='static_08'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='3C:0B:59:20:BA:BB'
uci set dhcp.@host[-1].ip='192.168.9.84'
uci set dhcp.@host[-1].name='static_09'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='3C:0B:59:20:BC:E4'
uci set dhcp.@host[-1].ip='192.168.9.85'
uci set dhcp.@host[-1].name='static_10'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='3C:BC:D0:BA:19:40'
uci set dhcp.@host[-1].ip='192.168.9.86'
uci set dhcp.@host[-1].name='static_11'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='50:FE:39:F2:1F:46'
uci set dhcp.@host[-1].ip='192.168.9.87'
uci set dhcp.@host[-1].name='static_12'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='54:2B:76:1D:20:D0'
uci set dhcp.@host[-1].ip='192.168.9.88'
uci set dhcp.@host[-1].name='static_13'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='58:B6:23:97:02:52'
uci set dhcp.@host[-1].ip='192.168.9.89'
uci set dhcp.@host[-1].name='static_14'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='5C:E5:0C:39:BA:2C'
uci set dhcp.@host[-1].ip='192.168.9.90'
uci set dhcp.@host[-1].name='static_15'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='74:39:89:88:83:20'
uci set dhcp.@host[-1].ip='192.168.9.91'
uci set dhcp.@host[-1].name='static_16'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='88:51:F2:A0:7A:F3'
uci set dhcp.@host[-1].ip='192.168.9.92'
uci set dhcp.@host[-1].name='static_17'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='BC:35:1E:EC:18:49'
uci set dhcp.@host[-1].ip='192.168.9.93'
uci set dhcp.@host[-1].name='static_18'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='CA:CE:C6:43:B6:B0'
uci set dhcp.@host[-1].ip='192.168.9.94'
uci set dhcp.@host[-1].name='static_19'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='CC:15:31:7A:64:30'
uci set dhcp.@host[-1].ip='192.168.9.95'
uci set dhcp.@host[-1].name='static_20'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='D4:27:87:FA:6D:E0'
uci set dhcp.@host[-1].ip='192.168.9.96'
uci set dhcp.@host[-1].name='static_21'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='D4:50:EE:98:2B:D0'
uci set dhcp.@host[-1].ip='192.168.9.97'
uci set dhcp.@host[-1].name='static_22'
uci set dhcp.@host[-1].leasetime='infinite'
uci add dhcp host
uci set dhcp.@host[-1].mac='F8:E4:E3:7B:B3:BC'
uci set dhcp.@host[-1].ip='192.168.9.98'
uci set dhcp.@host[-1].name='static_23'
uci set dhcp.@host[-1].leasetime='infinite'
uci commit dhcp

# /etc/config/luci
uci set luci.main.lang='zh_cn' # 调整语言为简体中文
uci set luci.diag.ping=www.baidu.com # 调整网络诊断地址到www.baidu.com
uci set luci.diag.route=www.baidu.com # 调整网络诊断地址到www.baidu.com
uci set luci.diag.dns=www.baidu.com # 调整网络诊断地址到www.baidu.com
uci commit luci

# /etc/config/dropbear
uci set dropbear.@dropbear[0].Port='2222' # SSH端口设置为'2222'
uci set dropbear.@dropbear[0].PasswordAuth='on'
uci set dropbear.@dropbear[0].RootPasswordAuth='on'
uci commit dropbear

# 设置防火墙-旁路由模式
uci set firewall.@defaults[0].synflood_protect='0' # 禁用 SYN-flood 防御
uci set firewall.@defaults[0].fullcone='0' # 禁用 FullCone NAT
uci set firewall.@defaults[0].fullcone6='0' # 禁用 FullCone NAT6
uci set firewall.@defaults[0].input='ACCEPT' # 入站数据接受
uci set firewall.@defaults[0].forward='ACCEPT' # 转发数据接受

# /etc/config/firewall
uci set firewall.@zone[0].masq='1' # 启用LAN口 IP 动态伪装
uci set firewall.@zone[0].input='ACCEPT' # 防火墙输入数据
uci set firewall.@zone[0].forward='ACCEPT' # 防火墙转发数据
uci set firewall.@zone[1].input='ACCEPT' # 防火墙输入数据
uci set firewall.@zone[1].forward='ACCEPT' # 防火墙转发数据
uci set firewall.cfg01e63d.tcpcca='bbr'
uci commit firewall

grep -q 'openwrt_menu_zh' /etc/profile || echo '[ -x /usr/bin/openwrt_menu_zh.sh ] && [ -t 0 ] && /usr/bin/openwrt_menu_zh.sh' >> /etc/profile
grep -q "alias menu" /etc/profile || echo "alias menu='/usr/bin/openwrt_menu_zh.sh'" >> /etc/profile
chmod +x /usr/share/AdGuardHome/addhost.sh
chmod +x /root/ipv6_notify.sh
(crontab -l 2>/dev/null; echo "0 */12 * * * /root/ipv6_notify.sh") | crontab -

EOF
fi

echo "结束 DIY 配置..."
echo "===================="

Firmware_Diy_1() {
    echo "[Firmware_Diy_1] 开始..."
    # 定义工作目录和配置文件路径
    WORK="${GITHUB_WORKSPACE}/openwrt"
    CONFIG_TEMP="${GITHUB_WORKSPACE}/openwrt/.config"
    # 切换到工作目录
    cd "${WORK}"
    # 根据源码仓库类型提取并输出内核信息
    # 修改点：将 ${{ env.REPO_NAME }} 改为标准的 Shell 变量 ${REPO_NAME}
    if [[ "${REPO_NAME}" == "immortalwrt" ]]; then
        # 1. 从 ImmortalWrt 的 Makefile 中提取内核版本
        DEVICE_TARGET="$(awk -F '[=_]' '/^CONFIG_TARGET_[^_]+=y/ {print $3; exit}' .config)"
        DEVICE_SUBTARGET="$(awk -F '[=_]' '/^CONFIG_TARGET_[^_]+_[^_]+=y/ {print $4; exit}' .config)"
        echo "DEVICE_TARGET=$DEVICE_TARGET" >> $GITHUB_ENV
        echo "DEVICE_SUBTARGET=$DEVICE_SUBTARGET" >> $GITHUB_ENV
        # 2. 写入环境变量并输出内核信息
        echo " 当前源码: ImmortalWrt"
    elif [[ "${REPO_NAME}" == "lede" ]]; then
        # 1. 从 LEDE 的 Makefile 中提取内核版本
        DEVICE_TARGET="$(awk -F '[=_]' '/^CONFIG_TARGET_[^_]+=y/ {print $3; exit}' .config)"
        DEVICE_SUBTARGET="$(awk -F '[=_]' '/^CONFIG_TARGET_[^_]+_[^_]+=y/ {print $4; exit}' .config)"
        echo "DEVICE_TARGET=$DEVICE_TARGET" >> $GITHUB_ENV
        echo "DEVICE_SUBTARGET=$DEVICE_SUBTARGET" >> $GITHUB_ENV
        # 设置密码为空（安装固件时无需密码登陆，然后自己修改想要的密码）
        sed -i 's@.*CYXluq4wUazHjmCDBCqXF*@#&@g' package/lean/default-settings/files/zzz-default-settings
        # 2. 写入环境变量并输出内核信息
        echo " 当前源码: LEDE"
    fi
    # 生成 luci-app-autoupdate 元数据（仅 x86_64）
    if [[ "${target_arch}" == "x86_64" ]]; then
        COMPILE_DATE="$(date +'%s')"
        AUTOUPDATE_TAG="Update-${REPO_NAME}"
        AUTOUPDATE_SOURCE="${REPO_NAME}"
        AUTOUPDATE_EDITION="${REPO_NAME}-x86"
        TARGET_PROFILE="${DEVICE_TARGET}-${DEVICE_SUBTARGET}"
        CURRENT_FIRMWARE="${AUTOUPDATE_SOURCE}-${TARGET_PROFILE}-${COMPILE_DATE}"
        metadata_path="package/base-files/files/etc/openwrt_update"
        mkdir -p "$(dirname "$metadata_path")"
        cat > "$metadata_path" <<EOF
GITHUB_LINK="https://github.com/${GITHUB_REPOSITORY}"
GITHUB_PROXY=""
RELEASE_DOWNLOAD="https://github.com/${GITHUB_REPOSITORY}/releases/download/${AUTOUPDATE_TAG}"
SOURCE="${AUTOUPDATE_SOURCE}"
LUCI_EDITION="${AUTOUPDATE_EDITION}"
FIRMWARE_VERSION="${CURRENT_FIRMWARE}"
TARGET_BOARD="x86"
DEVICE_MODEL="${TARGET_PROFILE}"
FIRMWARE_SUFFIX=".img.gz"
EOF
        chmod 0755 "$metadata_path"
        # 通过 uci-defaults 脚本写入 UCI 配置，避免与插件自带的 /etc/config/autoupdate 文件冲突
        # 这样 LuCI 界面打开即显示正确值，点"保存并应用"也不会把默认值覆盖进 /etc/openwrt_update
        uci_defaults_path="package/base-files/files/etc/uci-defaults/99-autoupdate"
        mkdir -p "$(dirname "$uci_defaults_path")"
        cat > "$uci_defaults_path" <<EOF
#!/bin/sh
uci set autoupdate.@login[0].github='https://github.com/${GITHUB_REPOSITORY}'
uci del autoupdate.@login[0].github_proxy
uci set autoupdate.@login[0].release_download='https://github.com/${GITHUB_REPOSITORY}/releases/download/${AUTOUPDATE_TAG}'
uci set autoupdate.@login[0].source='${AUTOUPDATE_SOURCE}'
uci set autoupdate.@login[0].luci_edition='${AUTOUPDATE_EDITION}'
uci set autoupdate.@login[0].firmware_version='${CURRENT_FIRMWARE}'
uci set autoupdate.@login[0].target_board='x86'
uci set autoupdate.@login[0].device_model='${TARGET_PROFILE}'
uci set autoupdate.@login[0].firmware_suffix='.img.gz'
uci set autoupdate.@login[0].use_no_config_update='1'
uci commit autoupdate
exit 0
EOF
        chmod 0755 "$uci_defaults_path"
        echo "COMPILE_DATE=$COMPILE_DATE" >> $GITHUB_ENV
        echo "AUTOUPDATE_TAG=$AUTOUPDATE_TAG" >> $GITHUB_ENV
        echo "AUTOUPDATE_SOURCE=$AUTOUPDATE_SOURCE" >> $GITHUB_ENV
        echo "AUTOUPDATE_EDITION=$AUTOUPDATE_EDITION" >> $GITHUB_ENV
        echo "TARGET_PROFILE=$TARGET_PROFILE" >> $GITHUB_ENV
        echo "CURRENT_FIRMWARE=$CURRENT_FIRMWARE" >> $GITHUB_ENV
        echo "✅ luci-app-autoupdate 元数据已生成: $metadata_path"
        echo "✅ luci-app-autoupdate UCI 默认值脚本已生成: $uci_defaults_path"
    fi
}

Firmware_Diy_2() {
    if [[ "${BUILTIN_CONFIG}" == "true" ]]; then
        if [[ -z "${CONFIG_REPO_URL}" ]]; then
            echo "::error::BUILTIN_CONFIG 已启用，但未提供 CONFIG_REPO_URL 环境变量。"
            exit 1
        fi
        echo "正在克隆内置配置文件..."
        rm -rf BUILTIN_CONFIG
        if ! git clone "${CONFIG_REPO_URL}" -b master; then
            echo "::error::克隆 BUILTIN_CONFIG 仓库失败"
            exit 1
        fi
        # 【调试】打印当前 REPO_NAME，检查是否匹配
        echo "当前检测到的 REPO_NAME 为: [${REPO_NAME}]"
        echo "克隆仓库的目录结构如下:"
        ls -la BUILTIN_CONFIG
        # 根据 REPO_NAME 确定源目录
        if [[ "${REPO_NAME}" == "immortalwrt" ]]; then
            SOURCE_DIR="BUILTIN_CONFIG/immortalwrt/files"
        elif [[ "${REPO_NAME}" == "lede" ]]; then
            SOURCE_DIR="BUILTIN_CONFIG/lede/files"
        else
            echo "::warning::未知的 REPO_NAME (${REPO_NAME})，跳过配置文件移动"
            return 0
        fi
        # 【关键】在移动前检查源目录是否存在
        if [[ ! -d "${SOURCE_DIR}" ]]; then
            echo "::error::源目录 ${SOURCE_DIR} 不存在！请检查仓库结构或 REPO_NAME 是否正确。"
            exit 1
        fi
        # 【安全校验】确保当前处于 OpenWrt 源码根目录
        if [[ ! -d "package" ]]; then
            echo "::error::当前不在 OpenWrt 源码根目录，拒绝移动 files 以防路径错误！"
            exit 1
        fi
        echo "正在将 ${SOURCE_DIR} 同步到当前目录的 files 文件夹下..."
        mkdir -p files
        # 【注意】源路径带 / 表示同步目录内的内容；目标路径为当前目录下的 files
        rsync -av "${SOURCE_DIR}/" files/
		
		# 中文交互菜单：加执行权限 + 插入非交互检测（防止WinSCP卡住）
		if [ -f files/usr/bin/openwrt_menu_zh.sh ]; then
		    sed -i '2a [ -t 0 ] || exit 0' files/usr/bin/openwrt_menu_zh.sh
		    chmod +x files/usr/bin/openwrt_menu_zh.sh
		    echo "✅ 中文菜单脚本已处理: files/usr/bin/openwrt_menu_zh.sh"
		else
		    echo "⚠️  未找到中文菜单脚本 files/usr/bin/openwrt_menu_zh.sh，跳过"
		fi
        # 【验证】检查目标目录是否生成且非空
        if [[ -d "files" && -n "$(ls -A files)" ]]; then
            echo "✅ 文件同步成功！当前 files 目录内容如下:"
        else
            echo "::error::文件同步失败或 files 目录为空。"
            exit 1
        fi
        # 清理临时克隆的仓库
        rm -rf BUILTIN_CONFIG
    fi
}
