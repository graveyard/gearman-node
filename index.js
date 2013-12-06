var path = __dirname + '/' + (process.env.TEST_GEARMAN_COV ? 'lib-js-cov' : 'lib-js');
module.exports = {
  Gearman: require(path + '/gearman'),
  Client: require(path + '/client'),
  Worker: require(path + '/worker')
};
