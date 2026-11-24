# Team 07 Phase 2 report

## Architecture and IP inventory

| Mac | Wi-Fi IPv4 | Services |
| --- | --- | --- |
| Bhawana | ``10.7.8.58`` | Primary dnsmasq for Team 07 on UDP/TCP 53. Independent blocked client for the firewall demonstration. |
| Abhiman | ``10.7.15.27`` | Backup dnsmasq for Team 07 and primary nginx on TCP 80/443. Holds the original Team 07 CA signing key. |
| Kevish | ``10.7.3.98`` | Express A and B on TCP 3001/3002, standby nginx on TCP 80/443, Wireshark/test client. |

```text
Client
  |-- DNS UDP/TCP 53 --> Bhawana or Abhiman
  |-- HTTPS 443 -------> Abhiman (primary)
  |                        '-> HTTP across the LAN -> Kevish A:3001 or B:3002
  '--- HTTPS 443 ------> Kevish (standby after cutover)
                           '-> HTTP over loopback -> A:3001 or B:3002
```

Both private names normally resolve to Abhiman with a 30-second TTL. Only ``app.team07.test`` moves during cutover, leaving ``api.team07.test`` as the control. A per-domain macOS resolver lists both DNS servers while public DNS stays automatic. The standby has a distinct leaf certificate and private key. Its leaf was signed by the original Team 07 CA. nginx terminates TLS and forwards HTTP. ``X-Backend`` identifies the process that handled the request. The standby sets ``X-Edge: standby``, and the test also records the connected remote IP to identify both edges.

## Results and decisions

- **A — Backup DNS.** Stopping Bhawana's dnsmasq caused a direct query to time out. After clearing the client cache, normal HTTPS still returned ``200`` through the backup path. Both resolvers answered again after recovery. [Evidence](evidence/A-backup-dns.txt)
- **B — TTL and manual flush.** Both resolvers published TTL 30. Live fresh answers moved to the standby before HTTPS did. In a separate successful trial, old HTTPS was observed at 18:27:16 after both direct DNS answers had switched and the post-flush request reached standby during the same displayed second. The earlier flush trial already showed the new destination before flushing, so its output is retained as an inconclusive flush sample. [TTL](evidence/B-ttl-baseline.txt) · [Explicit flush](evidence/B-manual-flush-success.txt)
- **C — Isolation.** The temporary PF anchor on Kevish admitted Abhiman to both backend ports and blocked Bhawana. HTTPS through the primary still returned ``200``. All four rules recorded packet hits. Clearing the dedicated anchor and releasing its enable token restored both ports for Bhawana. [Active test](evidence/C-firewall-active.txt) · [Rollback](evidence/C-firewall-rollback.txt)
- **D — Backend failover.** Healthy requests served A and B. Six consecutive HTTPS requests returned ``200`` from B while A was stopped. After A was restarted, both backend IDs returned over trusted HTTPS. This demonstrates process failover on a shared backend host. Losing Kevish's entire Mac would also lose both processes and the standby nginx. [A stopped](evidence/D-backend-a-stopped.txt) · [Recovery](evidence/D-backend-recovered.txt)
- **E — Edge cutover.** Both names validated over HTTPS on standby before the switch. Both resolvers first returned the standby at 18:23:22 and normal HTTPS first reached standby at 18:24:01. These are sampled timestamps. All 25 HTTPS requests returned ``200``. Bhawana missed two short DNS probes near the transition and resumed answering. The API stayed on Abhiman. Both DNS records and normal HTTPS returned to the primary after rollback. [Live trace and control](evidence/B-E-live-cutover.txt) · [Rollback](evidence/B-E-rollback-and-C-preflight.txt)
- **F — Troubleshooting rehearsal.** DNS returned the expected primary address, the intentionally wrong TCP port 8443 refused a connection, and correcting the port to 443 restored trusted HTTPS. The live faculty-injected fault outcome remains an evaluation item. [Rehearsal](evidence/F-troubleshooting-rehearsal.txt)

The [final preflight](evidence/D-backend-recovered.txt) additionally recorded both DNS servers at TTL 30 with both names restored to primary and a conditional HTTP ``304``.

