#!/bin/bash
#
# VLAN on Bond of physical interfaces
#
# setup:
#
#    eth1,eth2   -m->    bond0   <-l-    bond0.11
#                                <-l-    bond0.12
#

eth0="${eth0:-eth0}"
eth1="${eth1:-eth1}"

bond0="${bond0:-bond0}"
bond0_ip4="${bond0_ip4:-198.18.10.10/24}"

vlan0_id=11
vlan0="${vlan0:-$bond0.$vlan0_id}"
vlan0_ip4="${vlan0_ip4:-198.18.11.10/24}"

vlan1_id=12
vlan1="${vlan1:-$bond0.$vlan1_id}"
vlan1_ip4="${vlan1_ip4:-198.18.12.10/24}"

step0()
{
	bold "=== $step -- Setup configuration"

	cat >"${dir}/ifcfg-${eth0}" <<-EOF
		STARTMODE='hotplug'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-${eth1}" <<-EOF
		STARTMODE='hotplug'
		BOOTPROTO='none'
	EOF

	cat >"${dir}/ifcfg-${bond0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ZONE=trusted
		${bond0_ip4:+IPADDR='${bond0_ip4}'}
		BONDING_MASTER=yes
		BONDING_MODULE_OPTS='mode=active-backup miimon=100'
		BONDING_SLAVE_0="$eth0"
		BONDING_SLAVE_1="$eth1"
	EOF

	cat >"${dir}/ifcfg-${vlan0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='${bond0}'
		VLAN_ID=${vlan0_id}
		${vlan0_ip4:+IPADDR='${vlan0_ip4}'}
	EOF

	cat >"${dir}/ifcfg-${vlan1}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='${bond0}'
		VLAN_ID=${vlan1_id}
		${vlan1_ip4:+IPADDR='${vlan1_ip4}'}
	EOF

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' "$BASH_SOURCE"
		echo ""
		for dev in "$eth0" "$eth1" "$bond0" "$vlan0" "$vlan1"; do
			echo "== ${dir}/ifcfg-${dev} =="
			cat "${dir}/ifcfg-${dev}"
			echo ""
		done
	} | tee "config-step-${step}.cfg"
	echo "== wicked show-config"
	wicked show-config | tee "config-step-${step}.xml"
}

step1()
{
	bold "=== step $step: ifup $eth0"

	echo "# wicked $wdebug ifup $cfg $eth0"
	wicked $wdebug ifup $cfg "$eth0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$vlan1"

	check_device_is_up "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_down "$vlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown $eth0"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown "$eth0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$vlan1"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_down "$vlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step3()
{
	bold "=== step $step: ifdown $bond0"

	echo "# wicked $wdebug ifdown $bond0"
	wicked $wdebug ifdown "$bond0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$vlan1"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_down "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_down "$vlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_all=step3

step4()
{
	bold "=== step $step: ifup $eth1"

	echo "# wicked $wdebug ifup $cfg $eth1"
	wicked $wdebug ifup $cfg "$eth1"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$vlan1"

	check_device_is_down "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_down "$vlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step5()
{
	bold "=== step $step: ifdown $eth0"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown "$eth0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$vlan1"

	check_device_is_down "$eth0"
	check_device_is_down "$eth0"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_down "$vlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step6()
{
	$ifdown_all
}

step7()
{
	bold "=== step $step: ifup $bond0"

	echo "# wicked $wdebug ifup $cfg $bond0"
	wicked $wdebug ifup $cfg "$bond0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$vlan1"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_down "$vlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step8()
{
	$ifdown_all
}

step9()
{
	bold "=== step $step: ifup $vlan0"

	echo "# wicked $wdebug ifup $cfg $vlan0"
	wicked $wdebug ifup $cfg "$vlan0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$vlan1"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"
	check_device_is_down "$vlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step10()
{
	bold "=== step $step: ifup $vlan1"

	echo "# wicked $wdebug ifup $cfg $vlan1"
	wicked $wdebug ifup $cfg "$vlan1"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$vlan1"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"
	check_device_is_up "$vlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step11()
{
	bold "=== step $step: ifdown $eth0"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown "$eth0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$vlan1"

	check_device_is_down "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_up "$vlan0"
	check_device_is_up "$vlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step12()
{
	bold "=== step $step: ifdown $vlan0"

	echo "# wicked $wdebug ifdown $vlan0"
	wicked $wdebug ifdown "$vlan0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$vlan1"

	check_device_is_down "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_up "$vlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step13()
{
	bold "=== step $step: ifdown $vlan1"

	echo "# wicked $wdebug ifdown $vlan1"
	wicked $wdebug ifdown "$vlan1"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$vlan1"

	check_device_is_down "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_down "$vlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step14()
{
	bold "=== step $step: ifdown $eth1"

	echo "# wicked $wdebug ifdown $eth1"
	wicked $wdebug ifdown "$eth1"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0" "$vlan0" "$vlan1"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$bond0"
	check_device_is_down "$vlan0"
	check_device_is_down "$vlan1"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step15()
{
	$ifdown_all
}

step99()
{
	bold "=== step $step: cleanup"

	for dev in "$vlan1" "$vlan0" "$eth0" "$eth1" "$bond0"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../../lib/common.sh
