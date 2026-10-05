# Troubleshooting note 1 - `No route to host` toward Kevish (first ping round)

Symptom (Bhawana -> Kevish and Abhimaan -> Kevish), while Kevish -> both and Bhawana <-> Abhimaan worked:
```
ping -c 3 10.7.21.121
PING 10.7.21.121 (10.7.21.121): 56 data bytes
ping: sendto: No route to host
ping: sendto: No route to host
Request timeout for icmp_seq 0
ping: sendto: No route to host
Request timeout for icmp_seq 1
--- 10.7.21.121 ping statistics ---
3 packets transmitted, 0 packets received, 100.0% packet loss
```
Layer-by-layer reasoning: `No route to host` on macOS = the sender's ARP request for the target IP got no answer (a firewall would
give a plain timeout). Other pairs worked, so Wi-Fi isolation was ruled out; Local Network permission was ruled out because the same
Terminal pinged other Macs fine.
Fix: Wi-Fi off/on (reconnect) on Kevish's Mac refreshed the ARP state; all six directions then passed (see ping-all-pairs.txt).
Lesson: check ARP/L2 first when only one host is unreachable from several peers.
