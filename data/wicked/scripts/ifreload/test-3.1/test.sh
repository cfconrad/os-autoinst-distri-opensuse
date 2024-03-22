#!/bin/bash
#
#
#
# setup:
#     eth0,eth1 -m-> bond0 <-l- vlan0 -m-> br1
#                          <-l- vlan1
#                          -m-> br0
#

# The following variables are options which test the same scenario with
# slightly different setup

. ../../lib/common_pre.sh

bond0_slave_ifcfg=${bond0_slave_ifcfg:-yes}  # options: yes, no
other_call=${other_call:-link}               # options: link, tuntap
other_type=${other_type:-tap}
other1="${other1:-tap40}"
other2="${other2:-tap44}"

eth0=${eth0:-eth0}
eth1=${eth1:-eth1}

bond0="${bond0:-bond0}"
bond0_options="${bond0_options:-mode=active-backup miimon=100}"
bond0_slaves="$eth0 $eth1"

vlan0_id="${vlan0_id:-10}"
vlan0="${bond0}.${vlan0_id}"

vlan1_id="${vlan1_id:-20}"
vlan1="${bond0}.${vlan1_id}"

br0=${br0:-br0}
br1=${br1:-br1}

dummy0=${dummy0:-dummy0}

all_interfaces="$bond0 $other1 $other2 $vlan0 $vlan1 $br0 $br1 $dummy0"

other_call="tuntap"
other_type="tap"

step0()
{
	bold "=== $step -- Setup configuration"
	echo ""

	cat >"${dir}/ifcfg-${bond0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BONDING_MASTER='yes'
		BONDING_MODULE_OPTS='${bond0_options}'
	EOF
	i=0
	for slave in ${bond0_slaves} ; do
		((i++))
		cat >>"${dir}/ifcfg-${bond0}" <<-EOF
			BONDING_SLAVE_${i}='$slave'
		EOF
	done
	if test "X$bond0_slave_ifcfg" = "Xyes" ; then
		for slave in ${bond0_slaves} ; do
			cat >"${dir}/ifcfg-${slave}" <<-EOF
				STARTMODE='hotplug'
				BOOTPROTO='none'
			EOF
		done
	fi

	cat >"${dir}/ifcfg-${vlan1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${bond0}'
		#VLAN_ID='${vlan1_id}'
	EOF

	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${bond0}'
	EOF

	cat >"${dir}/ifcfg-${br1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${vlan1}'
	EOF

	print_test_description
	log_device_config $all_interfaces
}

step1()
{
	bold "=== $step: ifreload ${br0} { ${bond0} { ${bond0_slaves} } + ${other1} }, ${br1} { ${vlan1} + ${other2} }"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port $bond0 $bond0_slaves
	check_device_has_not_port $br0 $vlan0
	check_device_has_port $br0 $bond0
	check_device_has_port $br1 $vlan1

	case ${other_call} in
		link)
			echo "ip link add ${other1} type ${other_type}"
			ip link add ${other1} type ${other_type}
			echo "ip link add ${other2} type ${other_type}"
			ip link add ${other2} type ${other_type}
			;;
		tuntap)
			echo "ip tuntap add ${other1} mode ${other_type}"
			ip tuntap add ${other1} mode ${other_type}
			echo "ip tuntap add ${other2} mode ${other_type}"
			ip tuntap add ${other2} mode ${other_type}
			;;
	esac
	echo "ip link set master ${br0} up dev ${other1}"
	ip link set master ${br0} up dev ${other1} || ((err++))
	echo "ip link set master ${br1} up dev ${other2}"
	ip link set master ${br1} up dev ${other2} || ((err++))

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port $bond0 $bond0_slaves
	check_device_has_port $br0 $bond0
	check_device_has_not_port $br0 $vlan0

	check_device_has_port $br0 $other1
	check_device_has_port $br1 $vlan1
	check_device_has_port $br1 $other2
}

step2()
{
        ##
        ## setup bond vlan1 instead of bond as bridge1 port
        ##

	bold "=== $step: ifreload ${bond0} { ${bond0_slaves} }, ${br0} { ${vlan0} + ${other1} }, ${br1} { ${vlan1} + ${other2} }"

	cat >"${dir}/ifcfg-${vlan0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${bond0}'
		#VLAN_ID='${vlan0_id}'
	EOF

	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${vlan0}'
	EOF

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port "$bond0" $bond0_slaves
	check_device_has_not_port "$br0" "$bond0"
	check_device_has_port "$br0" "$vlan0" "$other1"
	check_device_has_port "$br1" "$vlan1" "$other2"
}

step3()
{
	##
	## remove bond vlan1 from br0 ports, but keep vlan1 ifcfg file
	##
	bold "=== $step: ifreload ${bond0} { ${bond0_slaves} }, ${br0} { + ${other1} }, ${br1} { ${vlan1} + ${other2} }, ${vlan0}"

	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS=''
	EOF

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port "$bond0" $bond0_slaves
	check_device_has_not_port "$br0" "$bond0"
	check_device_has_not_port "$br0" "$vlan0"
	check_device_has_port "$br0" "$other1"
	check_device_has_port "$br1" "$vlan1" "$other2"
}

