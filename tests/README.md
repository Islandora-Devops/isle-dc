# Test scripts

- [01-end-to-end.sh](#01-end-to-end.sh)
- [02-static-config.sh](#02-static-config.sh)
- [10-migration-backend-tests.sh](#10-migration-backend-tests.sh)
- [11-file-deletion-tests.sh](#11-file-deletion-tests.sh)
- [12-media-tests.sh](#12-media-tests.sh)
- [13-migration-entity-resolution.sh](#13-migration-entity-resolution.sh)
- [20-export-tests.sh](#20-export-tests.sh)
- [21-large-file-derivatives-nightly.sh](#21-large-file-derivatives-nightly.sh)
- [21-role-permission-tests.sh](#21-role-permission-tests.sh)

<h3 id="01-end-to-end.sh">- 01-end-to-end.sh</h3>

This script ==can== be ran by itself to test the end-to-end workflow. It runs the following steps:
1. Admin tests (end-to-end/tests/tests/admin/**/*.spec.js)
1. Add UI test data (end-to-end//tests/tests/ui/data-migrations.js)
1. UI tests (end-to-end//tests/tests/ui/*.spec.js)

##### Admin Tests
- end-to-end/tests/admin/add_collection.spec.js
  - Adds a collection object from https://islandora-idc.traefik.me/node/add/collection_object
- end-to-end/tests/admin/s3.spec.js
  - It uses this URL [saml login](https://islandora-idc.traefik.me/saml_login) to check the [SAML API integration](https://islandora-idc.traefik.me/simplesaml/module.php/core/authenticate.php?as=default-sp) via the test URL.
- end-to-end/tests/admin/saml_login.spec.js

##### UI Tests
- end-to-end/tests/ui/data-migrations.js
  - Adds test data to the UI.
  - Test several different scenarios (viewing pages, collection, media types, metadata exports, etc.)

<h3 id="02-static-config.sh">- 02-static-config.sh</h3>

Verifies that bad configuration in config/sync will cause a startup failure for Docker

<h3 id="10-migration-backend-tests.sh">- 10-migration-backend-tests.sh</h3>

This script ==can== be ran by itself to test the end-to-end workflow. It runs the following steps:

> "This script is the "controller" of the tests.  It is responsible for executing the various test frameworks and controls the shell exit code.  Each test framework executes in a Docker container, so there are no dependencies or configuration required to perform the tests, except for a working Docker." - [tests/10-migration-backend-tests/README.md](https://github.com/jhu-idc/idc-isle-dc/blob/development/tests/10-migration-backend-tests/README.md)

<h3 id="11-file-deletion-tests.sh">- 11-file-deletion-tests.sh</h3>

`make test test=11-file-deletion-tests.sh`

<h3 id="12-media-tests.sh">- 12-media-tests.sh</h3>

This script migrates the media files and verifies that derivatives are created and file naming conventions are correct.

Some checks are at http://migration-assets/assets/image/formats/tiff.tif

<h3 id="13-migration-entity-resolution.sh">- 13-migration-entity-resolution.sh</h3>

- Applies a path to [codebase/config/sync/migrate_plus.migration.idc_ingest_new_items.yml](https://github.com/jhu-idc/idc-isle-dc/blob/development/codebase/config/sync/migrate_plus.migration.idc_ingest_new_items.yml)

__WARNING:__ This could become problematic if the fields change.

<h3 id="20-export-tests.sh">- 20-export-tests.sh</h3>

> There are a few fields that might include more data in the quad when exported than was there during import. Export needs to be specific with a few
fields, so the bundle data might be there, whereas it wasn't there on ingest. - [tests/20-export-tests/README.md](https://github.com/jhu-idc/idc-isle-dc/blob/development/tests/20-export-tests/README.md)

<h3 id="21-large-file-derivatives-nightly.sh">- 21-large-file-derivatives-nightly.sh</h3>

- Migrates in test data to trigger derivative creation
- Verifies that derivatives are created
- Additional test to make sure the JWT expiry is equal to or greater than 14400

<h3 id="21-role-permission-tests.sh">- 21-role-permission-tests.sh</h3>
This adds the users and permissions for testing the role permissions.
- tests/21-role-permission-tests/testcafe/role_permissions.spec.js
- tests/21-role-permission-tests/testcafe/roles.js
- tests/21-role-permission-tests/testcafe/util.js
