TESTS=$(shell cd test && ls *.coffee | sed s/\.coffee$$//)
.PHONY: test test-cov $(TESTS)

test: $(TESTS)

test-cov:
	./reset_gearmand.sh
	rm -rf lib-js lib-js-cov
	coffee -c -o lib-js lib
	jscoverage lib-js lib-js-cov
	COV_GEARMAN=1 node_modules/mocha/bin/mocha -R html-cov --compilers coffee:coffee-script test/{test,test-raceconditions}.coffee | tee coverage.html
	open coverage.html

$(TESTS):
	./reset_gearmand.sh
	DEBUG=* NODE_ENV=test node_modules/mocha/bin/mocha --timeout 60000 --compilers coffee:coffee-script test/$@.coffee
