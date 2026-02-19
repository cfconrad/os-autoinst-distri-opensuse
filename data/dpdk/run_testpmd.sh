#!/bin/bash

NON_INTERACTIVE=false
INTEL_DEVS=""
MODE=fwd
LOGFILE=/tmp/testpmd_output.log
THRESHOLD_TX=1
THRESHOLD_RX=1

while [[ $# -gt 0 ]]; do
  case $1 in
    -y|--non-interactive)
      NON_INTERACTIVE="true"
      shift
      ;;
    -s|--search)
      SEARCH_STRING="$2"
      shift 2
      ;;
    -m|--mode)
      MODE="$2"
      if ! [[ "$MODE" =~ ^(fwd|tx_start)$ ]]; then
        echo "Invalid --mode '$MODE' -- supported tx_start and fwd"
        exit 3;
      fi
      shift 2
      ;;
    -a)
      INTEL_DEVS="$INTEL_DEVS $2"
      NON_INTERACTIVE='true'
      shift 2
      ;;
    -l|--logfile)
      LOGFILE="$2"
      shift 2
      ;;
    --threshold-rx)
      THRESHOLD_RX=$2;
      shift 2
      ;;
    --threshold-tx)
      THRESHOLD_TX=$2;
      shift 2
      ;;
    -*|--*)
      echo "Unknown option $1"
      exit 1
      ;;
    *)
      POSITIONAL_ARGS+=("$1")
      shift # past argument
      ;;
  esac
done

echo "Setting up hugepages..."
# Allocate 512 hugepages of 2MB (1024MB total)
echo 512 > /sys/devices/system/node/node0/hugepages/hugepages-2048kB/nr_hugepages || echo 512 > /proc/sys/vm/nr_hugepages
grep HugePages_ /proc/meminfo

mkdir -p /mnt/huge_2M
if ! mountpoint -q /mnt/huge_2M; then
  mount -t hugetlbfs -o pagesize=2M none /mnt/huge_2M
fi

dpdk-hugepages.py -s

if [ 0$(grep HugePages_Total /proc/meminfo | awk '{ print $2 }') -lt 300 ]; then
  echo "ERROR: hugepages setup failed!"
  exit 3
fi

if [ -z "$INTEL_DEVS" ]; then

  echo "Finding two Intel Ethernet devices..."
  INTEL_DEVS=$(lspci -nn | grep "Ethernet controller \[0200\]: Intel Corporation")
  if [[ -n "$SEARCH_STRING" ]]; then
      INTEL_DEVS=$(echo "$INTEL_DEVS" | grep "$SEARCH_STRING")
  fi
  INTEL_DEVS=$(echo "$INTEL_DEVS" | awk '{print $1}')

  if [ -z "$INTEL_DEVS" ]; then
      echo "ERROR: No Intel Ethernet devices found!"
      exit 1
  fi

  DEV_COUNT=$(echo "$INTEL_DEVS" | wc -l)
  if [ "$DEV_COUNT" -lt 2 ]; then
      echo "ERROR: Found only $DEV_COUNT Intel Ethernet device(s), need at least 2."
      exit 1
  fi
fi

echo "Binding devices to vfio-pci..."
modprobe vfio-pci
for dev in $INTEL_DEVS; do
    if [ "$NON_INTERACTIVE" = false ]; then
        echo ""
        lspci -nn -k -s "$dev"
        echo ""
        echo -n "Do you want to bind device $dev? (y/n) "
        read -n 1 -r REPLY
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            echo "SKIP $dev"
            continue
        fi
    fi
    echo "Binding $dev..."
    dpdk-devbind.py --unbind "$dev" || true
    dpdk-devbind.py --bind vfio-pci "$dev"
    dpdk_testpmd_a="$dpdk_testpmd_a -a $dev"
done

dpdk-devbind.py -s

echo ""
echo "Running dpdk-testpmd and checking for traffic..."
# Determine available cores
CORE_COUNT=$(nproc)
if [ "$CORE_COUNT" -gt 2 ]; then
    CORES="1-2"
else
    CORES="0"
fi

read -ra PCI_PORTS <<< "$INTEL_DEVS"
dpdk_cmd=(dpdk-testpmd -l "$CORES" ${PCI_PORTS[@]/#/-a } -- -i)
echo ">>> ${dpdk_cmd[@]}"

read -ra PCI_PORTS <<< "$INTEL_DEVS"
if [ $MODE == 'fwd' ]; then

  (
    sleep 10;
    echo start;
    sleep 30;
    echo quit
  ) | "${dpdk_cmd[@]}" >$LOGFILE 2>&1

else

  ( sleep 15;
    echo 'set fwd rxonly';
    echo 'start tx_first 10000';
    echo quit
  ) | "${dpdk_cmd[@]}" >$LOGFILE 2>&1

fi

cat $LOGFILE

rx_total=$(grep -A2 'Accumulated forward statistics for all ports' $LOGFILE | grep -oP 'RX-total:\s\d+' | awk '{print $2}')
tx_total=$(grep -A2 'Accumulated forward statistics for all ports' $LOGFILE | grep -oP 'TX-total:\s\d+' | awk '{print $2}')
if [ 0"$rx_total" -lt 0"$THRESHOLD_RX" ] || [ 0"$tx_total" -lt 0"$THRESHOLD_TX" ]; then
    echo ""
    echo "ERROR: traffic threshold not reached:"
    echo "       RX:$rx_total (threshold: $THRESHOLD_RX)"
    echo "       TX:$tx_total (threshold: $THRESHOLD_TX)"
    exit 1
else
    echo ""
    echo "SUCCESS: Traffic detected RX:$rx_total TX:$tx_total"
fi

exit 0
