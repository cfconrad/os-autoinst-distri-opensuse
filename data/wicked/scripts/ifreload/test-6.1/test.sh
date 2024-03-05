#!/bin/bash
eth0=${eth0:-eth0}
eth1=${eth1:-eth1}
team0="team0"
team_slaves="$eth0 $eth1"
team_slave_ifcfg=no

vlan0_id="2140"
vlan1_id="2144"
vlan0="${team0}.${vlan0_id}"
vlan1="${team0}.${vlan1_id}"
br0="br40"
br1="br44"

other_call="tuntap" # link or tuntap supported
other_type="tap"
other0="tap40"
other1="tap44"

#set -x

step0()
{
	bold "=== $step -- Setup configuration"

	##
	## setup team as br0 port
	##
	cat >"${dir}/ifcfg-${team0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		TEAM_RUNNER='activebackup'
		TEAM_LW_NAME='ethtool'
	EOF
	i=0
	for slave in ${team_slaves} ; do
		((i++))
		cat >>"${dir}/ifcfg-${team0}" <<-EOF
			TEAM_PORT_DEVICE_${i}='$slave'
		EOF
	done
	if test "X$team_slave_ifcfg" = "Xyes" ; then
		for slave in ${team_slaves} ; do
			cat >"${dir}/ifcfg-${slave}" <<-EOF
				STARTMODE='hotplug'
				BOOTPROTO='none'
			EOF
		done
	fi

	cat >"${dir}/ifcfg-${vlan1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${team0}'
		#VLAN_ID='${vlan1_id}'
	EOF

	# vlan1 is untagged pvid on team
	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${team0}'
	EOF

	# vlan2 is a tagged vlan on team
	cat >"${dir}/ifcfg-${br1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${vlan1}'
	EOF

	print_test_description
	print_device_config "$team0" "$vlan1" "$br0" "$br1"
}

step1()
{
	bold "=== $step: ifreload ${br0} { ${team0} { ${team_slaves} } + ${other0} }, ${br1} { ${vlan1} + ${other1} }"

	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	case ${other_call} in
	link)
	    echo "ip link add ${other0} type ${other_type}"
	    ip link add ${other0} type ${other_type}
	    echo "ip link add ${other1} type ${other_type}"
	    echo ""
	    ;;
	tuntap)
	    echo "ip tuntap add ${other0} mode ${other_type}"
	    ip tuntap add ${other0} mode ${other_type}
	    echo "ip tuntap add ${other1} mode ${other_type}"
	    ip tuntap add ${other1} mode ${other_type}
	    ;;
	esac
	echo "ip link set master ${br0} up dev ${other0}"
	ip link set master ${br0} up dev ${other0} || ((err++))
	echo "ip link set master ${br1} up dev ${other1}"
	ip link set master ${br1} up dev ${other1} || ((err++))

	print_device_status all
	print_bridges

	check_device_has_port "$team0" ${team_slaves}

	check_device_has_not_port "$br0" "$vlan0"
	check_device_has_port "$br0" "$team0" "$other0"
	check_device_has_port "$br1" "$vlan1" "$other1"
	check_device_has_link "$vlan1" "$team0"
}

step2()
{
	bold "=== $step: ifreload ${team0} { ${team_slaves} }, ${br0} { ${vlan0} + ${other0} }, ${br1} { ${vlan1} + ${other1} }"
	#
	## setup team vlan1 instead of team as br0 port
	##

	cat >"${dir}/ifcfg-${vlan0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${team0}'
		#VLAN_ID='${vlan0_id}'
	EOF

	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${vlan0}'
	EOF

	print_device_config

	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all
	print_bridges

	check_device_has_link "$vlan0" "$team0"
	check_device_has_port "$team0" ${team_slaves}
	check_device_has_not_port "$team0" "$br0"
	check_device_has_port "$br0" "$vlan0" "$other0"
	check_device_has_port "$br1" "$vlan1" "$other1"
	check_device_has_link "$vlan1" "$team0"
}

step3()
{
	bold "=== $step: ifreload ${team0} { ${team_slaves} }, ${br0} { + ${other0} }, ${br1} { ${vlan1} + ${other1} }, ${vlan0}"
	##
	## remove team vlan1 from br0 ports, but keep vlan1 ifcfg file
	##

	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS=''
	EOF

	print_device_config

	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all
	print_bridges

	check_device_has_port "$team0" ${team_slaves}
	check_device_has_not_port "$br0" "$team0" "$vlan0"
	check_device_has_port "$br0" "$other0"
	check_device_has_port "$br1" "$vlan1" "$other1"
	check_device_has_link "$vlan1" "$team0"
}

step4()
{
	bold "=== $step: ifreload ${team0} { ${team_slaves} }, ${br0} { + ${other0} }, ${br1} { ${vlan1} + ${other1} }"
	##
	## cleanup unenslaved team vlan1
	##

	rm -f "${dir}/ifcfg-${vlan0}"

	print_device_config

	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all
	print_bridges

	check_device_has_port "$team0" ${team_slaves}
	check_device_has_not_port "$br0" "$team0" "$vlan0"
	check_device_has_port "$br0" "$other0"
	check_device_has_port "$br1" "$vlan1" "$other1"
	device_exists "$vlan0" && ((err++))
	check_device_has_link "$vlan1" "$team0"
}

