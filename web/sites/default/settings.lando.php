<?php
/**
 * @file
 * Lando settings.
 */

// Configure the database if on Lando
// @todo: eventually we want to remove this in favor of Lando directly
// spoofing the needed PLATFORM_* envvars.
if (isset($_SERVER['LANDO'])) {

  // Set the database creds
  $databases['default']['default'] = [
    'database' => 'drupal8',
    'username' => 'drupal8',
    'password' => 'drupal8',
    'host' => 'database',
    'port' => '3306',
    'driver' => 'mysql'
  ];

  // And a bogus hashsalt for now
  $settings['hash_salt'] = json_encode($databases);
  // Fixes annoying perm issues on local.
  $settings['skip_permissions_hardening'] = TRUE;
}
