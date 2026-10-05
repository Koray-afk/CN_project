# Viva cheat sheet - every member must be able to explain every part

- **DNS vs connection:** DNS only finds the IP (UDP 53); TCP/TLS to that IP is a later, separate step (H1, H2).
- **Why `.test`:** reserved for private use; public DNS answers NXDOMAIN from the root zone (H1). `.local` is mDNS.
- **TTL 64 / MACs:** all pings ttl=64 and frames address the peer's own MAC (frame 5/7 ARP), so one LAN segment, no router hop.
- **Why 3 Macs work:** roles are separate processes/ports; Kevish hosts A:3001 and B:3002 on one IP, the edge picks the port.
- **TLS termination:** TLS ends at nginx; edge -> backend is plain HTTP (frame 27). Backend sees `from=10.7.7.5`; client IP is in X-Forwarded-For.
- **Client never knows backend IPs:** it only knows the name, DNS points at the edge, the edge chooses the backend.
- **TLS 1.2 handshake:** Client Hello (SNI, ALPN) -> Server Hello -> Certificate -> Server Key Exchange -> Server Hello Done -> Client Key Exchange -> CCS -> Finished. We forced `--tls-max 1.2` because TLS 1.3 encrypts the Certificate message.
- **Why our CA works:** CA:TRUE + Key Cert Sign, trusted in the System keychain, leaf has SAN for app and api.
- **ALPN:** HTTP/1.1 vs HTTP/2 chosen in the Client Hello; Wireshark labels encrypted data HTTP/2 without reading it.
- **Load balancing:** round-robin; `max_fails=1` + `fail_timeout=10s` mark a backend down; `proxy_next_upstream` retries (H3, H4). Cloud: ALB health checks.
- **Caching:** same content -> same ETag on A and B -> `304` from either; `/api/status` is `no-store`.
- **Ports:** client ephemeral port (59877, 51288); server 53, 443, 3001, 3002; socket = IP + port at each end (H5).
- **TCP reliability:** Seq/Ack numbers, Win (flow control), Dup ACK/SACK (frames 30, 37). RST in frame 39 is curl closing.
- **Failure map:** curl exit 6 = DNS, 7 = TCP, 60 = TLS cert, HTTP 502 = backend (H1-H5).
- **H2 nuance:** DNS gave the wrong IP; TCP still connected (a stray nginx on Kevish's Mac); TLS rejected the cert - certificates prove identity, not just encryption.
- **Single points of failure:** DNS Mac and edge Mac; Phase 2 adds a backup resolver and standby edge.
- **Our incidents:** ARP `No route to host` (L2) and leftover nginx/ports (L4) - how we diagnosed layer by layer.
