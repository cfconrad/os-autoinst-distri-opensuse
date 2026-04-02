#!/bin/bash
SCRIPT_DIR=$( cd -- "$( dirname -- "${BASH_SOURCE[0]}" )" &> /dev/null && pwd )
source $SCRIPT_DIR/setup.cfg
source $SCRIPT_DIR/lib.sh

REMOTE_IP1=${HOST2_IP:?MISSING HOST2_IP}
REMOTE_IP2=${HOST3_IP:?MISSING HOST3_IP}
LOCAL_IP=${HOST1_IP:?MISSING HOST1_IP}
LOCAL_HOSTNAME=${LOCAL_HOSTNAME:-$(hostname)}

zypper in -y openvswitch ovn-host ovn-central dpdk-tools iperf

systemctl enable --now openvswitch.service
systemctl enable --now ovn-controller.service
systemctl enable --now ovn-northd

firewall-cmd --add-port=6081/udp
firewall-cmd --add-port=3784/udp
firewall-cmd --add-port=6642/tcp

setup_network "$CTRL_ETH" "$CTRL_VLAN" "$HOST1_IP"
setup_br_dpdk "$HOST1_DATA_PCI_ID" "$DATA_VLAN" "$HOST1_DATA_IP" "$HUGEPAGES_2M"

echo "Allow connection to northd from everywhere"
ovn-sbctl set-connection ptcp:6642:0.0.0.0

ovs-vsctl set open_vswitch . external_ids:ovn-remote=tcp:${LOCAL_IP}:6642
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

# Create Switches and Router
ovn-nbctl ls-add ls1
ovn-nbctl ls-add ls2
ovn-nbctl ls-add ls3
ovn-nbctl lr-add lr1

# Connect LS1 to LR1
ovn-nbctl lrp-add lr1 lr1-ls1 00:00:00:00:01:01 $ROUTER1_TEST_IP/24
ovn-nbctl lsp-add ls1 ls1-lr1
ovn-nbctl lsp-set-type ls1-lr1 router
ovn-nbctl lsp-set-addresses ls1-lr1 router
ovn-nbctl lsp-set-options ls1-lr1 router-port=lr1-ls1

# Connect LS2 to LR1
ovn-nbctl lrp-add lr1 lr1-ls2 00:00:00:00:01:02 $ROUTER2_TEST_IP/24
ovn-nbctl lsp-add ls2 ls2-lr1
ovn-nbctl lsp-set-type ls2-lr1 router
ovn-nbctl lsp-set-addresses ls2-lr1 router
ovn-nbctl lsp-set-options ls2-lr1 router-port=lr1-ls2

# Connect LS3 to LR1
ovn-nbctl lrp-add lr1 lr1-ls3 00:00:00:00:01:03 $ROUTER3_TEST_IP/24
ovn-nbctl lsp-add ls3 ls3-lr1
ovn-nbctl lsp-set-type ls3-lr1 router
ovn-nbctl lsp-set-addresses ls3-lr1 router
ovn-nbctl lsp-set-options ls3-lr1 router-port=lr1-ls3

# Create Logical Ports for our test interfaces
ovn-nbctl lsp-add ls1 port-host1
ovn-nbctl lsp-set-addresses port-host1 "02:00:00:00:00:11 $HOST1_TEST_IP"

ovn-nbctl lsp-add ls2 port-host2
ovn-nbctl lsp-set-addresses port-host2 "02:00:00:00:00:12 $HOST2_TEST_IP"

ovn-nbctl lsp-add ls3 port-host3
ovn-nbctl lsp-set-addresses port-host3 "02:00:00:00:00:13 $HOST3_TEST_IP"

ovn-nbctl show

ovs-vsctl add-port br-int vif1 -- set Interface vif1 type=internal external_ids:iface-id=port-host1
ip netns add ns1
ip link set vif1 netns ns1
ip netns exec ns1 ip link set vif1 address 02:00:00:00:00:11
ip netns exec ns1 ip addr add $HOST1_TEST_IP/24 dev vif1
ip netns exec ns1 ip link set vif1 up
ip netns exec ns1 ip route add default via $ROUTER1_TEST_IP
ip netns exec ns1 ip a s

# Test traffic to Host 2 (crossing LS1 -> LR1 -> LS2 over DPDK Geneve)
echo "ip netns exec ns1 iperf3 -c $HOST2_TEST_IP"

# Test traffic to Host 3 (crossing LS1 -> LR1 -> LS3 over DPDK Geneve)
echo "ip netns exec ns1 iperf3 -c $HOST3_TEST_IP"
