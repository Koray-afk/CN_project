#!/usr/bin/env bash
set -euo pipefail

role="${1:-}"
prefix="$(brew --prefix)"
brew_bin="$(command -v brew)"
main="$prefix/etc/dnsmasq.conf"
fragments="$prefix/etc/dnsmasq.d"
hosts="$prefix/etc/dnsmasq.team07.hosts"

case "$role" in
  primary)
    expected_ip=10.7.8.58
    config="$main"
    grep -Fxq 'local=/team07.test/' "$config"
    grep -Fxq 'host-record=app.team07.test,10.7.15.27,30' "$config"
    grep -Fxq 'host-record=api.team07.test,10.7.15.27,30' "$config"
    grep -Fxq 'local-ttl=60' "$config"
    ;;
  backup)
    expected_ip=10.7.15.27
    config="$fragments/team07.conf"
    grep -Fxq 'local=/team07.test/' "$config"
    grep -Fxq 'host-record=app.team07.test,api.team07.test,10.7.15.27,30' "$config"
    grep -Fxq 'local-ttl=30' "$main"
    ;;
  *)
    printf 'Usage: bash prepare-team07-dns.sh primary|backup\n' >&2
    exit 2
    ;;
esac

if [ "$(ipconfig getifaddr en0)" != "$expected_ip" ]; then
  printf 'Expected Wi-Fi address %s for the %s role.\n' "$expected_ip" "$role" >&2
  exit 1
fi

if [ -e "$hosts" ] || [ -L "$hosts" ]; then
  printf 'Hosts file already exists at %s. Check the active config before continuing.\n' "$hosts" >&2
  exit 1
fi

rollback="$(mktemp -d "$HOME/team07-reloadable-dns.XXXXXX")"
cp -p "$config" "$rollback/original.conf"
printf 'Original config backup: %s\n' "$rollback/original.conf"

if [ "$role" = primary ]; then
  sed -E '/^host-record=(app|api)\.team07\.test,/d; s/^local-ttl=60$/local-ttl=30/' \
    "$rollback/original.conf" > "$rollback/new.conf"
else
  sed -E '/^host-record=app\.team07\.test,api\.team07\.test,/d' \
    "$rollback/original.conf" > "$rollback/new.conf"
fi
printf '\naddn-hosts=%s\n' "$hosts" >> "$rollback/new.conf"
printf '10.7.15.27 app.team07.test api.team07.test\n' > "$rollback/primary.hosts"

"$prefix/sbin/dnsmasq" --test --conf-file="$rollback/new.conf"
sudo -v
sudo install -m 644 "$rollback/primary.hosts" "$hosts"
sudo install -m 644 "$rollback/new.conf" "$config"
if ! "$prefix/sbin/dnsmasq" --test --conf-file="$main" --conf-dir="$fragments,*.conf"; then
  sudo cp -p "$rollback/original.conf" "$config"
  sudo mv "$hosts" "$rollback/unused.hosts"
  exit 1
fi
sudo "$brew_bin" services restart dnsmasq
printf 'Prepared %s with the original primary answer.\n' "$role"
