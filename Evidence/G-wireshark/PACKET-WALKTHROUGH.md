# Task G - packet walkthrough (CN-phase-1.pcapng, 43 packets, 0 dropped; capture on Kevish's Wi-Fi en0)
Capture filter: `host 10.7.19.109 or host 10.7.7.5`. Client = Kevish 10.7.21.121, ephemeral port 59877.
CN-phase-1-app-flow.pcapng = 39 packets (display filter: dns.qry.name == "app.team07.test" or tcp.port == 59877 or tcp.port == 52981)

| Frame | What | Details to point at |
|---|---|---|
| 3 | DNS query | 10.7.21.121:51288 -> 10.7.19.109:**53/UDP**, Transaction 0x8c3f, `A app.team07.test` |
| 4 | DNS response | 10.7.19.109:53 -> :51288, same Transaction ID, Answer RRs 1, `A 10.7.7.5`, 67 ms |
| 5, 7 | ARP | "Who has 10.7.7.5?" -> reply 72:94:6f:7b:aa:c9 (Abhimaan). Frames go straight to his MAC, not the gateway |
| 6 | TCP SYN | 59877 -> **443**, Seq 0 (raw 1389249030), flags SYN,ECE,CWR, Win 65535 |
| 8 | TCP SYN-ACK | 443 -> 59877, Seq 0 (raw 4023483017), Ack 1 (raw 1389249031) |
| 9 | TCP ACK | Seq 1, Ack 1 (raw 4023483018), Win 131776 - handshake complete |
| 10 | TLS 1.2 Client Hello | SNI `app.team07.test`, ALPN h2 + http/1.1, 46 cipher suites |
| 13 | Server Hello, Certificate, Server Key Exchange, Server Hello Done | Cipher TLS_ECDHE_RSA_WITH_CHACHA20_POLY1305_SHA256 (0xcca8); ALPN h2; cert issuer `team07 Local Root CA`, subject `app.team07.test` |
| 15, 17 | Client Key Exchange, Change Cipher Spec, Finished / server CCS + Finished | key agreement done |
| 18, 20, 21, 24, 33 | Application Data | encrypted; Wireshark labels it HTTP/2 only because ALPN negotiated h2 |
| 23, 26, 28 | TCP handshake nginx -> backend | 10.7.7.5:**52981** -> 10.7.21.121:**3001** |
| 27 | **plain HTTP** `GET /api/status HTTP/1.1` | Host app.team07.test, X-Real-IP / X-Forwarded-For 10.7.21.121, X-Forwarded-Proto https |
| 31 | `HTTP/1.1 200 OK` JSON | X-Backend: A, Cache-Control: no-store |
| 30, 37 | Dup ACK | TCP reliability / SACK evidence |
| 35, 36, 39 | Encrypted Alert, FIN, RST | TLS close_notify, teardown (the RST is curl closing, not an error) |
| 1, 2 | macOS background PTR lookup (NXDOMAIN) | noise; removed in the app-flow export |

Key points: two separate TCP connections (client<->edge on 443, edge<->backend on 3001); TLS ends at nginx.
