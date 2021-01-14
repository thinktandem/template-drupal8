<?php
/**
 * @file
 * Lando settings.
 */

// Configure the database if on Lando
// @todo: eventually we want to remove this in favor of Lando directly
// spoofing the needed PLATFORM_* envvars.
if (isset($_SERVER['LANDO'])) {
  // Only load dev settings on non admin pages.
  // This prevents very slow loading admin pages.
  // Especially when using some modules like layout builder.
  if (strpos($_SERVER["REQUEST_URI"], '/admin/') === FALSE && php_sapi_name() !== 'cli') {
    $settings['container_yamls'][] = DRUPAL_ROOT . '/sites/development.services.yml';
    $settings['cache']['bins']['render'] = 'cache.backend.null';
    $settings['cache']['bins']['dynamic_page_cache'] = 'cache.backend.null';
    $settings['cache']['bins']['page'] = 'cache.backend.null';
    $config['system.performance']['css']['preprocess'] = FALSE;
    $config['system.performance']['js']['preprocess'] = FALSE;
  }
  
  // Fixes annoying perm issues on local.
  $settings['skip_permissions_hardening'] = TRUE;
}
