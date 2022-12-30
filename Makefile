
UID = $(shell id -u)
export DOCKER_HOST = unix:///run/user/$(UID)/podman/podman.sock
DC = docker-compose -f hasura-docker-compose.yml
PG_COMMAND = $(DC) exec postgres

test:
	@echo "Boom!  You've been tested."

stamps/prereq:
	sudo apt install podman-docker docker-compose sql-migrate
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

stamps/data-prereq:
	sudo apt install curl unzip iconv mawk # csvkit
	touch $@

data/ekv-2019_ehd_maa.csv.zip: stamps/data-prereq
	curl https://tulospalvelu.vaalit.fi/EKV-2019/ekv-2019_ehd_maa.csv.zip > $@

data/ekv-2019_votes.csv: data/ekv-2019_ehd_maa.csv.zip stamps/data-prereq
	unzip -p $< ekv-2019_teat_maa.csv | iconv -f latin1 -t utf8 > $@

data/ekv-2019_areas.csv: data/ekv-2019_votes.csv scripts/get_areas.sh stamps/data-prereq
	bash ./scripts/get_areas.sh $< > $@

data/ekv-2019_area_candidate_votes.csv: data/ekv-2019_votes.csv scripts/get_area_candidate_votes.sh stamps/data-prereq
	bash ./scripts/get_area_candidate_votes.sh $< > $@

data/ekv-2019_candidates.csv: data/ekv-2019_votes.csv scripts/get_candidates.sh stamps/data-prereq
	bash ./scripts/get_candidates.sh $< > $@

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

