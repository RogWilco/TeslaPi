'use strict';

const config = {
    web: {
        protocol: 'http',
        host: 'localhost',
        port: 80,
    },
    logger: {
        appenders: {
            console: {
                type: 'console',
            },
            file: {
                type: 'file',
                filename: 'log/application.log',
            }
        },
        categories: {
            default: {
                appenders: [
                    'console',
                ],
                level: 'debug',
            },
            web: {
                appenders: [
                    'console',
                    'file',
                ],
                level: 'debug',
            },
        },
    },
};

module.exports = config;
