touch .env docker-compose.yml \
compose/{crowdsec.yml,networks.yml,socket-proxy.yml,traefik.yml} \
data/{
  crowdsec/.env,socket-proxy/.env,traefik/
      {.env,.htpasswd,traefik.yml,certs/{acme_letsencrypt.json,tls_letsencrypt.json},dynamic_conf/{http.middlewares.default.yml,http.middlewares.crowdsec.plugin.yml,http.middlewares.default-security-headers.yml,http.middlewares.gzip.yml,http.middlewares.traefik-dashboard-auth.yml,http.routers.traefik-dashboard.yml,tls.yml}}}


touch data/traefik/certs/{acme_letsencrypt.json,tls_letsencrypt.json}
chmod 600 data/traefik/certs/{acme_letsencrypt.json,tls_letsencrypt.json}