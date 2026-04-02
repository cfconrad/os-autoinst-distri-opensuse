#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/setup.cfg
source $SCRIPT_DIR/lib.sh

REMOTE_IP=${HOST1_IP:?MISSING HOST1_IP}
LOCAL_IP=${HOST2_IP:?MISSING HOST2_IP}
LOCAL_HOSTNAME=${LOCAL_HOSTNAME:-$(hostname)}

zypper in -y openvswitch ovn-host dpdk-tools iperf

systemctl enable --now openvswitch.service
systemctl enable --now ovn-controller.service

firewall-cmd --add-port=6081/udp
firewall-cmd --add-port=3784/udp

setup_network "$CTRL_IFC" "$CTRL_VLAN" "$HOST2_IP"
setup_br_dpdk "$HOST2_DATA_PCI_ID" "$DATA_VLAN" "$HOST2_DATA_IP" "$HUGEPAGES_2M"

ovs-vsctl set open_vswitch . external_ids:ovn-remote=tcp:${REMOTE_IP}:6642
ovs-vsctl set open_vswitch . external_ids:system-id=${LOCAL_HOSTNAME}
ovs-vsctl set open_vswitch . external_ids:ovn-encap-ip=${LOCAL_IP}
ovs-vsctl set open_vswitch . external_ids:ovn-encap-type=geneve
ovs-vsctl get open_vswitch . external_ids

echo "Is the ovn-controller connected?"
cnt=0
while [ "$(ovs-appctl -t /run/ovn/ovn-controller.*.ctl connection-status)" != 'connected' ]; do
  if [ $cnt -gt 10 ]; then
    echo "connection to ovn southbridge failed cnt:$cnt"
    exit 3;
  fi
  echo "Wait for connection to ovn southbridge (cnt:$cnt)"
  ((cnt++))
  sleep 10;
done
echo "  -> CONNECTED"

ovs-vsctl show

ovs-vsctl add-port br-int vif2 -- set Interface vif2 type=internal external_ids:iface-id=port-host2
ip netns add ns2
ip link set vif2 netns ns2
ip netns exec ns2 ip link set vif2 address 02:00:00:00:00:12
ip netns exec ns2 ip addr add $HOST2_TEST_IP/24 dev vif2
ip netns exec ns2 ip link set vif2 up
ip netns exec ns2 ip route add default via $ROUTER2_TEST_IP

echo "ip netns exec ns2 iperf3 -s"

