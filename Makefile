test-cov:
	./reset_gearmand.sh
	rm -rf lib-js lib-js-cov
	coffee -c -o lib-js lib
	jscoverage lib-js lib-js-cov
	COV_GEARMAN=1 node_modules/mocha/bin/mocha -R html-cov --compilers coffee:coffee-script test/{test,test-raceconditions}.coffee | tee coverage.html
	open coverage.html

test:
	./reset_gearmand.sh
	#node_modules/mocha/bin/mocha --compilers coffee:coffee-script test/{test,test-raceconditions}.coffee
	node_modules/mocha/bin/mocha --compilers coffee:coffee-script test/test-retry.coffee
