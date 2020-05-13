<?php

// @codingStandardsIgnoreFile

/**
 * @file
 * Isle settings override for drupal 8.
 */

 /**
  * Database connection settings.
  */
$databases['default']['default'] = [
  'database' => getenv('DB_NAME'),
  'username' => getenv('DB_USER'),
  'password' => getenv('DB_PASSWORD'),
  'host' => getenv('DB_HOST'),
  'port' => getenv('DB_PORT'),
  'driver' => 'mysql',
  'namespace' => 'Drupal\\Core\\Database\\Driver\\mysql',
  'prefix' => '',
  'collation' => 'utf8mb4_general_ci',
];

/**
 * Files path settings.
 */
$settings['file_public_path'] = 'sites/default/files';
$settings['file_private_path'] = getenv('FILES_DIR') . '/private';
$settings['file_temporary_path'] = '/tmp';

/**
 * Hash salt setting.
 */
if (empty($settings['hash_salt'])) {
  $settings['hash_salt'] = getenv('DRUPAL_HASH_SALT', true) ?: getenv('DRUPAL_HASH_SALT');
}

/**
 * Config directory setting.
 */
// $settings['config_sync_directory'] = '../config/sync';

/**
 * Flysystem
 */
$settings['flysystem'] = [
  'fedora' => [
    'driver' => 'fedora',
    'config' => [
      'root' => 'http://fedora:8080/fcrepo/rest/',
    ],
  ],
];
