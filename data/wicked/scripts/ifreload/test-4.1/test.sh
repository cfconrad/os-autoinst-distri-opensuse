#!/bin/bash
#
# Changing the port configuration of a bridge and apply via ifreload
#
# setup:
#
#     eth0/eth1/none -m-> br0
#

br0="${br0:-br0}"
eth0="${eth0:-eth0}"
eth1="${eth1:-eth1}"


set_bridge_ports()
{
	local br=$1; shift

	sed -i "/BRIDGE_PORTS/cBRIDGE_PORTS='$*'" "${dir}/ifcfg-$br"

	cat < "${dir}/ifcfg-${br}" | tee "config-step-${step}.cfg"
	wicked show-config $cfg | tee "config-step-${step}.xml"
}

step0()
{
	bold "=== $step -- Setup configuration"

	# no explicit port config
	rm -f -- "${dir}/ifcfg-$eth0"
	rm -f -- "${dir}/ifcfg-$eth1"

	# port in the port list
	cat >"${dir}/ifcfg-$br0" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='$eth0'
	EOF

	cat < "${dir}/ifcfg-${br}" | tee "config-step-${step}.cfg"
	wicked show-config $cfg | tee "config-step-${step}.xml"
}

step1()
{
	bold "=== $step: ifup all: $br0 { $eth0 }"

	set_bridge_ports "$br0" "$eth0"

	echo "wicked $wdebug ifup $cfg all"
	wicked $wdebug ifup $cfg all
	echo ""

	print_device_status "$br0" "$eth0"
	print_bridges

	check_device_has_port "$br0" "$eth0"
	check_device_has_compat_suse_config "$eth0"
}

step2()
{
	bold "=== $step: ifreload all: $br0 { }"

	set_bridge_ports "$br0" ""

	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status "$br0" "$eth0"
	print_bridges

	check_device_has_not_port "$br0" "$eth0"
	check_device_has_not_compat_suse_config "$eth0"
}

step3()
{
	step1
}

step4()
{
	bold "=== $step: ifreload $br0: $br0 { }"

	set_bridge_ports "$br0" ""

	echo "wicked $wdebug ifreload $cfg $br0"
	wicked $wdebug ifreload $cfg $br0
	echo ""

	print_device_status "$br0" "$eth0"
	print_bridges

	check_device_has_not_port "$br0" "$eth0"
	check_device_has_not_compat_suse_config "$eth0"
}

step5()
{
	bold "=== $step: ifreload $br0: $br0 { $eth0 }"

	set_bridge_ports "$br0" "$eth0"

	echo "wicked $wdebug ifreload $cfg $br0"
	wicked $wdebug ifreload $cfg $br0
	echo ""

	print_device_status "$br0" "$eth0"
	print_bridges

	check_device_has_port "$br0" "$eth0"
	check_device_has_compat_suse_config "$eth0"
}

step6()
{
	bold "=== $step: ifreload $eth0: $br0 { }"

	set_bridge_ports "$br0" ""

	echo "wicked $wdebug ifreload $cfg $eth0"
	wicked $wdebug ifreload $cfg "$eth0"
	echo ""

	print_device_status "$br0" "$eth0"
	print_bridges

	check_device_has_not_port "$br0" "$eth0"
	check_device_has_not_compat_suse_config "$eth0"
}

step7()
{
	bold "=== $step: ifreload $eth0: $br0 { $eth0 }"

	set_bridge_ports "$br0" "$eth0"

	echo "wicked $wdebug ifreload $cfg $eth0"
	wicked $wdebug ifreload $cfg "$eth0"
	echo ""

	print_device_status "$br0" "$eth0"
	print_bridges

	check_device_has_not_port "$br0" "$eth1"
	check_device_has_port "$br0" "$eth0"
	check_device_has_compat_suse_config "$eth0"
	check_device_has_not_compat_suse_config "$eth1"
}

step8()
{
	bold "=== $step: ifreload all: $br0 { $eth1 }"
	# switching the port interface

	set_bridge_ports "$br0" "$eth1"

	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg "all"
	echo ""

	print_device_status "$br0" "$eth0" "$eth1"
	print_bridges

	check_device_has_port "$br0" "$eth1"
	check_device_has_not_port "$br0" "$eth0"
	check_device_has_compat_suse_config "$eth1"
	check_device_has_not_compat_suse_config "$eth0"
}

step9()
{
	bold "=== $step: ifreload $eth0 $eth1: $br0 { $eth0 }"
	# switching the port interface

	set_bridge_ports "$br0" "$eth0"

	echo "wicked $wdebug ifreload $cfg $eth0 $eth1"
	wicked $wdebug ifreload $cfg "$eth0" "$eth1"
	echo ""

	print_device_status "$br0" "$eth0" "$eth1"
	print_bridges

	check_device_has_port "$br0" "$eth0"
	check_device_has_not_port "$br0" "$eth1"
	check_device_has_compat_suse_config "$eth0"
	check_device_has_not_compat_suse_config "$eth1"
}

step10()
{
	bold "=== $step: ifreload $eth0: $br0 { $eth1 }"
	# switching the port interface

	set_bridge_ports "$br0" "$eth1"

	echo "wicked $wdebug ifreload $cfg $eth0"
	wicked $wdebug ifreload $cfg "$eth0"
	echo ""

	print_device_status "$br0" "$eth0" "$eth1"
	print_bridges

	check_device_has_not_port "$br0" "$eth0"
	check_device_has_not_port "$br0" "$eth1"

	check_device_has_not_compat_suse_config "$eth0"
	check_device_has_not_compat_suse_config "$eth1"
}

step11()
{
	bold "=== $step: ifreload $eth1: $br0 { $eth1 }"
	# switching the port interface

	set_bridge_ports "$br0" "$eth1"

	echo "wicked $wdebug ifreload $cfg $eth1"
	wicked $wdebug ifreload $cfg "$eth1"
	echo ""

	print_device_status "$br0" "$eth1" "$eth0"
	print_bridges

	check_device_has_not_port "$br0" "$eth0"
	check_device_has_port "$br0" "$eth1"

	check_device_has_not_compat_suse_config "$eth0"
	check_device_has_compat_suse_config "$eth1"
}


step99()
{
	bold "=== $step: cleanup"

	wicked $wdebug ifdown $br0 $eth0 $eth1
	rm -f "${dir}/ifcfg-$br0"
	rm -f "${dir}/ifcfg-$eth0"
	if test -d "/sys/class/net/$eth0" ; then
		ip link delete $eth0 && ((++err))
	fi
	if test -d "/sys/class/net/$br0" ; then
		ip link delete $br0 || ((++err))
	fi
	echo "-----------------------------------"
	ps  ax | grep /usr/.*/wicked | grep -v grep
	echo "-----------------------------------"
	wicked ifstatus $cfg all
	echo "-----------------------------------"
	print_bridges
	echo "-----------------------------------"
	ls -l /var/run/wicked/nanny/
	echo "==================================="
}

. ../../lib/common.sh
