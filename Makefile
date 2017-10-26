help:
	@fgrep -h "##" $(MAKEFILE_LIST) | fgrep -v fgrep | sed -e 's/\\$$//' | sed -e 's/##//'

dog: ## Run dogma
	mix dogma

cov: ## Run coverage
	MIX_ENV=test mix coveralls.html

w:   ## Run test watcher
	mix test.watch
