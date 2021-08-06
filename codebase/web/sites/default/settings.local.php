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
$settings['s3fs.use_s3_for_private'] = TRUE;
$settings['s3fs.upload_as_private'] = TRUE;
$config['s3fs.settings']['bucket'] = getenv('DRUPAL_DEFAULT_S3_BUCKET') ?: 'idc';
$config['s3fs.settings']['hostname'] = getenv('DRUPAL_DEFAULT_S3_HOSTNAME');
$config['s3fs.settings']['use_cname'] = (bool) getenv('DRUPAL_DEFAULT_S3_USE_CNAME') ?: false;
$config['s3fs.settings']['use_customhost'] = (bool) getenv('DRUPAL_DEFAULT_S3_USE_CUSTOMHOST') ?: false;
$config['s3fs.settings']['use_path_style_endpoint'] = (bool) getenv('DRUPAL_DEFAULT_S3_USE_PATH_STYLE_ENDPOINT') ?: false;

# This will be overridden by s3fs, but needs a value in order to enable private FS at all.
$settings['file_private_path'] = '/tmp';

# This needs to be defined in in order to avoid crashing
$settings['flysystem']['fedora']['config']['root'] = 'http://fcrepo.isle-dc.localhost/fcrepo/rest/';

$config['islandora.settings']['jwt_expiry'] = str_replace("'", "", str_replace('"', '', getenv('DRUPAL_JWT_EXPIRY_INTERVAL') ?: '+2 hour'));
