| # | Fault | Layer | Symptom | curl exit |
|---|---|---|---|---|
| H1 | Wrong resolver (8.8.8.8) | DNS | NXDOMAIN from root zone; ping by IP works | 6 |
| H2 | DNS record -> wrong IP | TLS (wrong host) | TCP connects, certificate not trusted | 60 |
| H3 | Backend A stopped | App tier, masked by LB | all answers from B; error.log "Connection refused ... :3001" | 0 |
| H4 | Both backends stopped | App tier | HTTP/2 502 from nginx; error.log for :3001 then :3002 | 0 (HTTP 502) |
| H5 | Wrong port (8443) | TCP | Connection refused, host reachable | 7 |
Diagnosis order: dig -> ping -> nc -vz -> curl -v -> look for 502.
