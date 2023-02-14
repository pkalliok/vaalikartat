
UID = $(shell id -u)
export DOCKER_HOST = unix:///run/user/$(UID)/podman/podman.sock
DC = docker-compose -f hasura-docker-compose.yml
PG_COMMAND = $(DC) exec postgres
PSQL = psql "$(shell bash ./scripts/get_connection_params.sh development)"
GCP_PROJ = $(shell gcloud config get-value project)
GCP_SA = terraform-sa-1@$(GCP_PROJ).iam.gserviceaccount.com
TF = terraform -chdir=gcp-deploy
HASURA_IMAGE = $(shell grep image:.*hasura hasura-docker-compose.yml | grep -o 'docker.io/[^ ]*')
GCR_HASURA_IMAGE = $(HASURA_IMAGE:docker.io/hasura/%=eu.gcr.io/$(GCP_PROJ)/%)

test:
	@echo "Boom!  You've been tested."

stamps/prereq:
	sudo apt install podman-docker docker-compose sql-migrate postgresql-client
	systemctl --user enable podman.socket
	systemctl --user start podman.socket
	touch $@

stamps/database: stamps/prereq
	$(DC) up -d postgres
	-$(PG_COMMAND) createdb -U postgres hasura
	-$(PG_COMMAND) createdb -U postgres vaalidata
	touch $@

stamps/database-schema: stamps/database stamps/prereq
	sql-migrate up
	touch $@

stamps/database-data: stamps/database-schema stamps/prereq \
		data/ekv-2019_areas.csv \
		data/ekv-2019_candidates.csv \
		data/ekv-2019_area_candidate_votes.csv
	$(PSQL) -f ./scripts/ekv-2019_import.psql
	touch $@

stamps/graphql: stamps/database-data stamps/prereq
	$(DC) up -d
	until curl -s -o /dev/null http://localhost:18080; do \
		echo "Waiting for Hasura to come up..."; \
		sleep 1; \
	done
	touch $@

stamps/dev-env: config/hasura_metadata.json stamps/graphql stamps/data-prereq
	curl -d '{"type":"replace_metadata","args":'"$$(cat $<)"'}' http://localhost:18080/v1/metadata
	touch $@

stamps/deploy-prereq:
	sudo apt install apt-transport-https ca-certificates gnupg curl
	curl https://packages.cloud.google.com/apt/doc/apt-key.gpg \
	| sudo apt-key --keyring /usr/share/keyrings/cloud.google.gpg add -
	curl https://apt.releases.hashicorp.com/gpg | gpg --dearmor \
	| sudo tee /usr/share/keyrings/hashicorp-archive-keyring.gpg >/dev/null
	echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
	| sudo tee /etc/apt/sources.list.d/google-cloud-sdk.list
	echo "deb [signed-by=/usr/share/keyrings/hashicorp-archive-keyring.gpg] https://apt.releases.hashicorp.com $$(lsb_release -cs) main" \
	| sudo tee /etc/apt/sources.list.d/hashicorp.list
	sudo apt-get update
	sudo apt-get install google-cloud-cli terraform
	touch $@

