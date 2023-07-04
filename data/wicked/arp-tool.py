#!/usr/bin/python3
import scapy.all as scapy
import ipaddress
import time
import argparse
import sys


def defend(interface, network, count):
    myMAC = scapy.get_if_hwaddr(interface)
    counter = 0
    ipaddress.ip_network(network)

    def handle_packet(packet, ctx):
        if packet[scapy.ARP].op != 1: 
            return

        if ipaddress.ip_address(packet.pdst) not in ipaddress.ip_network(ctx['net']):
            print("IGN: Ignore incomming arp request with pdst=" + packet.pdst)
            return

        if str(packet.src) in ctx['ignore_src']:
            print("IGN: Ignore incomming arp request by MAC with src=" + packet.src)
            return

        print("RCV: " + packet.__repr__())
        reply = scapy.ARP(op=2,  hwsrc=myMAC, psrc=packet.pdst, hwdst=packet[scapy.ARP].hwsrc, pdst="0.0.0.0")
        reply = scapy.Ether(dst="ff:ff:ff:ff:ff:ff", src=myMAC) / reply

        scapy.sendp(reply, iface=ctx['ifc'], verbose=False)
        print("SND: " + reply.__repr__())
        print("");

        ctx['pkt_count'] = ctx['pkt_count'] + 1
        if(ctx['max_count'] > 0 and ctx['pkt_count'] >= ctx['max_count']):
                sys.exit(0)
        return

    my_macs=list(filter(lambda x: x != '00:00:00:00:00:00', [scapy.get_if_hwaddr(i) for i in scapy.get_if_list()]))
    ctx = dict( pkt_count = 0, max_count = count, net = network, ifc = interface, ignore_src = my_macs);
    # Sniff for ARP packets. Run handle_packet() on each one
    scapy.sniff(filter="arp",prn=lambda x: handle_packet(x,ctx), iface=interface)


if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='arp-tool', description='Test utility to for various ARP fake tasks')
    subparsers = parser.add_subparsers(dest='tool')

    defend_arg = subparsers.add_parser('defend', help='This tool can be used to send on each "HOW-HAS-IP" request a claim RESPONSE. Used to fake address in use cases.')
    defend_arg.add_argument('interface', help="The network interface where we listen and send the ARP reply")
    defend_arg.add_argument('network', default="169.254.0.0/16", help="The network which we asume to claim for us!")
    defend_arg.add_argument('--count', default=1, type=int, help="The number fakes we will send out")

    kwargs = vars(parser.parse_args())
    tool = kwargs.pop('tool')
    if (tool is None):
        print("ERROR missing tool parameter")
        parser.print_help()
        sys.exit(2)
    globals()[tool](**kwargs)

