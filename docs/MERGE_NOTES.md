## How to run your own app

* make folder 'codebase`
* git clone your site into it 
* copy in the new settings.php.local
* boot the system up, and don't care that drupal keeps crashing. when we have the database in place it will stop
* docker cp the database in and import it (root/password will work; db name is drupal_default)
* `COMPOSER_MEMORY_LIMIT=-1 composer install`