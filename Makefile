# Copyright (c) Humlab Development Team.
# Distributed under the terms of the Modified BSD License.

include .env

SHELL = /bin/bash

.DEFAULT_GOAL=build

build: docker-image
	@echo "Build done"

git-tag:
	@git tag v$(CLEARINGHOUSE_VERSION)
	@git push origin v$(CLEARINGHOUSE_VERSION)

# host-user:
# 	@-getent group $(HOST_USERNAME) &> /dev/null || echo addgroup --gid $(LAB_GID) $(HOST_USERNAME) &>/dev/null
# 	@-id -u $(HOST_USERNAME) &> /dev/null || sudo adduser $(HOST_USERNAME) --uid $(LAB_UID) --gid $(LAB_GID) --no-create-home --disabled-password --gecos '' --shell /bin/bash

rebuild: down build git-tag up
	@echo "Rebuild done"
	@exit 0

# network:
# 	@docker network inspect $(NETWORK_NAME) >/dev/null 2>&1 || docker network create $(NETWORK_NAME)

# host-volume:
# 	@docker volume inspect $(HUB_HOST_VOLUME_NAME) >/dev/null 2>&1 || docker volume create --name $(HUB_HOST_VOLUME_NAME)

check-files: config/userlist secrets/.env.oauth2

docker-image:
	@echo "Building docker image"
	docker build \
		-t $(IMAGE_NAME):latest \
		-t $(IMAGE_NAME):$(CLEARINGHOUSE_VERSION) \
		-f Dockerfile .

docker-run: docker-image
	@echo "Building docker image"
	@docker run --rm -p $(CLEARINGGHOUSE_LISTEN_PORT):$(CLEARINGGHOUSE_LISTEN_PORT) --mount "type=bind,source=$(HOST_DATA_FOLDER),target=/data" $(IMAGE_NAME):latest

bash:
	@docker exec -it -t `docker ps -f "ancestor=$(IMAGE_NAME)" -q --all | head -1` /bin/bash

clean: down
	-docker rm `docker ps -f "ancestor=$(IMAGE_NAME)" -q --all` >/dev/null 2>&1
	echo "FIX THIS: @docker volume rm `docker volume ls -q`"

down:
	-docker-compose down

up:
	@docker-compose up -d

follow:
	@docker logs $(IMAGE_NAME) --follow

restart: down up follow

nuke:
	-docker stop `docker ps --all -q`
	-docker rm -fv `docker ps --all -q`
	-docker images -q --filter "dangling=true" | xargs docker rmi

tag: guard_clean_working_repository
	@git tag $(CLEARINGHOUSE_VERSION) -a
	@git push origin --tags

.ONESHELL: guard_clean_working_repository
guard_clean_working_repository:
	@status="$$(git status --porcelain)"
	@if [ "$$status" != "" ]; then
		echo "error: changes exists, please commit or stash them: "
		echo "$$status"
		exit 65
	fi

.PHONY: bash clean down up follow restart nuke tag rebuild network

