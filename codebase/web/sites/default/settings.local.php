<?php


$settings['hash_salt'] = getenv('DRUPAL_DEFAULT_SALT');

$settings['config_sync_directory'] = '/var/www/drupal/config/sync';

$databases['default']['default']['database'] =  getenv('DRUPAL_DEFAULT_DB_NAME') ?: 'drupal_default';
$databases['default']['default']['username'] =  getenv('DRUPAL_DEFAULT_DB_USER') ?: 'drupal_default';
$databases['default']['default']['password'] =  getenv('DRUPAL_DEFAULT_DB_PASSWORD');
$databases['default']['default']['host'] =  getenv('DRUPAL_DEFAULT_DB_HOST') ?: 'database';
$databases['default']['default']['port'] =  getenv('DRUPAL_DEFAULT_DB_PORT') ?: '3306';
$databases['default']['default']['prefix'] = '';
$databases['default']['default']['driver'] = getenv('DRUPAL_DEFAULT_DB_DRIVER') ?: 'mysql';
$databases['default']['default']['namespace']  = 'Drupal\\Core\\Database\\Driver\\';
$databases['default']['default']['namespace'] .= $databases['default']['default']['driver'];
