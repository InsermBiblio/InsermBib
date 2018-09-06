.PHONY: save-db restore-db connect-mysql run-dev run-prod help

.DEFAULT_GOAL := help

help:
	@test -f /usr/bin/xmlstarlet || echo "Needs: sudo apt-get install --yes xmlstarlet"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'

# If the first argument is one of the supported commands...
SUPPORTED_COMMANDS := restore-db _restore_db save-db _save_db wp-cli-replace 
SUPPORTS_MAKE_ARGS := $(findstring $(firstword $(MAKECMDGOALS)), $(SUPPORTED_COMMANDS))
ifneq "$(SUPPORTS_MAKE_ARGS)" ""
    # use the rest as arguments for the command
    COMMAND_ARGS := $(wordlist 2,$(words $(MAKECMDGOALS)),$(MAKECMDGOALS))
    # ...and turn them into do-nothing targets
    $(eval $(COMMAND_ARGS):;@:)
endif

# If the command need the db password
DB_COMMANDS := _load_fixtures _save_db _restore_db
NEED_DB_PASSWORD := $(findstring $(firstword $(MAKECMDGOALS)), $(DB_COMMANDS))
ifneq "$(NEED_DB_PASSWORD)" ""
    DB_PASSWORD ?= $(shell stty -echo; read -p "Password: " DB_PASSWORD; stty echo; echo $$DB_PASSWORD)
endif

save-db: ## create a dump of the mariadb database arg: <name> default to current date
	@make _save_db $(COMMAND_ARGS) > /dev/null
	@ echo "dump successfully created"

_save_db:
ifdef COMMAND_ARGS
	docker exec insermbib_db_1 mysqldump --password=$(DB_PASSWORD) wordpress > backups/$(COMMAND_ARGS).sql
else
	docker exec insermbib_db_1 mysqldump --password=$(DB_PASSWORD) wordpress > backups/db_backup_$(shell date +%Y_%m_%d_%H_%M).sql
endif

restore-db: ## restore a given dump to the mariadb database list all dump if none specified
ifdef COMMAND_ARGS
	@make _restore_db $(COMMAND_ARGS) > /dev/null
	@ echo "backup successfully restored"
else
	echo 'please specify backup to restore':
	@ls -h ./backups
endif

deactivate_plugin: ## deactivate all wordpress plugin
	docker exec -i insermbib_db_1 mysql --password='$(DB_PASSWORD)' wordpress -e "UPDATE wp_options SET option_value = '' WHERE option_name = 'active_plugins';"

_restore_db:
	cat backups/$(COMMAND_ARGS) | docker exec -i insermbib_db_1 sh -c 'cat | mysql --password='$(DB_PASSWORD)' wordpress'

connect-mysql: ## connect into mysql
	docker exec -it bibcnrs_db_1 mysql --password wordpress


run-prod: ## launch insermbib for production environment
	docker-compose -f docker-compose.prod.yml up -d --force-recreate

cleanup-docker: ## remove all insermbib docker image
	test -z "$$(docker ps -a | grep insermbib)" || \
            docker rm --force $$(docker ps -a | grep insermbib | awk '{ print $$1 }')

stop: ## stop all insermbib docker image
	test -z "$$(docker ps | grep insermbib)" || \
            docker stop $$(docker ps -a | grep insermbib | awk '{ print $$1 }')

wp-cli-replace: ## allow to run replace one string by another inside wordpress database
	docker exec insermbib_wordpress_1 wp --allow-root --path=/var/www/html search-replace $(COMMAND_ARGS)

wp-cli: ## allow to run dockerized wp-cli command
	docker exec insermbib_wordpress_1 wp --allow-root --path=/var/www/html $(COMMAND_ARGS)

bump: ## create a file with current commit hash
	git rev-parse HEAD > .currentCommit