step4()
{
	##
	## cleanup unenslaved bond vlan1
	##
	bold "=== $step: ifreload ${bond0} { ${bond0_slaves} }, ${br0} { + ${other1} }, ${br1} { ${vlan1} + ${other2} }"

	rm -f "${dir}/ifcfg-${vlan0}"

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port "$bond0" $bond0_slaves
	check_device_has_not_port "$br0" "$bond0" "$vlan0"
	check_device_has_port "$br0" "$other1"
	check_device_has_port "$br1" "$vlan1" "$other2"
}

step5()
{
	##
	## create bond vlan1 and enslave as br0 port again
	##
	echo ""
	echo "=== $step: ifreload ${bond0} { ${bond0_slaves} }, ${br0} { ${vlan0} + ${other1} }, ${br1} { ${vlan1} + ${other2} }"

	cat >"${dir}/ifcfg-${vlan0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		ETHERDEVICE='${bond0}'
		#VLAN_ID='${vlan0_id}'
	EOF

	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${vlan0}'
	EOF

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port "$bond0" $bond0_slaves
	check_device_has_not_port "$br0" "$bond0"
	check_device_has_port "$br0" "$other1" "$vlan0"
	check_device_has_port "$br1" "$vlan1" "$other2"
	check_device_is_link "$vlan0" "$bond0"
}

step5()
{
	##
	## replace bond vlan1 br0 port with bond and delete bond vlan1 again
	##
	bold "=== $step: ifreload ${bond0} { ${bond0_slaves} }, ${br0} { ${bond0} + ${other1} }, ${br1} { ${vlan1} + ${other2} }"

	rm -f "${dir}/ifcfg-${vlan0}"
	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		BRIDGE='yes'
		BRIDGE_PORTS='${bond0}'
	EOF

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port "$bond0" $bond0_slaves
	check_device_has_not_port "$br0" "$vlan0"
	check_device_has_port "$br0" "$other1" "$bond0"
	check_device_has_port "$br1" "$vlan1" "$other2"
}

step6()
{
	##
	## removal of first bond slave from config (it is **not** a hotplugging test)
	##
	bold "=== $step: ifreload ${bond0} { ${bond0_slaves#* } }, ${br0} { ${bond0} + ${other1} }, ${br1} { ${vlan1} + ${other2} }"

	cat > "${dir}/ifcfg-${bond0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BONDING_MASTER='yes'
		BONDING_MODULE_OPTS='${bond0_options}'
	EOF
	i=0
	for slave in ${bond0_slaves#* } ; do
		((i++))
		cat >>"${dir}/ifcfg-${bond0}" <<-EOF
			BONDING_SLAVE_${i}='$slave'
		EOF
	done
	if test "X$bond0_slave_ifcfg" = "Xyes" ; then
		for slave in ${bond0_slaves} ; do
			rm -f "${dir}/ifcfg-${slave}"
		done
		for slave in ${bond0_slaves#* } ; do
			cat >"${dir}/ifcfg-${slave}" <<-EOF
				STARTMODE='hotplug'
				BOOTPROTO='none'
			EOF
		done
	fi

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""


	print_device_status $all_interfaces
	print_bridges

	for slave in ${bond0_slaves} ; do
		enslaved=no
		for s in ${bond0_slaves#* } ; do
			test "x$s" = "x$slave" && enslaved=yes
		done
		if test $enslaved = yes ; then
			check_device_has_port "$bond0" "$slave"
		else
			check_device_has_not_port "$bond0" "$slave"
		fi
	done

	check_device_has_port "$br0" "$other1" "$bond0"
	check_device_has_port "$br1" "$other2" "$vlan1"
}

step7()
{
	##
	## re-add first bond slave to config (it is **not** a hotplugging test)
	##
	bold "=== $step: ifreload ${bond0} { ${bond0_slaves} }, ${br0} { ${bond0} + ${other1} }, ${br1} { ${vlan1} + ${other2} }"

	cat >"${dir}/ifcfg-${bond0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BONDING_MASTER='yes'
		BONDING_MODULE_OPTS='${bond0_options}'
	EOF
	i=0
	for slave in ${bond0_slaves} ; do
		((i++))
		cat >>"${dir}/ifcfg-${bond0}" <<-EOF
			BONDING_SLAVE_${i}='$slave'
		EOF
	done
	if test "X$bond0_slave_ifcfg" = "Xyes" ; then
		for slave in ${bond0_slaves} ; do
			cat >"${dir}/ifcfg-${slave}" <<-EOF
				STARTMODE='hotplug'
				BOOTPROTO='none'
			EOF
		done
	fi

	log_device_config $all_interfaces

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status $all_interfaces
	print_bridges

	check_device_has_port "$bond0" $bond0_slaves
	check_device_has_not_port "$br0" "$vlan0"
	check_device_has_port "$br0" "$bond0" "$other1"
	check_device_has_port "$br1" "$vlan1" "$other2"
}

step99()
{
	bold "=== $step: cleanup"

	wicked $wdebug ifdown ${br0} ${br1} ${vlan0} ${vlan1} ${bond0} ${bond0_slaves} ${other1} ${other2}
	for dev in ${br0} ${br1} ${vlan0} ${vlan1} ${bond0} ${other1} ${other2} ; do
		ip link delete dev $dev
	done
	rm -f "${dir}/ifcfg-${br1}"
	rm -f "${dir}/ifcfg-${br0}"
	rm -f "${dir}/ifcfg-${vlan0}"
	rm -f "${dir}/ifcfg-${vlan1}"
	rm -f "${dir}/ifcfg-${bond0}"
	for slave in ${bond0_slaves} ; do
		rm -f "${dir}/ifcfg-${slave}"
	done
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
