# usage:
# `make build` or `make` compiles lib/*.coffee to lib-js/*.js (for all changed lib/*.coffee)
# `make lib/gearman.coffee` compiles just that file to lib-js
# `make test` runs all the tests
# `make test/.coffee` runs just that test
SHELL:=/bin/bash
TESTS=$(shell cd test && ls *.coffee | sed s/\.coffee$$//)
.PHONY: test test-cov $(TESTS)
LIBS=$(shell find . -regex "^./lib\/.*\.coffee\$$" | sed s/\.coffee$$/\.js/ | sed s/lib/lib-js/)

build: $(LIBS)

lib-js/%.js : lib/%.coffee
	node_modules/coffee-script/bin/coffee --bare -c -o $(@D) $(patsubst lib-js/%,lib/%,$(patsubst %.js,%.coffee,$@))

test:	build	$(TESTS)

test-cov: build
	@if [[ -z "$(DRONE)" ]]; then \
		./reset_gearmand.sh; \
	fi
	rm -rf lib-js lib-js-cov
	coffee -c -o lib-js lib
	jscoverage lib-js lib-js-cov
	COV_GEARMAN=1 node_modules/mocha/bin/mocha -R html-cov --compilers coffee:coffee-script test/{test,test-raceconditions}.coffee | tee coverage.html
	open coverage.html

$(TESTS): build
	@if [[ -z "$(DRONE)" ]]; then \
		./reset_gearmand.sh; \
	fi
	DEBUG=* NODE_ENV=test node_modules/mocha/bin/mocha -r coffee-errors --timeout 60000 --compilers coffee:coffee-script test/$@.coffee

publish: clean build
	$(eval VERSION := $(shell grep version package.json | sed -ne 's/^[ ]*"version":[ ]*"\([0-9\.]*\)",/\1/p';))
	@echo \'$(VERSION)\'
	$(eval REPLY := $(shell read -p "Publish and tag as $(VERSION)? " -n 1 -r; echo $$REPLY))
	@echo \'$(REPLY)\'
	@if [[ $(REPLY) =~ ^[Yy]$$ ]]; then \
	    npm publish; \
	    git tag -a v$(VERSION) -m "version $(VERSION)"; \
	    git push --tags; \
	fi

clean:
	rm -rf lib-js lib-js-cov
