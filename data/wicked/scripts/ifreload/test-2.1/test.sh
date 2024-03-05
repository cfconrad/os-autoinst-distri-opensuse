#!/bin/bash
#
# And/remove ports from Bridge and use wicked ifreload to apply
#
# setup:
#
#    eth0,tap0 -m-> br0
#

br0=${br0:-br0}
eth0=${eth0:-eth0}
tap0=${tap0:-tap0}

step0()
{

	bold "=== $step -- Setup configuration"

	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BRIDGE='yes'
		BRIDGE_STP='off'
		BRIDGE_FORWARDDELAY='0'
		BRIDGE_PORTS='${eth0}'
		# ignore br carrier
	EOF

	{
		sed -E '1d;2d;/^([^#])/d;/^$/d' $BASH_SOURCE
		echo ""
		for dev in "$br0" "$eth0" ; do
			echo "== ${dir}/ifcfg-${dev} =="
			cat "${dir}/ifcfg-${dev}"
			echo ""
		done
	} | tee "config-step-${step}.cfg"

	wicked show-config $cfg | tee "config-step-${step}.xml"

}

step1()
{
	bold "=== $step: ifup ${br0} { ${eth0} }"

	echo "wicked $wdebug ifup $cfg all"
	wicked $wdebug ifup $cfg all
	echo ""

	print_device_status "${br0}" "${eth0}" "${tap0}"

	check_device_has_port "$br0" "$eth0"
}

step2()
{
	bold "=== $step: ifreload ${br0} { }"

	# change bridge to not use any port + ifreload
	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BRIDGE='yes'
		BRIDGE_STP='off'
		BRIDGE_FORWARDDELAY='0'
		BRIDGE_PORTS=''
		# ignore br carrier
		LINK_REQUIRED='no'
	EOF

	wicked show-config $cfg | tee "config-step-${step}.xml"

	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status ${br0} ${eth0} ${tap0}

	check_device_has_not_port $br0 $eth0
}

step3()
{
	bold "=== $step: ifreload ${br0} { ${eth0} + ${tap0} }"

	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BRIDGE='yes'
		BRIDGE_STP='off'
		BRIDGE_FORWARDDELAY='0'
		BRIDGE_PORTS='${eth0}'
		# ignore br carrier
		LINK_REQUIRED='no'
	EOF

	wicked show-config $cfg | tee "config-step-${step}.xml"

	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo "ip tuntap add ${tap0} mode tap"
	ip tuntap add ${tap0} mode tap
	echo "ip link set master ${br0} up dev ${tap0}"
	ip link set master ${br0} up dev ${tap0}
	echo ""

	print_device_status ${br0} ${eth0} ${tap0}

	check_device_has_port "$br0" "$eth0" "$tap0"
}

step4()
{
	echo "=== $step: ifreload ${br0} { + ${tap0} }"

	cat >"${dir}/ifcfg-${br0}" <<-EOF
		STARTMODE='auto'
		BOOTPROTO='none'
		BRIDGE='yes'
		BRIDGE_STP='off'
		BRIDGE_FORWARDDELAY='0'
		BRIDGE_PORTS=''
		# ignore br carrier
		LINK_REQUIRED='no'
	EOF

	wicked show-config $cfg | tee "config-step-${step}.xml"

	echo "wicked $wdebug ifreload $cfg all"
	wicked $wdebug ifreload $cfg all
	echo ""

	print_device_status ${br0} ${eth0} ${tap0}

	check_device_has_port "$br0" "$tap0"
	check_device_has_not_port "$br0" "$eth0"
}

step99()
{
	echo "=== $step: cleanup"

	echo "ip link delete $tap0"
	ip link delete $tap0
	echo "rmmod tap &>/dev/null"
	rmmod tap &>/dev/null
	echo ""

	echo "wicked $wdebug ifdown ${br0}"
	wicked $wdebug ifdown ${br0}
	rm -f "${dir}/ifcfg-${br0}"
	rm -f "${dir}/ifcfg-${eth0}"

	print_device_status all
	check_device_is_down "$br0"
	check_device_is_down "$eth0"
}

. ../../lib/common.sh
