# Runbook

## Every session
1. `ipconfig getifaddr en0` on all Macs. Expected: Kevish 10.7.21.121, Bhawana 10.7.19.109, Abhimaan 10.7.7.5.
2. If an IP changed:
   | Changed | Fix |
   |---|---|
   | Edge (Abhimaan) | Bhawana: `sed -i '' 's/OLD/NEW/g' $(brew --prefix)/etc/dnsmasq.conf; sudo brew services restart dnsmasq`; clients flush DNS cache |
   | Backends (Kevish) | Abhimaan: `sed -i '' 's/OLD/NEW/g' $(brew --prefix)/etc/nginx/servers/team07.conf; sudo nginx -t && brew services stop nginx && sudo brew services start nginx` |
   | DNS (Bhawana) | each client: `sudo networksetup -setdnsservers Wi-Fi NEW` and flush cache |
3. Restart what does not survive sleep: both `node server.js` backends; `caffeinate -dims` on Bhawana and Abhimaan.
4. One test: `for i in 1 2 3 4; do curl -si https://app.team07.test/api/status | grep -i x-backend; done` -> A and B alternate.

## Layer-by-layer diagnosis (bottom-up)
| # | Check | Command | If it fails |
|---|---|---|---|
| 1 | DNS | `dig app.team07.test +short` | DNS Mac asleep? dnsmasq? client resolver? (curl exit 6) |
| 2 | IP | `ping -c 2 10.7.7.5` | same Wi-Fi? IP changed? `No route to host` = ARP, reconnect Wi-Fi |
| 3 | TCP | `nc -vz 10.7.7.5 443` | nginx not running / wrong port (curl exit 7) |
| 4 | TLS | `curl -v https://app.team07.test` | CA trust / SAN (curl exit 60) |
| 5 | App | look for `502` | backends down or upstream IP wrong; check nginx error.log |
`curl -s` hides errors: rerun without `-s` and add `; echo "exit=$?"`.

## Gotchas seen in this build
- Leftover nginx from an old project held 8080/443 and had a config without `include servers/*;` -> clean nginx.conf, root-owned service.
- nginx started without sudo -> `nginx.pid: Permission denied`.
- Heredoc `EOF` must start at column 0 when pasting.
- Stray nginx on Kevish's Mac (443) is harmless but explains exit 60 in failure H2.
