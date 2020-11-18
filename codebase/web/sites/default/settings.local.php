<?php

/* this adjusts how large the title field is on nodes and
 * how large the name field is on all taxonomies
 */
$settings['node_title_length_chars'] = 500;
$settings['taxonomy_term_title_length_chars'] = 2000;

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

$settings['s3fs.access_key'] = getenv('DRUPAL_DEFAULT_S3_ACCESS_KEY');
$settings['s3fs.secret_key'] = getenv('DRUPAL_DEFAULT_S3_SECRET_KEY');
$config['s3fs.settings']['bucket'] = getenv('DRUPAL_DEFAULT_S3_BUCKET') ?: 'idc';
$config['s3fs.settings']['hostname'] = getenv('DRUPAL_DEFAULT_S3_HOSTNAME');
$config['s3fs.settings']['use_s3_for_private'] = TRUE;
$config['s3fs.settings']['use_s3_for_public'] = FALSE;
$config['s3fs.settings']['use_cname'] = getenv('DRUPAL_DEFAULT_S3_USE_CNAME') ?: false;
$config['s3fs.settings']['use_customhost'] = getenv('DRUPAL_DEFAULT_S3_USE_CUSTOMHOST') ?: false;
$config['s3fs.settings']['use_path_style_endpoint'] = getenv('DRUPAL_DEFAULT_S3_USE_PATH_STYLE_ENDPOINT') ?: false;
$config['file_private_path'] = getenv('DRUPAL_DEFAULT_S3_PRIVATE_PATH') ?: 'pr';
