var path = __dirname + '/' + (process.env.TEST_GEARMAN_COV ? 'lib-js-cov' : 'lib-js');
module.exports = require(path + '/mocks');
