SERVICE    := spectagent
COMPOSE    := docker compose --env-file docker/.env -f docker/docker-compose.yml -f docker/docker-compose.secrets.yml
# local cache used by omc-install; OMC_FLAGS env var in .env drives the container
OMC_FLAGS  := .omc-flags

