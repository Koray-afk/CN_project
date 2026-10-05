# Troubleshooting note 2 - nginx "Connection refused" on port 80 (Abhimaan's Mac)

Layered diagnosis (Kevish's side): `dig` -> 10.7.7.5 OK; `ping 10.7.7.5` OK; `nc -vz 10.7.7.5 80` -> Connection refused
(`curl: (7) Failed to connect ... port 80`). So DNS and IP fine, failure at TCP: nothing listening on :80.

Edge diagnostics: `lsof` showed nothing on :80; `curl localhost` also failed; `nginx.conf` had no `include servers/*;`;
`error.log`: `bind() to 0.0.0.0:8080 failed (48: Address already in use)` and same for 443;
`brew services list`: `nginx error 1 root ... sh.brew.nginx.plist`.

Root cause: a leftover nginx from the previous project (user-owned PIDs 13389/13423 listening on *:8080 and *:443) and an old
nginx.conf (upstream 10.7.27.219:3001 / 10.7.5.62:3002, `app.teamX.test`, proxy_cache on HTTPS) that never included our `team07.conf`.
Second cause: started without sudo -> `open() "/opt/homebrew/var/run/nginx.pid" failed (13: Permission denied)`.

Fix: stopped old nginx, wrote the clean nginx.conf (nginx/nginx.conf in this repo) with `include servers/*;`, then
`brew services stop nginx && sudo brew services start nginx` -> nginx on *:80 as root, localhost curl returned 200 + X-Backend.
Old config is kept as `old-project-nginx.conf.txt` (the "before" evidence). proxy_cache was intentionally NOT kept:
it would hide A/B alternation; caching in Task F is done with backend Cache-Control/ETag headers.
