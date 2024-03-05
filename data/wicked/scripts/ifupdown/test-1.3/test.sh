#!/bin/bash
#
# Bond (master) on physical interfaces
#
# setup:
#
#    eth1,eth2   -m->    bond0
#

eth0="${eth0:-eth0}"
eth1="${eth1:-eth1}"

bond0="${bond0:-bond0}"
bond0_ip4="${bond0_ip4:-198.18.5.1/24}"

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

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' $BASH_SOURCE
		echo ""
		for dev in "$eth0" "$eth1" "$bond0"; do
			echo "== ${dir}/ifcfg-${dev} =="
			cat "${dir}/ifcfg-${dev}"
			echo ""
		done
	} | tee "config-step-${step}.cfg"
	wicked show-config | tee "config-step-${step}.xml"
}

step1()
{
	bold "=== step $step: ifup $eth0"

	echo "# wicked $wdebug ifup $cfg $eth0"
	wicked $wdebug ifup $cfg $eth0
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0"

	check_device_is_up "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$bond0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step2()
{
	bold "=== step $step: ifdown $eth0 $eth1 $bond0"

	echo "# wicked $wdebug ifdown $eth0 $eth1 $bond0"
	wicked $wdebug ifdown "$eth0" "$eth1" "$bond0"
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_down "$bond0"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifdown_all=step2

step3()
{
	bold "=== step $step: ifup $eth1"

	echo "# wicked $wdebug ifup $cfg $eth1"
	wicked $wdebug ifup $cfg $eth1
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0"

	check_device_is_down "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step4()
{
	$ifdown_all
}

step5()
{
	bold "=== step $step: ifup $bond0"

	echo "# wicked $wdebug ifup $cfg $bond0"
	wicked $wdebug ifup $cfg $bond0
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0"

	check_device_is_up "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"

	echo ""
	echo "=== step $step: finished with $err errors"
}
ifup_all=step5

step6()
{
	bold "=== step $step: down $eth0"

	echo "# wicked $wdebug ifdown $eth0"
	wicked $wdebug ifdown $eth0
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0"

	check_device_is_down "$eth0"
	check_device_is_up "$eth1"
	check_device_is_up "$bond0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step7()
{
	$ifup_all
}

step8()
{
	bold "=== step $step: down $eth1"

	echo "# wicked $wdebug ifdown $eth1"
	wicked $wdebug ifdown $eth1
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0"

	check_device_is_up "$eth0"
	check_device_is_down "$eth1"
	check_device_is_up "$bond0"

	echo ""
	echo "=== step $step: finished with $err errors"
}

step9()
{
	$ifup_all
}

step10()
{
	bold "=== step $step: down $bond0"

	echo "# wicked $wdebug ifdown $bond0"
	wicked $wdebug ifdown $bond0
	echo ""

	print_device_status "$eth0" "$eth1" "$bond0"

	check_device_is_down "$eth0"
	check_device_is_down "$eth1"
	check_device_is_down "$bond0"

	echo ""
	echo "=== step $step: finished with $err errors"
}


step99()
{
	bold "=== step $step: cleanup"

	for dev in "$bond0" "$eth0" "$eth1"; do
		echo "# wicked $wdebug ifdown $dev"
		wicked $wdebug ifdown $dev
		rm -rf "${dir}/ifcfg-${dev}"

		check_device_is_down "$dev"
		check_policy_not_exists "$dev"
	done
}

. ../../lib/common.sh