stamps/gcloud-setup: stamps/deploy-prereq
	test -f $(HOME)/.config/gcloud/active_config || gcloud init
	gcloud services enable sqladmin.googleapis.com iam.googleapis.com \
		compute.googleapis.com servicenetworking.googleapis.com \
		cloudresourcemanager.googleapis.com vpcaccess.googleapis.com \
		containerregistry.googleapis.com run.googleapis.com
	gcloud iam service-accounts list --format 'value(email)' \
	| grep -q terraform-sa-1@ \
	|| gcloud iam service-accounts create terraform-sa-1 \
		--display-name 'Terraform Service Account'
	gcloud projects add-iam-policy-binding $(GCP_PROJ) \
		--role roles/editor --member 'serviceAccount:$(GCP_SA)'
	gcloud iam roles list --project $(GCP_PROJ) --format 'value(name)' \
	| grep -q terraformExtras \
	|| gcloud iam roles create terraformExtras --project $(GCP_PROJ)
	gcloud iam roles update terraformExtras --project $(GCP_PROJ) \
		--description 'Extra permissions needed by Terraform' \
		--permissions resourcemanager.projects.setIamPolicy,run.services.setIamPolicy
	gcloud projects add-iam-policy-binding $(GCP_PROJ) \
		--role projects/$(GCP_PROJ)/roles/terraformExtras \
		--member 'serviceAccount:$(GCP_SA)'
	gcloud iam service-accounts list --format 'value(email)' \
	| grep -q sql-connection-1@ \
	|| gcloud iam service-accounts create sql-connection-1 \
		--display-name 'Local development SQL connection SA'
	gcloud projects add-iam-policy-binding $(GCP_PROJ) \
		--role roles/cloudsql.client \
		--member 'serviceAccount:sql-connection-1@$(GCP_PROJ).iam.gserviceaccount.com'
	touch $@

gcp-deploy/sql-credentials.json: stamps/gcloud-setup
	test -f $@ \
	|| gcloud iam service-accounts keys create $@ \
		--iam-account 'sql-connection-1@$(GCP_PROJ).iam.gserviceaccount.com'
	chmod a+r $@  # because it needs to be mounted to sql-auth-proxy cont

gcp-deploy/gcloud-credentials.json: stamps/gcloud-setup
	test -f $@ \
	|| gcloud iam service-accounts keys create $@ --iam-account '$(GCP_SA)'

gcp-deploy/gcloud.auto.tfvars: config/database-password-root stamps/gcloud-setup
	echo 'gcp_project = "$(GCP_PROJ)"' > $@
	echo 'hasura_image = "$(GCR_HASURA_IMAGE)"' >> $@

stamps/terraform-setup: gcp-deploy/main.tf \
	  gcp-deploy/gcloud-credentials.json gcp-deploy/gcloud.auto.tfvars
	$(TF) init
	touch $@

stamps/gcp-database: $(wildcard gcp-deploy/*.tf) stamps/terraform-setup
	$(TF) apply -target=google_sql_user.hasura-pg-root
	touch $@

stamps/gcr-setup: stamps/gcloud-setup
	gcloud auth configure-docker
	touch $@

stamps/gcp-hasura-image: stamps/gcr-setup
	podman pull $(HASURA_IMAGE)
	podman tag $(HASURA_IMAGE) $(GCR_HASURA_IMAGE)
	podman push $(GCR_HASURA_IMAGE)
	touch $@

stamps/gcp-deploy: $(wildcard gcp-deploy/*.tf) \
		stamps/terraform-setup stamps/gcp-hasura-image
	$(TF) apply
	touch $@

config/database-password%:
	head -c 20 /dev/urandom | base64 > $@

stamps/deploy-database: config/database-password stamps/gcloud-setup \
		config/database-password-hasura config/database-password-import
	gcloud sql instances list --format='csv(name)' | grep -q hasura-pg \
	|| gcloud sql instances create hasura-pg --region europe-north1 \
		--database-version POSTGRES_13 --cpu 1 --memory 3840MiB \
		--root-password $$(cat $<)
	gcloud sql users create hasura --instance hasura-pg \
		--password $$(cat config/database-password-hasura)
	gcloud sql users create vdimport --instance hasura-pg \
		--password $$(cat config/database-password-import)
	gcloud sql databases list --format='csv(name)' --instance hasura-pg \
	| grep -q hasura \
	|| gcloud sql databases create hasura --instance hasura-pg
	gcloud sql databases list --format='csv(name)' --instance hasura-pg \
	| grep -q vaalidata \
	|| gcloud sql databases create vaalidata --instance hasura-pg
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

.PHONY: psql
psql: stamps/database
	$(PSQL)

