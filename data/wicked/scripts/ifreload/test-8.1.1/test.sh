#!/bin/bash

nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
ipvlanA=${ipvlanA:-ipvlanA}
ipvlanA_ip4="${ipvlanA_ip4:-198.18.11.10/24}"

test_description()
{
	cat - <<-EOT

	Change IPVLAN config and run ifreload all.

	setup:

	   $ipvlanA <-l- $ipvlanA

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
	bold "=== $step ifreload all ($nicA <-l- $ipvlanA)"

	echo "# wicked $wdebug ifreload all"
	wicked $wdebug ifup all

	log_device_config $ipvlanA

	print_device_status "$nicA" "$ipvlanA"
	check_device_is_up "$nicA" "$ipvlanA"
	check_ipvlan "$ipvlanA" "l3" "bridge"
}

step5()
{
	bold "=== $step ifreload $ipvlanA (l3 bridge)"

	modify_ipvlan $ipvlanA l3 bridge

	echo "# wicked $wdebug ifreload $ipvlanA"
	wicked $wdebug ifreload "$ipvlanA"

	log_device_config $ipvlanA

	print_device_status "$nicA" "$ipvlanA"
	check_device_is_up "$nicA" "$ipvlanA"
	check_ipvlan "$ipvlanA" "l3" "bridge"
}

step6()
{
	bold "=== $step ifreload $ipvlanA (l3 vepa)"
	modify_ipvlan $ipvlanA l3 vepa

	echo "# wicked $wdebug ifreload $ipvlanA"
	wicked $wdebug ifreload "$ipvlanA"

	log_device_config $ipvlanA

	print_device_status "$nicA" "$ipvlanA"
	check_device_is_up "$nicA" "$ipvlanA"
	check_ipvlan "$ipvlanA" "l3" "vepa"
}

step7()
{
	bold "=== $step ifreload $ipvlanA (l3s vepa)"
	modify_ipvlan $ipvlanA l3s vepa

	echo "# wicked $wdebug ifreload $ipvlanA"
	wicked $wdebug ifreload "$ipvlanA"

	log_device_config $ipvlanA

	print_device_status "$nicA" "$ipvlanA"
	check_device_is_up "$nicA" "$ipvlanA"
	check_ipvlan "$ipvlanA" "l3s" "vepa"
}

step8()
{
	bold "=== $step ifreload $ipvlanA - change IPVLAN_DEVICE"

	cat >"${dir}/ifcfg-${ipvlanA}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${ipvlan_ip4:+IPADDR='${ipvlanA_ip4}'}
		IPVLAN=yes
		IPVLAN_DEVICE='${nicB}'
		IPVLAN_MODE=l3s
		IPVLAN_FLAGS=vepa
	EOF

	echo "# wicked $wdebug ifreload $ipvlanA"
	wicked $wdebug ifreload "$ipvlanA"

	print_device_status "$nicB" "$ipvlanA"
	check_device_is_up "$nicB" "$ipvlanA"
	check_ipvlan "$ipvlanA" "l3s" "vepa"
	check_device_has_link "$ipvlanA" "$nicB"
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
