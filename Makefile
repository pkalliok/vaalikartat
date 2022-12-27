
UID = $(shell id -u)
export DOCKER_HOST = unix:///run/user/$(UID)/podman/podman.sock
DC = docker-compose -f hasura-docker-compose.yml

test:
	@echo "Boom!  You've been tested."

stamps/prereq:
	sudo apt install podman-docker docker-compose
	systemctl --user enable podman.socket
	systemctl --user start podman.socket
	touch $@

stamps/dev-env: stamps/prereq
	$(DC) up -d
	touch $@

.PHONY: stop
stop:
	$(DC) stop
	rm stamps/dev-env
