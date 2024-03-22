#!/bin/bash
#
# And/remove ports from Bridge and use wicked ifreload to apply
#
# setup:
#
#    dummy0,dummy1,tap0 -m-> br0
#

. ../../lib/common_pre.sh

br0=${br0:-br0}
dummy0=${dummy0:-dummy0}
dummy1=${dummy1:-dummy1}
tap0=${tap0:-tap0}


step0()
{
	bold "=== $step -- Setup configuration"
	echo ""

	cat >"${dir}/ifcfg-$dummy0" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-$dummy1" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-$br0" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='$dummy0'
	EOF

	print_test_description
	log_device_config "$dummy0" "$dummy1" "$br0"

	modprobe -qs dummy
	modprobe -qs tap
}

step1()
{
	bold "=== $step: ifup $br0 { $dummy0 + $tap0 }"

	echo "wicked $wdebug ifup $cfg all"
	wicked $wdebug ifup $cfg all
	echo ""

	print_device_status "$br0" "$dummy0"
	check_device_is_up "$br0" "$dummy0"
	echo ""

	echo "ip tuntap add $tap0 mode tap"
	ip tuntap add $tap0 mode tap
	echo "ip link set master $br0 up dev $tap0"
	ip link set master $br0 up dev $tap0
	echo ""

	print_device_status "$dummy0" "$dummy1" "$tap0"

	check_device_has_port "$br0" "$dummy0" "$tap0"
	check_device_has_not_port "$br0" "$dummy1"
	echo ""

	if wicked ifstatus $cfg $tap0 | grep -qs compat:suse ; then
		echo "ERROR: $tap0 has received generated config"
		((err))
	fi
}

step2()
{
	bold "=== $step: ifup $br0 { $dummy0 + $tap0 } again"

	echo "wicked $wdebug ifup $cfg all"
	wicked $wdebug ifup $cfg all
	echo ""

	print_device_status all

	check_device_has_port "$br0" "$dummy0" "$tap0"
	check_device_has_not_port "$br0" "$dummy1"
	echo ""

	if wicked ifstatus $cfg $tap0 | grep -qs compat:suse ; then
		echo "ERROR: $tap0 has received generated config"
		((err))
	fi
}

step3()
{
	bold "=== $step: ifreload $br0 { $dummy1 + $tap0 }"

	# change bridge to use $dummy1 instead + ifreload
	cat >"${dir}/ifcfg-$br0" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='$dummy1'
	EOF

	log_device_config "$dummy0" "$dummy1" "$br0"


	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all

	check_device_has_port "$br0" "$dummy1" "$tap0"
	check_device_has_not_port "$br0" "$dummy0"
	echo ""

	if wicked ifstatus $cfg $tap0 | grep -qs compat:suse ; then
		echo "ERROR: $tap0 has received generated config"
		((err))
	fi
}

step99()
{
	bold "=== $step: cleanup"

	echo "ip link delete $tap0"
	ip link delete $tap0
	echo "rmmod tap &>/dev/null"
	rmmod tap &>/dev/null
	echo ""

	echo "wicked $wdebug ifdown "$br0" "$dummy0" "$dummy1" "$tap0""
	wicked $wdebug ifdown "$br0" "$dummy0" "$dummy1" "$tap0"
	echo ""

	rm -f "${dir}/ifcfg-$dummy0"
	rm -f "${dir}/ifcfg-$dummy1"
	rm -f "${dir}/ifcfg-$br0"

	check_policy_not_exists "$dummy0"
	check_policy_not_exists "$dummy1"
	check_device_is_down "$br0"

	echo "rmmod dummy"
	rmmod dummy
}

. ../../lib/common.sh
