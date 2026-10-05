# Task A - LAN inventory (team07, 3 Macs, network `Rishihood_Learner`, 4 Oct 2026)

| Owner | Role | IP | Mask | Gateway | Iface | MAC (Private Wi-Fi = Fixed) |
|---|---|---|---|---|---|---|
| Kevish(Mac 3) | Backends A (3001) + B (3002), test client, Wireshark | 10.7.21.121 | 255.255.224.0 (/19) | 10.7.0.1 | en0 | ba:53:b8:ee:a3:2f |
| Bhawana | Private DNS (dnsmasq, UDP 53) | 10.7.19.109 | 255.255.224.0 (/19) | 10.7.0.1 | en0 | 1a:83:7b:75:38:a9 |
| Abhimaan | Edge: nginx reverse proxy, TLS, load balancer (TCP 80/443) | 10.7.7.5 | 255.255.224.0 (/19) | 10.7.0.1 | en0 | 72:94:6f:7b:aa:c9 |

/19 = 10.7.0.0 - 10.7.31.255; all three IPs and the gateway are inside it => same LAN segment.
Clients using our DNS: Kevish and Abhimaan.
MAC addresses were re-checked later in the session (before and after Wi-Fi reconnect/laptop restart) and were unchanged.
