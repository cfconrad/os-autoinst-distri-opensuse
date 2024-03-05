#!/bin/bash
#
#
# Setup:
#     eth1   -m->    ovsbr0   <-l-    ovsbr1
#
eth0=${eth0:-eth0}
eth1=${eth1:-eth1}
ovsbr0=${ovsbr0:-ovsbr0}
tap0=${tap0:-tap3}
ovs_system=ovs-system

set_ovsbridge_ports()
{
	local br=$1; shift

	if [ "XXX$*" == "XXX" ]; then
		sed -i "/OVS_BRIDGE_PORT_DEVICE/d" "${dir}/ifcfg-$br"
	else
		if grep -qsw OVS_BRIDGE_PORT_DEVICE "${dir}/ifcfg-$br"; then
			sed -i "/OVS_BRIDGE_PORT_DEVICE/cOVS_BRIDGE_PORT_DEVICE='$*'" "${dir}/ifcfg-$br"
		else
			echo "OVS_BRIDGE_PORT_DEVICE='$*'" >> "${dir}/ifcfg-$br"
		fi
	fi

	print_device_config "$br" "$@"
}

step0()
{
	bold "=== $step -- Setup configuration"

	cat >"${dir}/ifcfg-${ovsbr0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		OVS_BRIDGE='yes'
		OVS_BRIDGE_PORT_DEVICE='${eth0}'
		# ignore br carrier
		LINK_REQUIRED='no'
	EOF
}

step1()
{
	bold "=== $step: ifup ${ovsbr0} { ${eth0} }"

	echo "wicked ${wdebug} ifup $cfg all"
	wicked ${wdebug} ifup $cfg all
	echo ""

	print_device_status "$ovsbr0" "$eth0"
	check_ovsbr_has_port "$ovsbr0" "$eth0"
}

step2()
{
	bold "=== $step: ifreload ${ovsbr0} { }"

	set_ovsbridge_ports "$ovsbr0" ""

	echo "wicked ${wdebug} ifreload all"
	wicked ${wdebug} ifreload $cfg all
	echo ""

	print_device_status "$ovsbr0" "$eth0"
	check_ovsbr_has_not_port "$ovsbr0" "$eth0"
}

step3()
{
	bold "=== $step: ifreload ${ovsbr0} { ${eth0} + ${tap0} }"

	set_ovsbridge_ports "$ovsbr0" "$eth0"

	echo "wicked ${wdebug} ifreload $cfg all"
	wicked ${wdebug} ifreload $cfg all
	echo ""

	print_device_status "$ovsbr0" "$eth0"
	check_ovsbr_has_port "$ovsbr0" "$eth0"


	ip tuntap add ${tap0} mode tap
	ovs-vsctl add-port ${ovsbr0} ${tap0}
	ip link set up dev ${tap0}

	print_device_status "${ovsbr0}" "${eth0}" "${tap0}"
	ovs-vsctl show

	check_ovsbr_has_port "$ovsbr0" "$eth0" "$tap0"
}

step4()
{
	bold "=== $step: ifreload ${ovsbr0} { ${tap0} }"

	set_ovsbridge_ports "$ovsbr0" ""

	echo "wicked ${wdebug} ifreload $cfg all"
	wicked ${wdebug} ifreload $cfg all
	echo ""

	print_device_status "${ovsbr0}" "${eth0}" "${tap0}"
	ovs-vsctl show

	check_ovsbr_has_port "$ovsbr0" "$tap0"
	check_ovsbr_has_not_port "$ovsbr0" "$eth0"
}

step5()
{
	bold "=== $step: ifreload ${ovsbr0} { ${tap0} + $eth1 }"

	set_ovsbridge_ports "$ovsbr0" "$eth1"

	echo "wicked ${wdebug} ifreload $cfg all"
	wicked ${wdebug} ifreload $cfg all
	echo ""

	print_device_status "${ovsbr0}" "${eth1}" "$eth0" "${tap0}"
	ovs-vsctl show

	check_ovsbr_has_port "$ovsbr0" "$tap0" "$eth1"
	check_ovsbr_has_not_port "$ovsbr0" "$eth0"
}

step6()
{
	bold "=== $step: ifreload ${ovsbr0} { ${tap0} + $eth0 }"

	set_ovsbridge_ports "$ovsbr0" "$eth0"

	echo "wicked ${wdebug} ifreload $cfg all"
	wicked ${wdebug} ifreload $cfg all
	echo ""

	print_device_status "${ovsbr0}" "${eth1}" "$eth0" "${tap0}"
	ovs-vsctl show

	check_ovsbr_has_port "$ovsbr0" "$tap0" "$eth0"
	check_ovsbr_has_not_port "$ovsbr0" "$eth1"
}


step99()
{
	bold "=== $step: cleanup"

	wicked ${wdebug} ifdown ${ovs} ${eth0}
	rm -f "${dir}/ifcfg-${ovsbr0}"
	rm -f "${dir}/ifcfg-${eth0}"
	ip link delete ${tap}
	ovs-vsctl del-br ${ovsbr0}
	wicked ${wdebug} ifstatus all
	ovs-vsctl show
	echo "==================================="
}


. ../../lib/common.sh
