#!/bin/bash
#
#
# Setup:
#     eth1   -m->    ovsbr0   <-l-    ovsbr1
#
. ../../lib/common_pre.sh

eth0=${eth0:-eth0}
eth1=${eth1:-eth1}
ovsbr0=${ovsbr0:-ovsbr0}
tap0=${tap0:-tap3}

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

	log_device_config "$br" "$@"
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

	print_test_description
	log_device_config "$ovsbr0"
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

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
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

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
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

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
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

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
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

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
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

	echo "# wicked ifdown ${ovsbr0} ${eth0}"
	wicked ${wdebug} ifdown ${ovsbr0} ${eth0}
	echo ""

	print_device_status ${ovsbr0} ${eth0} ${tap0}
	echo "# ovs-vsctl show"
	ovs-vsctl show
	echo ""

	# delete tap0 we've created in this testcase
	echo "# ip link delete ${tap0}"
	ip link delete ${tap0}
	echo ""

	# just in case ifdown fails, also br in ovs
	echo "# ovs-vsctl del-br ${ovsbr0}"
	ovs-vsctl del-br ${ovsbr0}
	echo ""

	echo "# rm -v -f -- ${dir}/ifcfg-${ovsbr0}*"
	rm -v -f -- "${dir}/ifcfg-${ovsbr0}"*
	echo "# rm -v -f -- ${dir}/ifcfg-${eth0}*"
	rm -v -f -- "${dir}/ifcfg-${eth0}"*
	echo ""

	echo "==================================="
}


. ../../lib/common.sh
