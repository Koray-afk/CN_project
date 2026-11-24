#!/usr/bin/env bash
set -euo pipefail

name=app.team07.test
primary=10.7.15.27
standby=10.7.3.98
dns1=10.7.8.58
dns2=10.7.15.27

http_edge() {
  /usr/bin/curl --noproxy '*' -fsS -o /dev/null --max-time 5 \
    -w '%{remote_ip}\n' "https://$name/api/status"
}

fresh_ip() {
  dig @"$1" "$name" A +time=1 +tries=1 +noall +answer |
    awk -v name="$name." '$1==name && $4=="A" {print $5; exit}'
}

sudo -v
if [ "$(fresh_ip "$dns1")" != "$primary" ] || [ "$(fresh_ip "$dns2")" != "$primary" ]; then
  printf 'Start with both resolvers pointing to the primary (%s).\n' "$primary" >&2
  exit 1
fi
sudo -n dscacheutil -flushcache
sudo -n killall -HUP mDNSResponder
warm="$(http_edge)"
printf '%s Warm HTTPS remote IP: %s\n' "$(date '+%H:%M:%S')" "$warm"
if [ "$warm" != "$primary" ]; then exit 1; fi
printf 'SWITCH NOW: Bhawana and Abhiman should each run team07_standby.\n'

deadline=$((SECONDS + 24))
while [ "$SECONDS" -lt "$deadline" ]; do
  ip1="$(fresh_ip "$dns1" || true)"
  ip2="$(fresh_ip "$dns2" || true)"
  if [ "$ip1" = "$standby" ] && [ "$ip2" = "$standby" ]; then
    printf '%s Both direct DNS answers: %s\n' "$(date '+%H:%M:%S')" "$standby"
    before="$(http_edge)"
    printf '%s Before flush: %s\n' "$(date '+%H:%M:%S')" "$before"
    if [ "$before" != "$primary" ]; then
      printf 'Client already switched. Restore both DNS records and retry.\n' >&2
      exit 1
    fi
    sudo -n dscacheutil -flushcache
    sudo -n killall -HUP mDNSResponder
    after="$(http_edge)"
    printf '%s After flush: %s\n' "$(date '+%H:%M:%S')" "$after"
    test "$after" = "$standby"
    exit
  fi
  sleep 1
done
printf 'The two resolvers did not switch within the test window. Restore both to primary before retrying.\n' >&2
exit 1
