
UID = $(shell id -u)
export DOCKER_HOST = unix:///run/user/$(UID)/podman/podman.sock
DC = docker-compose -f hasura-docker-compose.yml
PG_COMMAND = $(DC) exec postgres

test:
	@echo "Boom!  You've been tested."

stamps/prereq:
	sudo apt install podman-docker docker-compose sql-migrate curl
	systemctl --user enable podman.socket
	systemctl --user start podman.socket
	touch $@

stamps/database: stamps/prereq
	$(DC) up -d postgres
	-$(PG_COMMAND) createdb -U postgres hasura
	-$(PG_COMMAND) createdb -U postgres vaalidata
	touch $@

stamps/dev-env: stamps/prereq stamps/database
	$(DC) up -d
	touch $@

.PHONY: stop
stop:
	$(DC) stop
	-rm stamps/dev-env
	-rm stamps/database

.PHONY: clean-dev-env
clean-dev-env: stop
	$(DC) down -v

.PHONY: logs
logs:
	$(DC) logs -f

