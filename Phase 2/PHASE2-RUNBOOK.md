# Team 07 Phase 2 runbook

Start from working Team 07 Phase 1. Keep all three Macs on the same reachable LAN. The [report](PHASE2-REPORT.md) records the tested IPs. Check current addresses with `ipconfig getifaddr en0` first. The bundled scripts use the recorded addresses and reject or fail preflight when those addresses no longer match. Update the affected values in the configs, resolver entries, and commands together if DHCP changes them.

| Mac | Team 07 role |
| --- | --- |
| Bhawana, `10.7.8.58` | Primary DNS and firewall test client |
| Abhiman, `10.7.15.27` | Primary HTTPS edge, backup DNS, Team 07 CA signing |
| Kevish, `10.7.3.98` | Two backends, standby HTTPS edge, capture and test client |

Paths below assume the ZIP was extracted as `~/Downloads/team07-phase2`, unless specified. AirDrop individual public configs if a teammate does not have the whole folder. Keep private keys on the Macs that generated them.

## 0. Confirm the Phase 1 baseline

**Kevish:** Keep A and B running in separate Terminal tabs. From the original `~/cn-backend`, run `BACKEND=A PORT=3001 node server.js` in one and `BACKEND=B PORT=3002 node server.js` in the other. For a new local folder, use the included [backend source](backend/) and install Express with `npm install` first.

