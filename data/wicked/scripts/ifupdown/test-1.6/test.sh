#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"

nicA_ip4="${nicA_ip4:-198.18.10.10/24}"
ipvtapA="${ipvtapA:-ipvtapA}"
ipvtapA_ip4="${ipvtapA_ip4:-198.18.11.10/24}"

test_description()
{
	cat - <<-EOT

	ipvtap on physical interfaces

	setup:

	   $nicA   -m->    $ipvtapA

	EOT
}

modify_ipvtap()
{
	local device
	local mode
	local flags

	device=$1
	mode=$2
	flags=$3

	sed -i '/IPVTAP_MODE=/cIPVTAP_MODE='$mode "$dir/ifcfg-$device"
	sed -i '/IPVTAP_FLAGS=/cIPVTAP_FLAGS='$flags "$dir/ifcfg-$device"
}

step0()
{
	bold "=== $step -- Setup configuration"

	print_test_description

	cat >"${dir}/ifcfg-${nicA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		IPADDR='${nicA_ipv4}'
	EOF

	cat >"${dir}/ifcfg-${ipvtapA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${ipvtap_ip4:+IPADDR='${ipvtapA_ip4}'}
		IPVTAP=yes
		IPVTAP_DEVICE='${nicA}'
		IPVTAP_MODE=l3
		IPVTAP_FLAGS=bridge
	EOF

	log_device_config all
}

step1()
{
	bold "=== $step ifup all ($nicA <-l- $ipvtapA)"

	echo "# wicked $wdebug ifup all"
	wicked $wdebug ifup all

	log_device_config $ipvtapA

	print_device_status "$nicA" "$ipvtapA"
	check_device_is_up "$nicA" "$ipvtapA"
	check_ipvtap "$ipvtapA" "l3" "bridge"

	echo "# wicked $wdebug ifdown $nicA $ipvtapA"
	wicked $wdebug ifdown "$nicA" "$ipvtapA"
	check_device_is_down "$nicA" "$ipvtapA"
}

step2()
{
	bold "=== $step ifup $ipvtapA ($nicA <-l- $ipvtapA)"

	echo "# wicked $wdebug ifup $ipvtapA"
	wicked $wdebug ifup $ipvtapA

	log_device_config $ipvtapA

	print_device_status "$nicA" "$ipvtapA"
	check_device_is_up "$nicA" "$ipvtapA"
	check_ipvtap "$ipvtapA" "l3" "bridge"

	echo "# wicked $wdebug ifdown $nicA $ipvtapA"
	wicked $wdebug ifdown "$nicA" "$ipvtapA"
	check_device_is_down "$nicA" "$ipvtapA"
}

step3()
{
	bold "=== $step ifup $ipvtapA (mode: l2 private)"

	modify_ipvtap $ipvtapA l2 private

	echo "# wicked $wdebug ifup $ipvtapA"
	wicked $wdebug ifup $ipvtapA

	log_device_config $ipvtapA

	print_device_status "$nicA" "$ipvtapA"
	check_device_is_up "$nicA" "$ipvtapA"
	check_ipvtap "$ipvtapA" "l2" "private"

	echo "# wicked $wdebug ifdown $nicA $ipvtapA"
	wicked $wdebug ifdown "$nicA" "$ipvtapA"
	check_device_is_down "$nicA" "$ipvtapA"
}

step4()
{
	bold "=== $step ifup $ipvtapA (mode: l3s vepa)"

	modify_ipvtap $ipvtapA l3s vepa

	echo "# wicked $wdebug ifup $ipvtapA"
	wicked $wdebug ifup "$ipvtapA"

	log_device_config $ipvtapA

	print_device_status "$nicA" "$ipvtapA"
	check_device_is_up "$nicA" "$ipvtapA"
	check_ipvtap "$ipvtapA" "l3s" "vepa"

	echo "# wicked $wdebug ifdown $nicA $ipvtapA"
	wicked $wdebug ifdown "$nicA" "$ipvtapA"
	check_device_is_down "$nicA" "$ipvtapA"
}

step5()
{
	bold "=== $step ifup + ifup $ipvtapA (l3 bridge)"

	modify_ipvtap $ipvtapA l3 bridge

	echo "# wicked $wdebug ifup $ipvtapA"
	wicked $wdebug ifup "$ipvtapA"

	log_device_config $ipvtapA

	print_device_status "$nicA" "$ipvtapA"
	check_device_is_up "$nicA" "$ipvtapA"
	check_ipvtap "$ipvtapA" "l3" "bridge"
}

step6()
{
	bold "=== $step ifup + ifup $ipvtapA (l3 vepa)"
	modify_ipvtap $ipvtapA l3 vepa

	echo "# wicked $wdebug ifup $ipvtapA"
	wicked $wdebug ifup "$ipvtapA"

	log_device_config $ipvtapA

	print_device_status "$nicA" "$ipvtapA"
	check_device_is_up "$nicA" "$ipvtapA"
	check_ipvtap "$ipvtapA" "l3" "vepa"
}

step7()
{
	bold "=== $step ifup + ifup $ipvtapA (l3s vepa)"
	modify_ipvtap $ipvtapA l3s vepa

	echo "# wicked $wdebug ifup $ipvtapA"
	wicked $wdebug ifup "$ipvtapA"

	log_device_config $ipvtapA

	print_device_status "$nicA" "$ipvtapA"
	check_device_is_up "$nicA" "$ipvtapA"
	check_ipvtap "$ipvtapA" "l3s" "vepa"
}

step99()
{
	bold "=== Cleanup"
	rm "${dir}/ifcfg-${nicA}"
	rm "${dir}/ifcfg-${ipvtapA}"

	echo "# wicked $wdebug ifdown ${nicA} ${ipvtapA}"
	wicked $wdebug ifdown "${nicA}" "${ipvtapA}"

	check_device_is_down "$nicA" "$ipvtapA"
}

. ../../lib/common.sh
