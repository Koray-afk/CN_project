# Setup, per machine (all three on the same Wi-Fi, VPN and Private Relay off, Private Wi-Fi Address = Fixed)

## Bhawana - DNS (10.7.19.109)
```bash
brew install dnsmasq
cp dns/dnsmasq.conf $(brew --prefix)/etc/dnsmasq.conf
$(brew --prefix)/sbin/dnsmasq --test --conf-file=$(brew --prefix)/etc/dnsmasq.conf   # syntax check OK
sudo brew services start dnsmasq
dig @127.0.0.1 app.team07.test +short        # 10.7.7.5
caffeinate -dims                             # keep awake, own tab
```

## Kevish - backends (10.7.21.121)
```bash
cd backend && npm install            # express
BACKEND=A PORT=3001 node server.js   # tab 1
BACKEND=B PORT=3002 node server.js   # tab 2
curl -i http://localhost:3001/api/status   # X-Backend: A
```
Allow incoming connections for `node` if macOS asks. Wireshark: `brew install --cask wireshark`, install ChmodBPF.

## Abhimaan - edge (10.7.7.5)
```bash
brew install nginx openssl@3
bash certs/make-certs.sh                       # CA, server cert, installs into nginx/certs
cp nginx/nginx.conf $(brew --prefix)/etc/nginx/nginx.conf
mkdir -p $(brew --prefix)/etc/nginx/servers
cp nginx/team07.conf $(brew --prefix)/etc/nginx/servers/team07.conf
sudo nginx -t
brew services stop nginx; sudo brew services start nginx     # root-owned service (port 80/443 + pid file)
caffeinate -dims
```
Make sure no old nginx holds 80/443/8080: `sudo lsof -iTCP -sTCP:LISTEN -n -P | grep nginx`.

## Client Macs (Kevish, Abhimaan)
```bash
sudo networksetup -setdnsservers Wi-Fi 10.7.19.109
sudo dscacheutil -flushcache; sudo killall -HUP mDNSResponder
sudo security add-trusted-cert -d -r trustRoot -k /Library/Keychains/System.keychain rootCA.pem   # AirDrop only rootCA.pem
curl -i https://app.team07.test/api/status        # no -k
```
Never share rootCA.key or server.key.
