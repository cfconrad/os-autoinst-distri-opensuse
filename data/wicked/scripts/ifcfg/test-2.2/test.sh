#!/bin/bash


nicA="${nicA:?Missing "nicA" parameter, this should be set to the first physical ethernet adapter (e.g. nicA=eth1)}"
vlanA_id=${vlanA_id:-10}
vlanA_ip4=${vlanA_ip:-198.18.11.10/24}
vlanA=${vlanA:-$nicA.$vlanA_id}
sysctl_conf=${sysctl_conf:-/etc/sysctl.conf}

test_description()
{
	cat - <<-EOT

	Reproducer test for bsc#1213203

	EOT
}

check_sysctl()
{
	local name=$1
	local value=$2

	if ! sysctl "$name" >& /dev/null; then
		red "ERROR: sysctl $name not found"
		((err++))
		return
	fi

	got="$(sysctl "$name" | awk '{print $3}')"
	if [ "$got" == "$value" ] ; then
		echo "WORKS: sysctl $name has expected value $got"
	else
		red "ERROR: sysctl $name has value:$got expeded:$value"
		((err++))
	fi
}

step0()
{
	bold "=== $step -- Setup configuration"

	if test -e "$dir/ifcfg-$nicA"; then
		((err++))
		red "ERROR: this test expect no ifcfg-$nicA config"
		exit 2
	fi

	if test -e "$sysctl_conf"; then
		((err++))
		red "ERROR: this test expect no $sysctl_conf"
		exit 2
	fi

	cat > "$dir/ifcfg-$vlanA" <<-EOT
		BOOTPROTO='static'
		STARTMODE='auto'
		ETHERDEVICE='${nicA}'
		IPADDR='${vlanA_ip4}'
	EOT

	log_device_config "$nicA" "$vlanA"

	echo "wicked $wdebug ifup $cfg $nicA $vlanA"
	wicked $wdebug ifup $cfg "$nicA" "$vlanA"
	echo ""

	check_device_is_up "$nicA"
	check_device_is_up "$vlanA"
	check_device_has_link "$vlanA" "$link"

	check_sysctl "net/ipv6/conf/${nicA}/disable_ipv6" "0"
	check_sysctl "net/ipv6/conf/${vlanA}/disable_ipv6" "0"
}

step1()
{
	bold "=== step $step: overwrite runtime config on ifup"

	echo "# set disable_ipv6 in /etc/sysctl.conf"
	echo 'echo "net/ipv6/conf/'"${nicA}"'/disable_ipv6 = 0" > /etc/sysctl.conf'
	echo "net/ipv6/conf/${nicA}/disable_ipv6 = 0" > /etc/sysctl.conf
	echo ""
	log_device_config "$nicA" "$vlanA"

	echo "wicked ifdown $vlanA"
	wicked ifdown "$vlanA"
	echo "wicked ifdown $nicA"
	wicked ifdown "$nicA"
	echo ""

	echo "sysctl -w net/ipv6/conf/${nicA}/disable_ipv6=1"
	sysctl -w "net/ipv6/conf/${nicA}/disable_ipv6=1"
	echo ""

	echo "wicked $wdebug ifup $vlanA"
	wicked $wdebug ifup $cfg "$vlanA"
	echo ""

	check_sysctl "net/ipv6/conf/${nicA}/disable_ipv6" "0"
	check_sysctl "net/ipv6/conf/${vlanA}/disable_ipv6" "0"

	# Second run shouldn't have a different output
	echo "wicked $wdebug ifup $vlanA"
	wicked $wdebug ifup $cfg "$vlanA"
	echo ""

	check_device_is_up "$vlanA"
	check_sysctl "net/ipv6/conf/${nicA}/disable_ipv6" "0"
	check_sysctl "net/ipv6/conf/${vlanA}/disable_ipv6" "0"
}

step99()
{
	bold "=== step $step: cleanup"

	wicked $wdebug ifdown "$vlanA"
	wicked $wdebug ifdown "$nicA"

	sysctl -w "net/ipv6/conf/${nicA}/disable_ipv6=0"

	rm -f "$dir/ifcfg-$vlanA"
	rm -f "$sysctl_conf"
	sysctl --system
}

. ../../lib/common.sh
