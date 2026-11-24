# Team 07 Phase 2 evidence index

Some live evidence was supplied by operators in chat. Such entries are labeled or tabulated from their outputs. Independent checks were run from Kevish's Mac.

| Extension | Evidence |
| --- | --- |
| A — DNS backup | [Client config, outage and recovery](A-backup-dns.txt) |
| B — TTL | [30-second baseline](B-ttl-baseline.txt), [natural expiry and cutover](B-E-live-cutover.txt), [first flush trial](B-manual-flush-first-trial.txt), [successful before/after flush](B-manual-flush-success.txt) |
| C — Backend isolation | [Before](C-firewall-baseline.txt), [active](C-firewall-active.txt), [rule counters and rollback](C-firewall-rollback.txt) |
| D — Backend failover | [Before](D-backend-baseline.txt), [A stopped](D-backend-a-stopped.txt), [A recovered and final HTTPS/DNS/cache checks](D-backend-recovered.txt) |
| E — Edge migration | [Certificate signing](E-standby-tls-signing.txt), [trusted standby preflight](E-standby-live-preflight.txt), [DNS readiness](E-reloadable-dns-baseline.txt), [live cutover and API control](B-E-live-cutover.txt), [DNS rollback](B-E-rollback-and-C-preflight.txt) |
| F — Troubleshooting | [Team rehearsal](F-troubleshooting-rehearsal.txt). Faculty challenge evidence is added during evaluation. |
| Packet capture | [Live preflight pcapng](team07-live-preflight.pcapng). It records both DNS replies with TTL 30 and the TLS connection to the primary for ``app.team07.test``, after rollback. The failover result is recorded separately in the A terminal evidence. |

