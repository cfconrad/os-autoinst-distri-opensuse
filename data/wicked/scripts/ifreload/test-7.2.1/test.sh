#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
dummyA="${dummyA:-dummyA}"
dummyB="${dummyB:-dummyB}"
vlanA_id=${vlanA_id:-11}
vlanB_id=${vlanB_id:-12}
vlanA="${vlanA:-vlanA}"
vlanA_ip4="${vlanA_ip4:-198.18.11.10/24}"

test_description()
{
	cat - <<-EOT

	Change VLAN config (ETHERDEVICE) and run ifreload all.

	WARNING: this test fails with wicked <= 0.6.75

	setup:
	   dummyA|dummyB|nicA <-l- vlanA

	EOT
}

step0()
{
	print_test_description

	cat >"${dir}/ifcfg-$dummyA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		DUMMY=yes
	EOF

	cat >"${dir}/ifcfg-$dummyB" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		DUMMY=yes
	EOF

	cat >"${dir}/ifcfg-$nicA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
	EOF


	cat >"${dir}/ifcfg-$vlanA" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='static'
		ETHERDEVICE='$dummyA'
		VLAN_ID='$vlanA_id'
		IPADDR='$vlanA_ip4'
	EOF

	log_device_config "$vlanA" "$dummyA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all

	check_device_is_up "$vlanA"
	check_device_is_up "$dummyA"
	check_device_has_link "$vlanA" "$dummyA"
	check_vlan_id "$vlanA" "$vlanA_id"
}



step1()
{
	bold "=== $step: $vlan / ETHERDEVICE=$dummyB / ifreload all"

	sed -i "/ETHERDEVICE=/c\ETHERDEVICE='$dummyB'" "${dir}/ifcfg-$vlanA"

	log_device_config "$vlanA" "$dummyA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all

	check_device_is_up "$vlanA"
	check_device_is_up "$dummyB"
	check_device_has_link "$vlanA" "$dummyB"
	check_vlan_id "$vlanA" "$vlanA_id"
}

step2()
{
	bold "=== $step: $vlan / ETHERDEVICE=$dummyA / ifreload all"

	sed -i "/ETHERDEVICE=/c\ETHERDEVICE='$dummyA'" "${dir}/ifcfg-$vlanA"

	log_device_config "$vlanA" "$dummyA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all

	check_device_is_up "$vlanA"
	check_device_is_up "$dummyA"
	check_device_has_link "$vlanA" "$dummyA"
	check_vlan_id "$vlanA" "$vlanA_id"
}

step3()
{
	bold "=== $step: $vlan / ETHERDEVICE=$nicA / ifreload all"

	sed -i "/ETHERDEVICE=/c\ETHERDEVICE='$nicA'" "${dir}/ifcfg-$vlanA"

	log_device_config "$vlanA" "$nicA"

	echo "wicked ifreload --dry-run $cfg all"
	wicked ifreload --dry-run $cfg all
	echo ""
	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status all

	check_device_is_up "$vlanA"
	check_device_is_up "$nicA"
	check_device_has_link "$vlanA" "$nicA"
	check_vlan_id "$vlanA" "$vlanA_id"
}

step4()
{
	step1
}

step5()
{
	step2
}

step6()
{
	step3
}

step99()
{
	bold "=== $step: cleanup"

	echo "wicked $wdebug ifdown  $vlanA $dummyA $dummyB"
	wicked $wdebug ifdown  "$vlanA" "$dummyA" "$dummyB"
	echo ""

	rm -f "${dir}/ifcfg-$dummyA"
	rm -f "${dir}/ifcfg-$dummyB"
	rm -f "${dir}/ifcfg-$vlanA"

	check_policy_not_exists "$dummyA"
	check_policy_not_exists "$dummyB"
	check_policy_not_exists "$vlanA"
}

. ../../lib/common.sh
