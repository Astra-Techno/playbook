<?php

define('PING4SMS_KEY',         getenv('PING4SMS_KEY')         ?: '');
define('PING4SMS_SENDER',      getenv('PING4SMS_SENDER')      ?: 'KOCORT');
define('PING4SMS_TEMPLATE_ID', getenv('PING4SMS_TEMPLATE_ID') ?: '');
define('PING4SMS_ROUTE',       getenv('PING4SMS_ROUTE')       ?: '2');
define('PING4SMS_BASE_URL',    'https://site.ping4sms.com/api/smsapi');
