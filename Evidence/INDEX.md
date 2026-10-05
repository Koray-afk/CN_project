# Evidence index (find anything in 30 seconds)
| Folder | Contents | Demo step |
|---|---|---|
| A-lan | inventory.md, netinfo-raw.txt, ping-all-pairs.txt (six directions), troubleshooting-no-route-to-host.md; topology in ../docs/topology.png | 1, 2 |
| B-dns | dnsmasq-setup-and-tests.txt, dnsmasq-query-log.txt, dns-settings-client-1/2.png (DNS = 10.7.19.109 on two clients) | 3 |
| C-backends | curl-localhost-and-lan.txt, backend-logs.txt (`from=10.7.7.5`) | 5 |
| D-loadbalancer | nginx-test-and-roundrobin.txt, troubleshooting-nginx-port-80-refused.md, old-project-nginx.conf.txt | 5 |
| E-tls | openssl-ca-and-cert.txt, https-no-k.txt (two clients), http1-vs-http2.txt, keychain-always-trust.png, browser-status-json.png, browser-certificate-viewer.png | 4 |
| F-caching | cache-headers-and-304.txt (304 from A and B) | 7 |
| G-wireshark | CN-phase-1.pcapng (43 pkts), CN-phase-1-app-flow.pcapng (39 pkts), curl-verbose.txt, PACKET-WALKTHROUGH.md, 17 screenshots | 6 |
| H-failures | H1..H5 outputs + SUMMARY.md | 8 (+ Phase 2 fault drill) |

Naming note: the guide suggests `phase1-full-flow.pcapng` / `phase1-app-flow.pcapng`; ours are `CN-phase-1.pcapng` / `CN-phase-1-app-flow.pcapng`.
Not done / optional: Wireshark capture of the wrong-port RST (H5); Keychain screenshot from Abhimaan's Mac; labels on the two DNS-settings screenshots.
