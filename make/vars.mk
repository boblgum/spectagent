SERVICE    := spectagent
COMPOSE    := docker compose --env-file docker/.env -f docker/docker-compose.yml -f docker/docker-compose.secrets.yml

