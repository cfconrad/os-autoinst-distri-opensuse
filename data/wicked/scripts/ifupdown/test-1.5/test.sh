#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"

nicA_ip4="${nicA_ip4:-198.18.10.10/24}"
ipvlanA="${ipvlanA:-ipvlanA}"
ipvlanA_ip4="${ipvlanA_ip4:-198.18.11.10/24}"

test_description()
{
	cat - <<-EOT

	ipvlan on physical interfaces

	setup:

	   $nicA   -m->    $ipvlanA

	EOT
}

modify_ipvlan()
{
	local device
	local mode
	local flags

	device=$1
	mode=$2
	flags=$3

	sed -i '/IPVLAN_MODE=/cIPVLAN_MODE='$mode "$dir/ifcfg-$device"
	sed -i '/IPVLAN_FLAGS=/cIPVLAN_FLAGS='$flags "$dir/ifcfg-$device"
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

	cat >"${dir}/ifcfg-${ipvlanA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${ipvlan_ip4:+IPADDR='${ipvlanA_ip4}'}
		IPVLAN=yes
		IPVLAN_DEVICE='${nicA}'
		IPVLAN_MODE=l3
		IPVLAN_FLAGS=bridge
	EOF

	log_device_config all
}

step1()
{
	bold "=== $step ifup all ($nicA <-l- $ipvlanA)"

	echo "# wicked $wdebug ifup all"
	wicked $wdebug ifup all

	log_device_config $ipvlanA

	print_device_status "$nicA" "$ipvlanA"
	check_device_is_up "$nicA" "$ipvlanA"
	check_ipvlan "$ipvlanA" "l3" "bridge"

	echo "# wicked $wdebug ifdown $nicA $ipvlanA"
	wicked $wdebug ifdown "$nicA" "$ipvlanA"
	check_device_is_down "$nicA" "$ipvlanA"
}

step2()
{
	bold "=== $step ifup $ipvlanA ($nicA <-l- $ipvlanA)"

	echo "# wicked $wdebug ifup $ipvlanA"
	wicked $wdebug ifup $ipvlanA

	log_device_config $ipvlanA

	print_device_status "$nicA" "$ipvlanA"
	check_device_is_up "$nicA" "$ipvlanA"
	check_ipvlan "$ipvlanA" "l3" "bridge"

	echo "# wicked $wdebug ifdown $nicA $ipvlanA"
	wicked $wdebug ifdown "$nicA" "$ipvlanA"
	check_device_is_down "$nicA" "$ipvlanA"
}

step3()
{
	bold "=== $step ifup $ipvlanA (mode: l2 private)"

	modify_ipvlan $ipvlanA l2 private

	echo "# wicked $wdebug ifup $ipvlanA"
	wicked $wdebug ifup $ipvlanA

	log_device_config $ipvlanA

	print_device_status "$nicA" "$ipvlanA"
	check_device_is_up "$nicA" "$ipvlanA"
	check_ipvlan "$ipvlanA" "l2" "private"

	echo "# wicked $wdebug ifdown $nicA $ipvlanA"
	wicked $wdebug ifdown "$nicA" "$ipvlanA"
	check_device_is_down "$nicA" "$ipvlanA"
}

step4()
{
	bold "=== $step ifup $ipvlanA (mode: l3s vepa)"

	modify_ipvlan $ipvlanA l3s vepa

	echo "# wicked $wdebug ifup $ipvlanA"
	wicked $wdebug ifup "$ipvlanA"

	log_device_config $ipvlanA

	print_device_status "$nicA" "$ipvlanA"
	check_device_is_up "$nicA" "$ipvlanA"
	check_ipvlan "$ipvlanA" "l3s" "vepa"

	echo "# wicked $wdebug ifdown $nicA $ipvlanA"
	wicked $wdebug ifdown "$nicA" "$ipvlanA"
	check_device_is_down "$nicA" "$ipvlanA"
}

step5()
{
	bold "=== $step ifup + ifup $ipvlanA (l3 bridge)"

	modify_ipvlan $ipvlanA l3 bridge

	echo "# wicked $wdebug ifup $ipvlanA"
	wicked $wdebug ifup "$ipvlanA"

	log_device_config $ipvlanA

	print_device_status "$nicA" "$ipvlanA"
	check_device_is_up "$nicA" "$ipvlanA"
	check_ipvlan "$ipvlanA" "l3" "bridge"
}

step6()
{
	bold "=== $step ifup + ifup $ipvlanA (l3 vepa)"
	modify_ipvlan $ipvlanA l3 vepa

	echo "# wicked $wdebug ifup $ipvlanA"
	wicked $wdebug ifup "$ipvlanA"

	log_device_config $ipvlanA

	print_device_status "$nicA" "$ipvlanA"
	check_device_is_up "$nicA" "$ipvlanA"
	check_ipvlan "$ipvlanA" "l3" "vepa"
}

step7()
{
	bold "=== $step ifup + ifup $ipvlanA (l3s vepa)"
	modify_ipvlan $ipvlanA l3s vepa

	echo "# wicked $wdebug ifup $ipvlanA"
	wicked $wdebug ifup "$ipvlanA"

	log_device_config $ipvlanA

	print_device_status "$nicA" "$ipvlanA"
	check_device_is_up "$nicA" "$ipvlanA"
	check_ipvlan "$ipvlanA" "l3s" "vepa"
}

step99()
{
	bold "=== Cleanup"
	rm "${dir}/ifcfg-${nicA}"
	rm "${dir}/ifcfg-${ipvlanA}"

	echo "# wicked $wdebug ifdown ${nicA} ${ipvlanA}"
	wicked $wdebug ifdown "${nicA}" "${ipvlanA}"

	check_device_is_down "$nicA" "$ipvlanA"
}

. ../../lib/common.sh
