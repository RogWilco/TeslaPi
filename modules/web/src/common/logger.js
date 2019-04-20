'use strict';

const log4js = require('log4js');
const {logger: config} = require('../../config');

if (process.env.NODE_ENV != 'test') {
    log4js.configure(config);
}

module.exports = log4js;
