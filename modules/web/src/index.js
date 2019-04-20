'use strict';

const express = require('express');
const logger = require('./common/logger');
const {web: config} = require('../config');

const app = express();

app.set('x-powered-by', false);

app.listen(config.port, function() {
	logger.getLogger('web').info(`Listening: ${config.protocol}://${config.host}:${config.port}`);
})

module.exports = app;
