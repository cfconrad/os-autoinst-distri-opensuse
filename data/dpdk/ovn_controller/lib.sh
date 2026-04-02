#!/bin/bash



function setup_br_dpdk()
{
  local pci_id=${1:?Missing PCI_ID parameter}
  local vlan=${2:?Missing DATA_VLAN parameter}
  local ipaddr=${3:?Missing DATA_IP parameter}
  local num_hugepages_2m=${4:-512}

  echo "Setting up hugepages..."
  echo $num_hugepages_2m > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages ||
    echo $num_hugepages_2m > /proc/sys/vm/nr_hugepages
  grep HugePages_ /proc/meminfo

  mkdir -p /mnt/huge_2M
  if ! mountpoint -q /mnt/huge_2M; then
    mount -t hugetlbfs -o pagesize=2M none /mnt/huge_2M
  fi

  modprobe vfio-pci
  dpdk-devbind.py --bind=vfio-pci $pci_id

  echo "Change owerner of /dev/vfio/[0-9]* to openvswitch"
  chown openvswitch:openvswitch /dev/vfio/[0-9]*

  echo "Enable DPDK"
  ovs-vsctl set Open_vSwitch . other_config:dpdk-init=true
  systemctl restart openvswitch

  echo "Create a netdev bridge"
  ovs-vsctl add-br br-dpdk -- set bridge br-dpdk datapath_type=netdev

  echo "Add the DPDK port"
  ovs-vsctl add-port br-dpdk dpdk0 -- \
    set Interface dpdk0 type=dpdk options:dpdk-devargs=$pci_id
  ovs-vsctl add-port br-dpdk vlan$vlan tag=$vlan -- \
    set Interface vlan$vlan type=internal

  ip addr add $ipaddr/24 dev vlan$vlan
  ip link set vlan$vlan up
}

function setup_network()
{
  local ifc=${1:?Missing parameter interface name}
  local vlan=${2:?Missing parameter vlan id}
  local ip=${3:?Missing parameter ip address}
  if systemctl is-active wickedd; then
    cfg="/etc/sysconfig/network/ifcfg-vlan$vlan"
    cat > "$cfg" << EOT
STARTMODE=auto
ETHERDEVICE=$ifc
IPADDR=$ip/24
ZONE=public
EOT
    wicked ifreload all
    cat "$cfg"
  else
    conname="$ifc.$vlan"
    nmcli con del "$conname"
    echo "nmcli con add type vlan con-name $conname \
      dev $ifc id $vlan ipv4.addresses $ip/24 ipv4.method manual"
    nmcli con add type vlan con-name "$conname" \
      dev "$ifc" id "$vlan" ipv4.addresses "$ip/24" ipv4.method manual
    nmcli con up "$conname"

    nmcli c show
  fi
}
