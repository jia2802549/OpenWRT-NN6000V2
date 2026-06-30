#!/bin/bash
# SPDX-License-Identifier: MIT
# Copyright (C) 2026 VIKINGYFY

#移除luci-app-attendedsysupgrade
sed -i "/attendedsysupgrade/d" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改默认主题
sed -i "s/luci-theme-bootstrap/luci-theme-$WRT_THEME/g" $(find ./feeds/luci/collections/ -type f -name "Makefile")
#修改immortalwrt.lan关联IP
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $(find ./feeds/luci/modules/luci-mod-system/ -type f -name "flash.js")
#添加编译日期标识
sed -i "s/(\(luciversion || ''\))/(\1) + (' \/ $WRT_MARK-$WRT_DATE')/g" $(find ./feeds/luci/modules/luci-mod-status/ -type f -name "10_system.js")

WIFI_SH=$(find ./target/linux/{mediatek/filogic,qualcommax}/base-files/etc/uci-defaults/ -type f -name "*set-wireless.sh" 2>/dev/null)
WIFI_UC="./package/network/config/wifi-scripts/files/lib/wifi/mac80211.uc"
if [ -f "$WIFI_SH" ]; then
	#修改WIFI名称
	sed -i "s/BASE_SSID='.*'/BASE_SSID='$WRT_SSID'/g" $WIFI_SH
	#修改WIFI密码
	sed -i "s/BASE_WORD='.*'/BASE_WORD='$WRT_WORD'/g" $WIFI_SH
elif [ -f "$WIFI_UC" ]; then
	#修改WIFI名称
	sed -i "s/ssid='.*'/ssid='$WRT_SSID'/g" $WIFI_UC
	#修改WIFI密码
	sed -i "s/key='.*'/key='$WRT_WORD'/g" $WIFI_UC
fi

CFG_FILE="./package/base-files/files/bin/config_generate"
#修改默认IP地址
sed -i "s/192\.168\.[0-9]*\.[0-9]*/$WRT_IP/g" $CFG_FILE
#修改默认主机名
sed -i "s/hostname='.*'/hostname='$WRT_NAME'/g" $CFG_FILE

#配置文件修改
echo "CONFIG_PACKAGE_luci=y" >> ./.config
echo "CONFIG_LUCI_LANG_zh_Hans=y" >> ./.config
echo "CONFIG_PACKAGE_luci-theme-$WRT_THEME=y" >> ./.config
echo "CONFIG_PACKAGE_luci-app-$WRT_THEME-config=y" >> ./.config

#引入私有扩展配置
if [ -f "$GITHUB_WORKSPACE/Config/PRIVATE.txt" ]; then
	echo "Applying private configurations from PRIVATE.txt..."
	cat $GITHUB_WORKSPACE/Config/PRIVATE.txt >> ./.config
fi

#手动调整的插件
if [ -n "$WRT_PACKAGE" ]; then
	echo -e "$WRT_PACKAGE" >> ./.config
fi

#无WIFI配置标志
if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
	echo "WRT_WIFI=wifi-no" >> $GITHUB_ENV
fi

#高通平台调整
DTS_PATH="./target/linux/qualcommax/dts/"
if [[ "${WRT_TARGET^^}" == *"QUALCOMMAX"* ]]; then
	#无WIFI配置调整Q6大小
	if [[ "${WRT_CONFIG,,}" == *"wifi"* && "${WRT_CONFIG,,}" == *"no"* ]]; then
		find $DTS_PATH -type f ! -iname '*nowifi*' -exec sed -i 's/ipq\(6018\|8074\).dtsi/ipq\1-nowifi.dtsi/g' {} +
		echo "qualcommax set up nowifi successfully!"
	fi
fi
# 切换到源码目录执行内核配置工具，解决路径错位bbr
cd $GITHUB_WORKSPACE/wrt
./scripts/config --set-val CONFIG_TCP_BBR y
./scripts/config --set-val CONFIG_NET_SCH_FQ y
./scripts/config --set-val CONFIG_NET_SCH_FQ_CODEL y
cd $GITHUB_WORKSPACE
# ========== IPQ6000 1.8GHz 超频｜无错完美版（适配你的NN6000-V2源码） ==========

# 1. 精准在 1.5GHz 节点后追加 1.8GHz 原厂电压节点（1075mV，不加压）
sed -i '/opp-1500000000 {/,+4a\    opp-1800000000 {\
        opp-hz = /bits/ 64 <1800000000>;\
        opp-microvolt = <1075000>;\
        opp-supported-hw = <0xf>;\
        clock-latency-ns = <200000>;\
    };' $GITHUB_WORKSPACE/wrt/target/linux/qualcommax/dts/ipq6000.dtsi

# 2. 解锁NN6000-V2专属设备树1.2GHz上限，放开至1.8GHz（使用真实的 9 个 0 位数）
sed -i 's/cpu-max-freq = <1200000000>;/cpu-max-freq = <1800000000>;/g' $GITHUB_WORKSPACE/wrt/target/linux/qualcommax/dts/ipq6000-nn6000-v2.dts

# 3. 动态调频脚本：空闲降频省电降温，流量自动拉满1.8GHz
cat >> $GITHUB_WORKSPACE/wrt/package/base-files/files/etc/uci-defaults/99-oc-1800 << EOF
#!/bin/sh
echo ondemand > /sys/devices/system/cpu/cpufreq/policy0/scaling_governor
echo 1800000 > /sys/devices/system/cpu/cpufreq/policy0/scaling_max_freq
echo 1800000 > /sys/devices/system/cpu/cpu0/cpufreq/scaling_max_freq
echo 1800000 > /sys/devices/system/cpu/cpu1/cpufreq/scaling_max_freq
echo 1800000 > /sys/devices/system/cpu/cpu2/cpufreq/scaling_max_freq
echo 1800000 > /sys/devices/system/cpu/cpu3/cpufreq/scaling_max_freq
EOF
chmod +x $GITHUB_WORKSPACE/wrt/package/base-files/files/etc/uci-defaults/99-oc-1800
# ======================================================================