**Abhiman:** The existing Team 07 [nginx Phase 1 edge](https://github.com/Koray-afk/CN_project/blob/main/docs/ARCHITECTURE.md) must use Kevish's current IP `10.7.3.98` in both upstream entries. Keep the TLS site and certificate already used for Team 07.

**Kevish:** Verify DNS to Bhawana, normal HTTPS by name, and both backend IDs:

```sh
dig @10.7.8.58 app.team07.test A +noall +answer
for i in 1 2 3 4; do
  curl -fsSI --max-time 5 https://app.team07.test/api/status |
    grep -iE '^(HTTP/|x-backend:)'
done
```

## 1. A — Backup DNS

**Abhiman:** The Homebrew dnsmasq service in the tested setup loads `$(brew --prefix)/etc/dnsmasq.d/*.conf`. Confirm that with `sudo launchctl print system/sh.brew.dnsmasq`. Before stopping either DNS server, set up the backup using a dedicated fragment. If this is already installed and correct, skip installation. Preserve any existing fragment and check it for conflicts before replacement. Use TTL 60 initially if Bhawana's Phase 1 records still use 60.

```sh
PREFIX="$(brew --prefix)"
RULE="$PREFIX/etc/dnsmasq.d/team07.conf"
test ! -e "$RULE" &&
printf '%s\n' 'local=/team07.test/' \
  'host-record=app.team07.test,api.team07.test,10.7.15.27,60' |
  sudo tee "$RULE" >/dev/null
"$PREFIX/sbin/dnsmasq" --test --conf-file="$PREFIX/etc/dnsmasq.conf" \
  --conf-dir="$PREFIX/etc/dnsmasq.d,*.conf" &&
sudo "$(command -v brew)" services restart dnsmasq
```

**Kevish:** Confirm both Team 07 names answer directly from `10.7.15.27`. **Kevish and Abhiman** configure the two resolvers just for Team 07 using the bundled [client resolver file](configs/team07.test.resolver). Preserve your earlier rule if one exists.

```sh
sudo mkdir -p /etc/resolver
if [ -f /etc/resolver/team07.test ]; then
  sudo cp -p /etc/resolver/team07.test "/private/tmp/team07.test.before-$(date +%Y%m%d-%H%M%S)"
fi
sudo install -m 644 "$HOME/Downloads/team07-phase2/configs/team07.test.resolver" \
  /etc/resolver/team07.test
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
curl -fsSI --max-time 8 https://app.team07.test/api/status
```

**Bhawana:** Stop only dnsmasq with `sudo "$(command -v brew)" services stop dnsmasq`. **Kevish:** Flush the cache, then show the direct primary query timing out and normal HTTPS still working:

```sh
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
dig @10.7.8.58 app.team07.test A +time=2 +tries=1
curl -fsSI --max-time 20 https://app.team07.test/api/status
```

**Bhawana:** Immediately restore dnsmasq with `sudo "$(command -v brew)" services start dnsmasq`. Check that both direct resolvers answer again. If recording Wireshark, capture on Kevish's Wi-Fi with `host 10.7.15.27 and port 53` and filter to `dns.qry.name == "app.team07.test"`. Record the primary timeout, successful normal HTTPS, and restoration. The package's pcapng is a later healthy preflight capture.

## 2. B/E preparation — 30-second TTL and standby HTTPS

### DNS preparation

Before moving to reloadable host files, **Bhawana** should have individual Team 07 host-records with an explicit TTL 30 in `$(brew --prefix)/etc/dnsmasq.conf`, for example `host-record=app.team07.test,10.7.15.27,30` and the equivalent for `api`. In the original setup Bhawana's global `local-ttl` was still 60 at this point. **Abhiman** should have the combined Team 07 host-record ending in `,30` in the Team 07 fragment and existing main `local-ttl=30`. Back up all edited files, syntax-check and restart one daemon at a time. Both must return TTL 30.

Then run [prepare-team07-dns.sh](configs/prepare-team07-dns.sh) on Bhawana first with argument `primary`, and on Abhiman with argument `backup` after Bhawana answers again. The script recognizes the tested initial files and prints backup locations. It moves just the Team 07 mappings to `$(brew --prefix)/etc/dnsmasq.team07.hosts` for SIGHUP reload. Bhawana's default local TTL becomes 30 and Abhiman's existing 30 remains in effect. If the script refuses an unfamiliar configuration, read the active file and resolve the difference before applying the conversion. If already converted, verify that both names currently answer with TTL 30 and point to the primary. The original filenames and launchd label are tested for Homebrew's current setup.

### Team 07 standby

**Kevish:** Generate a distinct key and CSR if they do not exist. Send only the CSR to Abhiman.

```sh
SSL="$(brew --prefix openssl@3)/bin/openssl"
DIR="$HOME/cn-team07-standby-tls"
mkdir -p "$DIR"
if [ ! -e "$DIR/standby.key" ] && [ ! -e "$DIR/team07-standby.csr" ]; then
  (umask 077; "$SSL" req -new -newkey rsa:2048 -nodes \
    -subj '/CN=app.team07.test' -keyout "$DIR/standby.key" \
    -out "$DIR/team07-standby.csr")
fi
```

**Abhiman:** From `~/cn-certs`, verify that `rootCA.pem` belongs to Team 07 and that `rootCA.key` and `leaf.cnf` exist. Sign the received CSR and verify both SANs.

```sh
cd "$HOME/cn-certs"
SSL="$(brew --prefix openssl@3)/bin/openssl"
CSR="$HOME/Downloads/team07-standby.csr"
CRT="$HOME/Downloads/team07-standby.crt"
"$SSL" x509 -in rootCA.pem -noout -subject
"$SSL" req -in "$CSR" -noout -verify &&
"$SSL" x509 -req -in "$CSR" -CA rootCA.pem -CAkey rootCA.key \
  -set_serial "0x01$("$SSL" rand -hex 15)" -days 397 -sha256 \
  -extfile leaf.cnf -extensions v3_leaf -out "$CRT" &&
"$SSL" verify -CAfile rootCA.pem -verify_hostname app.team07.test "$CRT" &&
"$SSL" verify -CAfile rootCA.pem -verify_hostname api.team07.test "$CRT"
```

**Kevish:** Receive only `team07-standby.crt` into Downloads. The [standby nginx template](configs/nginx-standby.conf.template) uses a separate named virtual host and independent certificate directory, with loopback upstreams. If the Team 07 site or existing Team 07 certificate files are already installed, back them up outside the nginx server include directory before replacing them.

```sh
KIT="$HOME/Downloads/team07-phase2"
PREFIX="$(brew --prefix)"
SSL="$(brew --prefix openssl@3)/bin/openssl"
NGINX="$PREFIX/bin/nginx"
CERT="$HOME/Downloads/team07-standby.crt"
KEY="$HOME/cn-team07-standby-tls/standby.key"
STAGED="$(mktemp)"
test "$("$SSL" x509 -in "$CERT" -noout -pubkey)" = "$("$SSL" pkey -in "$KEY" -pubout)" &&
sed "s|@BREW_PREFIX@|$PREFIX|g" "$KIT/configs/nginx-standby.conf.template" > "$STAGED" &&
sudo mkdir -p "$PREFIX/etc/nginx/certs/team07" &&
sudo install -m 644 "$CERT" "$PREFIX/etc/nginx/certs/team07/standby.crt" &&
sudo install -m 600 "$KEY" "$PREFIX/etc/nginx/certs/team07/standby.key" &&
sudo install -m 644 "$STAGED" "$PREFIX/etc/nginx/servers/team07.conf" &&
sudo "$NGINX" -t &&
sudo "$NGINX" -s reload
```

This uses Kevish's existing nginx process. If using a fresh nginx install with no master process, start it with Homebrew after a successful syntax check. If validation fails, restore the prior config or move the new site out of `servers/` before reloading. Test both names with trusted HTTPS, for example `curl --resolve app.team07.test:443:10.7.3.98 -fsSI https://app.team07.test/api/status`. Both names must return `200` and `X-Edge: standby` before DNS moves.

## 3. B/E — Live cutover, TTL, explicit flush and restoration

On **both DNS Macs** prepare the following in an open Terminal. The functions take effect only when called. Both DNS Macs must receive each switch. Only the app name moves.

```sh
HOSTS="$(brew --prefix)/etc/dnsmasq.team07.hosts"
sudo -v
team07_standby() {
  printf '10.7.3.98 app.team07.test\n10.7.15.27 api.team07.test\n' |
    sudo tee "$HOSTS" >/dev/null &&
  sudo launchctl kill SIGHUP system/sh.brew.dnsmasq
}
team07_primary() {
  printf '10.7.15.27 app.team07.test api.team07.test\n' |
    sudo tee "$HOSTS" >/dev/null &&
  sudo launchctl kill SIGHUP system/sh.brew.dnsmasq
}
```

**Natural expiry.** On Kevish, flush and warm the primary by starting the loop. At the first HTTPS result for Abhiman, both DNS operators call `team07_standby`. Keep both edges running. Save samples where both direct queries return Kevish but normal HTTPS still reaches Abhiman. Keep watching until regular HTTPS reaches Kevish. Confirm the API still reaches Abhiman with the same curl format.

```sh
sudo dscacheutil -flushcache
sudo killall -HUP mDNSResponder
for i in $(seq 1 25); do
  date '+%H:%M:%S'
  for ip in 10.7.8.58 10.7.15.27; do
    printf 'DNS %s: ' "$ip"
    dig @"$ip" app.team07.test A +short +time=1 +tries=1
  done
  curl -fsS --max-time 5 -o /dev/null \
    -w 'HTTPS %{http_code}, remote IP %{remote_ip}\n' https://app.team07.test/api/status
  sleep 2
done
```

**Explicit flush.** Restore both DNS Macs to primary with `team07_primary`. Run [check-team07-cache-flush.sh](configs/check-team07-cache-flush.sh) on **Kevish**. When it prints `SWITCH NOW`, both DNS operators call `team07_standby`. The script checks both fresh DNS answers, captures the old HTTPS destination before flushing, then records the new destination afterward. If it reports the client switched too early, restore primary and retry with operators ready.

**Rollback.** Both DNS operators call `team07_primary`. From Kevish, verify both private names at both resolvers return `10.7.15.27` with TTL 30. Flush if needed and verify normal HTTPS connects to Abhiman. Save the timestamps and results.

## 4. C — Temporary service isolation

**Bhawana and Abhiman** first confirm direct curls to `http://10.7.3.98:3001/api/status` and `http://10.7.3.98:3002/api/status` both work. **Kevish** checks the parent filter hook and loads only the temporary Team 07 anchor, using the [PF rules](configs/team07-backend.pf). The file assumes interface `en0`. Ensure `com.apple/*` appears in the main filter rules and the Team 07 anchor is unused before proceeding.

```sh
PF_FILE="$HOME/Downloads/team07-phase2/configs/team07-backend.pf"
PF_BACKUP="$(mktemp -d "$HOME/team07-pf.XXXXXX")"
ANCHOR=com.apple/team07-phase2
sudo pfctl -sr | tee "$PF_BACKUP/main.rules"
sudo pfctl -a com.apple -s Anchors
sudo pfctl -a "$ANCHOR" -nf "$PF_FILE"
```

After checking the output, use the same Terminal tab:

```sh
sudo pfctl -a "$ANCHOR" -f "$PF_FILE" &&
  sudo pfctl -E 2>&1 | tee "$PF_BACKUP/enable.txt"
```

**Bhawana and Abhiman** repeat both direct curls, with `--connect-timeout 3 --max-time 5`. Bhawana should time out. Abhiman should still get A and B. **Kevish** verifies normal HTTPS still returns `200` through the primary. Then Kevish saves counters, removes only the Team 07 rules and releases the enable reference:

```sh
sudo pfctl -a "$ANCHOR" -vvsr
PF_TOKEN="$(awk '/Token[[:space:]]*:/ {print $NF; exit}' "$PF_BACKUP/enable.txt")"
if [ -n "$PF_TOKEN" ]; then
  sudo pfctl -a "$ANCHOR" -F rules &&
    sudo pfctl -X "$PF_TOKEN"
fi
```

**Bhawana** verifies both direct ports work again. Save the baseline, active results, counters and restored access.

## 5. D — Backend failover and recovery

**Kevish** runs the HTTPS loop once with both backends active, once after stopping A with Ctrl+C in its tab, and again after restarting A and allowing the nginx failure window to elapse.

```sh
for i in 1 2 3 4 5 6; do
  curl -fsS -D - -o /dev/null --max-time 5 \
    -w 'Remote IP: %{remote_ip}\n' https://app.team07.test/api/status |
    grep -iE '^(HTTP/|x-backend:|Remote IP:)'
done
```

Expect A/B, then all B with `200`, then both IDs again. Restart A from its original directory with `BACKEND=A PORT=3001 node server.js`. Keep B and both nginx edges running throughout. Save requests from all three stages.

## 6. F and final demonstration

Diagnose the faculty's fault in the order DNS → TCP → TLS → application. Compare `dig @10.7.8.58 app.team07.test` and `dig @10.7.15.27 app.team07.test`, then test the edge with `nc -G 2 -vz 10.7.15.27 443` and trusted `curl -v` on the normal hostname. Check `X-Backend` and upstream reachability if TCP and TLS passed. State the first failing layer, isolate or correct it, and rerun the same check. Record faculty results separately from the [practice fault](evidence/F-troubleshooting-rehearsal.txt).

Follow the assignment's final sequence: topology, LAN reachability, private DNS, trusted HTTPS, A/B load balancing, saved [Phase 1 packet walkthrough](https://github.com/Koray-afk/CN_project/blob/main/Evidence/G-wireshark/PACKET-WALKTHROUGH.md), HTTP caching, live Backend A stop, Phase 2 DNS resilience, faculty troubleshooting, and individual viva. Have the [report](PHASE2-REPORT.md), [evidence index](evidence/README.md), and firewall rollback proof open during review. Use the final preflight to verify both DNS answers, primary HTTPS, both backend IDs, and conditional HTTP `304` before the demo.