step5()
{
	##
	## create team vlan0 and enslave as br0 port again
	##
	bold "=== $step: ifreload ${team0} { ${team_slaves} }, ${br0} { ${vlan0} + ${other0} }, ${br1} { ${vlan1} + ${other1} }"

	cat >"${dir}/ifcfg-${vlan0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${team0}'
		#VLAN_ID='${vlan0_id}'
	EOF

	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${vlan0}'
	EOF

	print_device_config

	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all
	print_bridges

	check_device_has_link "$vlan0" "$team0"
	check_device_has_port "$team0" ${team_slaves}
	check_device_has_not_port "$team0" "$br0"
	check_device_has_port "$br0" "$vlan0" "$other0"
	check_device_has_port "$br1" "$vlan1" "$other1"
	check_device_has_link "$vlan1" "$team0"
}

step6()
{
	##
	## replace team vlan0 br0 port with team and delete team vlan0 again
	##
	bold "=== $step: ifreload ${br0} { ${team0} { ${team_slaves} } + ${other0} }, ${br1} { ${vlan1} + ${other1} }"

	rm -f "${dir}/ifcfg-${vlan0}"
	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${team0}'
	EOF

	print_device_config

	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all
	print_bridges

	check_device_has_port "$team0" ${team_slaves}
	check_device_has_not_port "$br0" "$vlan0"
	check_device_has_port "$br0" "$team0" "$other0"
	check_device_has_port "$br1" "$vlan1" "$other1"
	device_exists "$vlan0" && ((err++))
	check_device_has_link "$vlan1" "$team0"
}

step7()
{
	##
	## removal of first team slave from config (it is **not** a hotplugging test)
	##
	bold "=== $step: ifreload ${br0} { ${team0} { ${team_slaves#* } } + ${other0} }, ${br1} { ${vlan1} + ${other1} }"

	cat >"${dir}/ifcfg-${team0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		TEAM_RUNNER='activebackup'
		TEAM_LW_NAME='ethtool'
	EOF
	i=0
	for slave in ${team_slaves#* } ; do
		((i++))
		cat >>"${dir}/ifcfg-${team0}" <<-EOF
			TEAM_PORT_DEVICE_${i}='$slave'
		EOF
	done
	if test "X$team_slave_ifcfg" = "Xyes" ; then
		for slave in ${team_slaves} ; do
			rm -f "${dir}/ifcfg-${slave}"
		done
		for slave in ${team_slaves#* } ; do
			cat >"${dir}/ifcfg-${slave}" <<-EOF
				STARTMODE='hotplug'
				BOOTPROTO='none'
			EOF
		done
	fi

	print_device_config

	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all
	print_bridges

	for slave in ${team_slaves} ; do
		enslaved=no
		for s in ${team_slaves#* } ; do
			test "x$s" = "x$slave" && enslaved=yes
		done
		if test $enslaved = yes ; then
			check_device_has_port "$team0" "$slave"
		else
			check_device_has_not_port "$team0" "$slave"
		fi
	done

	check_device_has_port "$br0" "$team0" "$other0"
	check_device_has_port "$br1" "$vlan1" "$other1"
	check_device_has_link "$vlan1" "$team0"
}

step7()
{
	##
	## re-add first team slave to config (it is **not** a hotplugging test)
	##
	bold "=== $step: ifreload ${br0} { ${team0} { ${team_slaves} } + ${other0} }, ${br1} { ${vlan1} + ${other1} }"

	cat >"${dir}/ifcfg-${team0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		TEAM_RUNNER='activebackup'
		TEAM_LW_NAME='ethtool'
	EOF
	i=0
	for slave in ${team_slaves} ; do
		((i++))
		cat >>"${dir}/ifcfg-${team0}" <<-EOF
			TEAM_PORT_DEVICE_${i}='$slave'
		EOF
	done
	if test "X$team_slave_ifcfg" = "Xyes" ; then
		for slave in ${team_slaves} ; do
			cat >"${dir}/ifcfg-${slave}" <<-EOF
				STARTMODE='hotplug'
				BOOTPROTO='none'
			EOF
		done
	fi

	print_device_config

	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all
	print_bridges

	check_device_has_port "$team0" ${team_slaves}
	check_device_has_port "$br0" "$team0" "$other0"
	check_device_has_port "$br1" "$vlan1" "$other1"
	check_device_has_link "$vlan1" "$team0"
}

step99()
{
	bold "=== $step: cleanup"

	echo "wicked ifdown ${br0} ${br1} ${vlan0} ${vlan1} ${team0} ${team_slaves} ${other0} ${other1}"
	wicked ifdown ${br0} ${br1} ${vlan0} ${vlan1} ${team0} ${team_slaves} ${other0} ${other1}
	echo ""

	for dev in ${br0} ${br1} ${vlan0} ${vlan1} ${team0} ${other0} ${other1} ; do
		ip link delete dev $dev
	done
	rm -f "${dir}/ifcfg-${br1}"
	rm -f "${dir}/ifcfg-${br0}"
	rm -f "${dir}/ifcfg-${vlan0}"
	rm -f "${dir}/ifcfg-${vlan1}"
	rm -f "${dir}/ifcfg-${team0}"
	for slave in ${team_slaves} ; do
		rm -f "${dir}/ifcfg-${slave}"
	done
	echo "-----------------------------------"
	ps  ax | grep /usr/.*/wicked | grep -v grep
	echo "-----------------------------------"
	wicked ifstatus all
	echo "-----------------------------------"
	print_bridges
	echo "-----------------------------------"
	ls -l /var/run/wicked/nanny/
	echo "==================================="
}


. ../../lib/common.sh
