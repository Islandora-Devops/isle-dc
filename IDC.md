# IDC development platform

Leverages ISLE to provide a local development environment for the IDC stack, with particular focus on development/testing of
the Drupal site.

## Contents

* Our Drupal site is in `codebase`.
  * Use `composer` to add, remove, or update dependencies in `codebase/composer.json` and `codebase/composer.lock` when developing
  * Dependencies are not vendored, so you need to do a composer install.  This is included in `make bootstrap`
* IDC development-specific environment variables are in `.env` and `docker-compose.env.yml`
* An idc-specific Makefile `idc.Makefile` defines additional make targets available for `make

## Quick Start

To start the IDC development environment, run

    make up

This will build a `docker-compose` file, run `composer install` to locally install all dependencies for our site (which will
take a few minutes when done the first time, but will be much quicker subsequent times), and start the stack.  The stack will
start from a known snapshot state, which currently is an entirely empty (but initialized) Drupal.

To reset to a known Drupal state, run

    make reset

This will remove all content from volumes that you may have added, remove all php files downloaded by composer,
launch using the snapshot as its initial state, then import any config from config/sync.  
`composer install` will run automatically as part of the startup process.

A slightly quicker way to reset to a known state is:

    docker-compose down -v
    make up

This removes all content from volumes, restores from the last snapshot, pulls in config from config/sync, but does _not_ remove composer-managed PHP files.  `composer install` will still run upon startup, but it needs to do much less.

To dump the site's configuration so that it can be committed to `git`, do

    make config-export

## Make targets

There are several Make targets in the `Makefile`, and its idc-specific companion `idc.Makefile` (which are included by default,
so no need to do anything special other than `make` to invoke them).  A few useful targets are as follows:

* **make reset** Burn everything down and create a fresh installation _from the snapshot image_.  composer-installed modules and dependencies **do not** survive; they will be deleted, then installed from scratch via `composer install` when the drupal container starts.  Once up, configuration will from `config/sync` will be imported.
* **make composer-install**  Use the Drupal container to run a `composer install`.  This avoids having to install composer on your local system.  Note:  the Drupal image startup process implicitly runs `composer install` already, so this make target is used for on-demand composer installs.
* **make cache-rebuild** Uses Drush inside the Drupal container to rebuild Drupal's cache.
* **make config-export** Exports all current active Drupal config to the `codebase/config/sync` directory, so that it can be committed to git.
* **make up** Brings up the development environment, including running `composer install`.  If there is no pre-existing state (e.g. after a `docker compose down -v`), this will load initial state from the current snapshot, and pull in config from `config/sync`.  Otherwise, if there _is_ pre-existing state (i.e. after a `docker stop`), docker will start, `composer install` will run, but configuration from `config/sync` will _not_ be imported.
* **make test** Runs all tests.  Optionally, takes a `test=` parameter for running a particular test suite.  NOTE:  Running all tests without a `test=` argument will result in all local state being wiped out
* **make dev-up** Launches the stack with a Drupal image configured with XDebug for IDE-based debugging.  Updates the environment requiring `make dev-down` to be invoked at the conclusion of a development session.
* **make dev-down** Stops the Drupal development image, and resets the environment to using production.

A few specialized targets are:

* **make bootstrap** Burn everything down and create a fresh installation from scratch, deleting any pre-existing data, and starting from a completely empty state.  Only the list of modules in `composer.json` (and dependencies in `composer.lock`) survives the process.
* **make minio-bucket** Create a new bucket in minio based on the environment variables present in `.env`
* **make snapshot** Create a snapshot of the current Drupal state (db, content files, etc), so that you can reset to this state at will, or push it so that others can.
* **make snapshot-push** Push the current snapshot image to the container registry
* **make static-docker-compose.yml** Make a docker-compose.yml based off non-development "static" environment.  Notably:
  * A `drupal-static` image is built or pulled, which has `codebase` baked in, and is used in place of the normal `drupal` image
  * `codebase` is no longer bind mounted
* **make static-drupal-image** builds (or pulls, if published) a "static" drupal image suitable for deployment in the cloud.  This image:
  * Has the contents of `codebase` baked into it, as well as all dependencies via `composer install`
  * Will load its config from `config/sync` upon startup
  * Is named `drupal-static` and is tagged based on `git describe --tags`.
* **make minio_bucket** Creates a new S3 bucket in minio for IDC.  The empty bucket should be part of the snapshot, so this is really only
  useful for bootstrapping new snapshots from scratch.
  
## Running tests

To run all tests, with the environment (configuration, modules, content) reset between each test, run `make test`.  This
is the make target used to run tests during CI.   To run an individual test, run `make test test=<name of test>`, where `<name of test>` is the name of a test script in the `tests` directory, e.g. `make test test=01-end-to-end.sh`.

When a single test is specified with the `test=` argument, the environment is _not_ reset for the execution of the test.
That is, the existing configuration, content, and modules present in the current codebase are used.  This is the recommended (and really only supported way) of running your tests while iterating.

Some additional notes about the test execution environment:
* Tests are run in a subshell given the environment from `.env` and functions from `tests/.includes.sh`.
  * To share common test-related variables or functions between tests, add them to `tests/.includes.sh`.
  * Variables added to `.env` are automatically available to the test script.
* The `test=` argument to `make test` accepts the name of the test suite, minus the `.sh` ending; `make test test=01-end-to-end.sh` and `make test test=01-end-to-end` (no `.sh` extension) will both work.
* Directly executing the test script (e.g. `cd`ing into `tests` and invoking `./01-end-to-end.sh` on its own) will _no longer work reliably_.
  * Instead, invoke the test using `make test=<test name>`
  * This is because test scripts are _provided_ the environment.  If their environment is not properly set up, they won't be able to execute properly.  The test controller (`run-tests.sh`) insures that the test environment is properly set up.

## S3 file storage

Drupal is configured to store media on the `private://` filesystem, backed by S3.  The `s3fs` module provides this s3-backed implementation of the `private://` filesystem.  For the `idc-isle-dc` development environment, `minio` ([https://minio-idc.traefik.me][https://minio-idc.traefik.me]) provides the S3 API.  Cloud/production instances will use Amazon S3.

### Configuration
Configuration is via environment variables

|Env Var|Default Value|Description|
|-------|-------------|-----------|
|DRUPAL_DEFAULT_MIGRATIONS_VALIDATE|true|Determines whether migrations will perform validation|
|DRUPAL_DEFAULT_S3_ACCESS_KEY|-|S3 access key|
|DRUPAL_DEFAULT_S3_SECRET_KEY|-|S3 secret key|
|DRUPAL_DEFAULT_S3_BUCKET|idc|S3 bucket name|
|DRUPAL_DEFAULT_S3_USE_CUSTOMHOST|false|Connect to an S3-compatible storage service other than Amazon. |
|DRUPAL_DEFAULT_S3_HOSTNAME|-|S3 hostname; use only if `DRUPAL_DEFAULT_USE_CUSTOMHOST` is true|
|DRUPAL_DEFAULT_S3_USE_CNAME|false|Serve files from a custom domain by using an appropriately named bucket, e.g. "mybucket.mydomain.com".|
|DRUPAL_DEFAULT_S3_USE_PATH_STYLE_ENDPOINT|false|Send requests to a path-style endpoint, instead of a virtual-hosted-style endpoint. For example, http://s3.amazonaws.com/bucket, insead of http://bucket.s3.amazonaws.com. |
## Debugging

### TL;DR

* Install [browser extension](https://xdebug.org/docs/step_debug#browser-extensions)
* make dev-up
* set breakpoint
* load page, trip breakpoint, repeat
* make dev-down

### Supported Env Vars

|Env Var|Default Value|Description|
|-------|-------------|-----------|
|XDEBUG_CONFIG|n/a|Allows for multiple XDebug config params to be set in a string.  Used for CLI debugging.|
|XDEBUG_SESSION|n/a|Enables XDebug when present.  Used for CLI debugging.|
|XDEBUG_MODE|`develop,debug,trace`|Supported XDebug modes.  Used for browser-based debugging|
|XDEBUG_LOG|`/var/www/drupal/xdebug.log`|XDebug logfile.  Used for browser-based debugging|
|XDEBUG_LOGLEVEL|`7`|XDebug log level. Used for browser-based debuggging.|
|XDEBUG_DISCOVERCLIENTHOST|`false`|If XDebug should attempt to discover the debugging client host.  Used for browser-based debugging.|
|XDEBUG_CLIENTHOST|`host.docker.internal`|The address of the debugging client host.  Used for browser-based debugging.|

## About

Allows a developer to launch Drupal with step-wise debugging enabled.  The three supported use cases are:
* Debugging human-mediated interactions with Drupal (i.e. what most developers would consider to be "debugging")
* Debugging CLI commands (e.g. `drush`) and/or PHP code executed on container startup
* Debugging service-mediate interactions with Drupal

Each use case requires setting a different combination of XDebug settings.  By default, the Drupal development image is configured to support the primary use-case, step-enabled debugging of PHP from a browser.  Enabling all the use cases at once would be counter-productive from a performance standpoint.

Debugging Drupal interactively from a browser requires the installation of an XDebug helper plugin, so if you don't have one installed, you'll need to do so.
* [Firefox](https://addons.mozilla.org/en-GB/firefox/addon/xdebug-helper-for-firefox/)
* [Chrome](https://chrome.google.com/extensions/detail/eadndfjplgieldjbigjakmdgkmoaaaoc)
* [Safari](https://apps.apple.com/app/safari-xdebug-toggle/id1437227804?mt=12)

To run the debugging container:
* Determine which use case applies, and set the environment accordingly in `docker-compose.drupal-dev.yml`.  If you want to debug Drupal with your browser and an IDE, you don't need to change anything.
* Run `make dev-up`

> When your debugging session is over, it is important to remember to run `make dev-down`

In your IDE, configure a PHP/XDebug development session.  Your IDE must listen for debugging requests on port `9003`.  Set a breakpoint.  In your browser, activate the XDebug helper by selecting "Debug", then make a request to Drupal which will activate your breakpoint.  Your browser should prompt you to map the file from the remote server to your local filesystem, and then you can perform step-by-step debugging.

There are a few ways to determine whether you've successfully started the development environment correctly:
* First, `docker ps` should list a running container named `<repo>/drupal-dev:<tag>`, and there should be _no_ other containers named `<repo>/drupal` running.
* Second, create a file named `xdebug.php` in codebase root: `echo "<?php xdebug_info();" > codebase/xdebug.php`, then in your browser visit `https://islandora-idc.traefik.me/xdebug.php`.  Information about XDebug should appear, including its settings.  This is a handy way to double-check XDebug's runtime configuration, especially for more complex debugging scenarios.

> .gitignore is set up to ignore any file that is prefixed with `xdebug`.  If you need to create files to support your debug session, or store output from your debug session, name them `xdebug<something>` to avoid committing debug artifacts.

* A third check, which should be unnecessary, is to `exec` into the `drupal-dev` container and run `php -v`; the output should reference XDebug version 3.

If first two conditions are met, you should be able to start a debug session.  If you can't, then check for the presence of `xdebug.log` in the codebase directory for clues, double check your IDE settings, and check the output of `php -v` in the `drupal-dev` container.  The IDE must accept connections on port `9003`, and XDebug must know the IP address of your machine.  By default, XDebug connects to `host.docker.internal`, which is a special DNS name for the host computer.

To switch back from the debugging container:
* Run `make dev-down`

## Snapshots

Snapshots are Docker images that contain Drupal state (content files, database, SOLR indexes, Fedora files, etc).  When Docker starts,
all Docker volumes will be populated with files from the snapshot image.  The net result is that an environment will start quickly,
from a known state, with pre-populated content.

After Docker starts from a snapshot, data subsequent in Docker's volumes is ephemeral.  It will persist across `stop` and `down`, but can be wiped out by

    docker-compose down -v

When docker subsequently starts, it will start from the known snapshot state.  You are free to [take a snapshot](#taking-and-publishing-snapshots)
whenever you want a checkpoint you can reliably reset Drupal to.

### Images

The image used for the snapshot is specified via environment variables in `.env`.  For example:

    # Docker image and tag for snapshot image
    SNAPSHOT_IMAGE=birkland/snapshot
    SNAPSHOT_TAG=upstream-20201007-739693ae-12-ga409e4d8.1602146397

When the `docker-compose.yml` make target is run, that image and tag will be specified in the docker-compose file.  The images contain data that are
copied to Docker volumes upon initial startup of the stack (i.e. snapshots are deployed only once, until all volumes are wiped out via `docker-compose down -v`).  Because they are just regular docker images, they can be pushed and puled from container registry as usual.

### Taking and publishing snapshots

To take a snapshot, run

    make snapshot

This will do the following:

* stop the docker-compose stack
* dump the contents of the volumes
* create a new image from the contents of the volume
* give the image a unique tag based on the current git commit, and the date
* update the `.env` file to specify the just-taken `SNAPSHOT_TAG`
* rebuild the `docker-compose.yml` file to specify that tag
* start docker-compose

If you want to commit that snapshot so that others can use it, you need to commit `.env` (which contains the tag of the snapshot image),
and publish the snapshot image to a Docker registry via

    make snapshot-push

Make sure you do both steps!  You need to push the image (so others can pull it), and push `.env` (so others can check out and run it).

# SAML Configuration

Drupal incorporates its own SAML Service Provider using [SimpleSAMLphp][simplesaml]; an Apache-based SP proxy (c.f. PASS SAML configuration) is _not_ used, and would be incompatible with Drupal.  The SimpleSAMLphp SP will be used in development and production environments (including all cloud-based instances).

The developer environment includes a mock Shibboleth Identity Provider (IdP) and LDAP user store to serve as a backend for user attributes.  These services would also be used when running integration tests, e.g. as a part of a PR or locally-executed tests.  The production environment would _not_ deploy these mock services.

SimpleSAMLphp has an administrative [web interface][simplesaml-webadmin] which supports:
  * diagnostics and configuration testing
  * testing logins, including viewing attribute assertions by the IdP
  * SP metadata generation (used to generate SP `EntityDescriptor` XML used by Shibboleth IdPs)
  * IdP XML metadata conversion (used to transform Shibboleth IdP metadata for use by SimpleSAMLphp)

Clicking on the Federation tab, and then click on the link labeled [Show metadata][sp-gen-md] under the heading “SAML 2.0 SP Metadata” will generate the SAML metadata to provide to the IdP. Testing authentication and attributes presented by the IdP is best performed using this admin interface.

Runtime parameterization of the IdP and SP is accomplished using a mixture of environment variables and secrets.  Two containers use these secrets: the `idp` and `drupal` containers.  Secrets are defined in `docker-compose.yml` from the consitutient service definitions in `docker-compose.saml.yml` and `docker-compose.local.yml`.

For a deeper understanding of SAML certificate roles, this [primer][cert-primer] may help.

## Requested Attributes

|Allocation<sup>1</sup>|SAML 1<sup>2</sup>|SAML 2<sup>3</sup>|
|---|---|---|
|eduPersonAffiliation|urn:mace:dir:attribute-def:eduPersonAffiliation|1.3.6.1.4.1.5923.1.1.1.1|
|eduPersonUniqueId|urn:oid:1.3.6.1.4.1.5923.1.1.1.13|1.3.6.1.4.1.5923.1.1.1.13|
|eduPersonPrincipalName|urn:mace:dir:attribute-def:eduPersonPrincipalName|1.3.6.1.4.1.5923.1.1.1.6|
|eduPersonScopedAffiliation|urn:mace:dir:attribute-def:eduPersonScopedAffiliation|1.3.6.1.4.1.5923.1.1.1.9|
|eduPersonAffiliation|urn:mace:dir:attribute-def:eduPersonAffiliation|1.3.6.1.4.1.5923.1.1.1.1|
|employeeNumber|urn:mace:dir:attribute-def:employeeNumber|2.16.840.1.113730.3.1.3|
|displayName|urn:mace:dir:attribute-def:displayName|2.16.840.1.113730.3.1.241|
|givenName|urn:mace:dir:attribute-def:givenName|2.5.4.42|
|departmentNumber|urn:mace:dir:attribute-def:departmentNumber|2.16.840.1.113730.3.1.2|
|mail|urn:mace:dir:attribute-def:mail|urn:oid:0.9.2342.19200300.100.1.3|

> <sup>1</sup> urn:oasis:names:tc:SAML:2.0:attrname-format:basic

> <sup>2</sup> urn:mace:shibboleth:1.0:attributeNamespace:uri

> <sup>3</sup> urn:oasis:names:tc:SAML:2.0:attrname-format:uri

The `authsources.php` file contains the requested attributes.  These are hardcoded, and are _not_ parameterized.

See the [SimpleSAMLphp User Sync page][simplesaml-usersync] for how these attributes may be mapped to Drupal user attributes or role selection.

> Note: 'mail' and 'eduPersonPrincipleName' are required attributes

## Env vars

These are truly environment variables (in the sense that they are not _secrets_).  Cloud-based installations will need to update these to expected values.

|Variable Name|Default Value|Location|Description|
|---|---|---|---|
|SP_BASEURL|https://islandora-idc.traefik.me|`.env` file|Base URL for SP services. Cloud-based installations will need to update these to expected values.|
|SP_ENTITYID|https://islandora-idc.traefik.me/sp/shibboleth|`.env` file|SP entity ID (a URI). Cloud-based installations will need to update these to expected values.|
|IDP_BASEURL|https://islandora-idp.traefik.me:4443|`.env` file|Base URL for IdP services. Cloud-based installations will need to update these to expected values.|
|IDP_ENTITYID|https://islandora-idp.traefik.me/idp/shibboleth|`.env` file|IdP entity ID (a URI). Cloud-based installations will need to update these to expected values.|
|DRUPAL_DEFAULT_SITE_URL|https://islandora-idc.traefik.me|`docker-compose.env.yml`|Use to derive the SimpleSAMLphp `baseurlpath`|
|DRUPAL_SP_TECHCONTACTNAME|Moo Cow|`docker-compose.env.yml`|Some information about the technical persons running this installation. The email address will be used as the recipient address for error reports, and also as the technical contact in generated metadata.|
|DRUPAL_SP_TECHCONTACTEMAIL|moo@cow.org|`docker-compose.env.yml`|Some information about the technical persons running this installation. The email address will be used as the recipient address for error reports, and also as the technical contact in generated metadata.|
|DRUPAL_SP_PROTECTINDEXPAGE|false|`docker-compose.env.yml`|Set this options to true if you want to require administrator password to access the web interface or the metadata pages, respectively.|
|DRUPAL_SP_PROTECTMETADATAPAGE|false|`docker-compose.env.yml`|Set this options to true if you want to require administrator password to access the web interface or the metadata pages, respectively.|
|DRUPAL_SP_CHECKFORUPDATES|true|`docker-compose.env.yml`|Set this option to false if you don't want SimpleSAMLphp to check for new stable releases when visiting the configuration tab in the web interface.|
|DRUPAL_SP_ASSERTIONALLOWEDCLOCKSKEW|180|`docker-compose.env.yml`|Set the allowed clock skew between encrypting/decrypting assertions|
|DRUPAL_SP_SESSION_DURATIONSECONDS|28800|`docker-compose.env.yml`|This value is the duration of the session in seconds. Make sure that the time duration of cookies both at the SP and the IdP exceeds this duration.|
|DRUPAL_SP_SESSION_DATASTORETIMEOUTSECONDS|14400|`docker-compose.env.yml`|Sets the duration, in seconds, data should be stored in the datastore. As the data store is used for login and logout requests, this option will control the maximum time these operations can take.|
|DRUPAL_SP_SESSION_STATETIMEOUTSECONDS|3600|`docker-compose.env.yml`|Sets the duration, in seconds, auth state should be stored.|
|DRUPAL_SP_SESSION_COOKIENAME|SimpleSAMLSessionID|`docker-compose.env.yml`|Option to override the default settings for the session cookie name|
|DRUPAL_SP_SESSION_COOKIELIFETIMESECONDS|0|`docker-compose.env.yml`|Expiration time for the session cookie, in seconds. Defaults to 0, which means that the cookie expires when the browser is closed.|
|DRUPAL_SP_SESSION_COOKIEPATH|/|`docker-compose.env.yml`|Limit the path of the cookies. Can be used to limit the path of the cookies to a specific subdirectory.|
|DRUPAL_SP_SESSION_COOKIESECURE|false|`docker-compose.env.yml`|Set the secure flag in the cookie. Set this to TRUE if the user only accesses your service through https. If the user can access the service through both http and https, this must be set to FALSE.|
|DRUPAL_SP_LOGGING_LEVEL|INFO|`simplesaml_config.patch`, `<vendor dir>/simplesamlphp/simplesamlphp/config/config.php`|Set the log level used by the SimpleSAMLphp SP.  Valid values are 'ERR', 'WARNING', 'NOTICE', 'INFO', 'DEBUG'|
|DRUPAL_SP_LOGGING_HANDLER|errorlog|`simplesaml_config.patch`, `<vendor dir>/simplesamlphp/simplesamlphp/config/config.php`|Sets the log handler used by the SimpleSAMLphp SP.  Valid values are 'syslog', 'file', 'errorlog', 'stderr'|


## SAML Secrets

It should be said immediately that not every key/value pair in the `saml-secrets.yml` file is strictly a secret.  For example, public keys (in the form of X509 certs) would not be considered a secret.  However, to facilitate uniform processing of private/public key _pairs_ and other values, using a single secrets file together with the `confd` `file` backend makes sense.  `saml-secrets.yml` uses a structure well-known to the containers that process its contents.  Renaming, removing, or adding keys may impact the processing of its content by the `idp` or `drupal` containers.

In the Docker environment, there are unfortunate layers of indirection when it comes to the use of secrets.

First and foremost, secrets are defined in `docker-compose.yml`, which is formed by constituent service files including `docker-compose.local.yml` (which defines the `drupal` service) and `docker-compose.saml.yml` (which defines the `idp` service).  The first indirection decouples the _location_ of the secret from the _name_ of the secret: the secrets are exposed to the containers by their _name_, independent of their location in the repository.

Generally, a named secret defines a single value.  The exception is the secret named `saml_secrets`; it contains multiple secrets.  This is the second indirection, whereby a single named secret can securely expose multiple secret values.  (This is in order to leverage the `file` [backend][file-backend] of [confd][confd])  Values in `saml-secrets.yml` may themselves be environment variables, which must be processed before they are used.  This is the third indirection.

Finally, some values from `saml_secrets` may be written out to files.  This depends on the capabilities of the consumer: some read configuration values inline, others read them from files.

|Composer Secret Name|Composer Location|Confd Key|Container(s)|Used By|Referenced As|References|Notes|
|---|---|---|---|---|---|---|---|
|saml_secrets|/secrets/saml-secrets.yml|/saml-secrets/idp/signing-key|idp|Shibboleth IdP|file|`idp.properties`|Ends with: 'opm/rxS83hCrTsIX3Il3T8Fpb97kdF+unCiWEaxrPEurjW8lB506'|
|saml_secrets|/secrets/saml-secrets.yml|/saml-secrets/idp/signing-cert|idp,drupal|Shibboleth IdP, SimpleSAMLphp|file, inline|`idp.properties`, `idp-metadata.xml`, `shib13-idp-remote.php`|Ends with: 's00xrv14zLifcc8oj5DYzOhYRifRXgHX'|
|saml_secrets|/secrets/saml-secrets.yml|/saml-secrets/idp/encryption-key|idp|Shibboleth IdP|file|`idp.properties`|Ends with: 'qX7ZsBuOT72RwVEa8fpT6IZ6IpOOEPmUid/f2VM2aAcXgaF//vMjxA=='|
|saml_secrets|/secrets/saml-secrets.yml|/saml-secrets/idp/encryption-cert|idp,drupal|Shibboleth IdP, SimpleSAMLphp|file, inline|`idp.properties`, `idp-metadata.xml`, `shib13-idp-remote.php`|Ends with: 'p+tGUbGS2l873J5PrsbpeKEVR/IIoKo='|
|idp_sealer|/secrets/idp/sealer.jks|-|idp|Shibboleth IdP|file|`idp.properties`|-|
|idp_backchannel|/secrets/idp/idp-backchannel.p12|-|idp|Jetty|file|`backchannel.ini`|Runs on port 8443, may not be used|
|saml_secrets|/secrets/saml-secrets.yml|/saml-secrets/idp/backchannel-signing-cert|idp,drupal|Shibboleth IdP, SimpleSAMLphp|inline|`idp-metadata.xml`, `shib13-idp-remote.php`|PEM version of the PKCS 12 encoded `idp_backchannel`; ends with: 't6Lf23Kb8yD6ZR7dihMZAGHnYQ/hlhM='|
|idp_browser|/secrets/idp/idp-browser.p12|-|idp|Jetty|file|`ssl.ini`|Runs on port 4443; this is the cert presented to HTTPS clients for IdP requests|
|saml_secrets|/secrets/saml-secrets.yml|/saml-secrets/idp/browser-cert|-|-|-|-|PEM version of the PKCS 12 encoded `idp_browser`, seems unused; ends with '7vawjZs0YP5qGifhos34g2GKW81m6sjoxpstLMK7pNQRy/pR/kv/jiXEn8xHRE6s'|
|saml_secrets|/secrets/saml-secrets.yml|/saml-secrets/sp/admin-pw|drupal|SimpleSAMLphp|inline|`config.php`|Contains the administrative password for the SimpleSAMLphp interface|
|saml_secrets|/secrets/saml-secrets.yml|/saml-secrets/sp/signing-cert|idp,drupal|Shibboleth IdP, SimpleSAMLphp|inline|`sp-metadata.xml`, `authsources.php`|Ends with: 'lQQUhxyEXTBJx3luLlpIjoloFKIute9K7pE5qAENjg=='|
|saml_secrets|/secrets/saml-secrets.yml|/saml-secrets/sp/hashing-salt|drupal|SimpleSAMLphp|inline|`config.php`|Used by SimpleSAMLphp to create secure hashes|
|saml_secrets|/secrets/saml-secrets.yml|/saml-secrets/sp/signing-key|drupal|SimpleSAMLphp|file|`authsources.php`|Ends with: 'HPxmTTEX5graPtXeDM3hz5A='|

### SAML env and secrets processing

Two containers use SAML env vars and secrets: the `idp` container (the mock Shibboleth Identity Provider) and the `drupal` container (SimpleSAMLphp Service Provider).  Secrets are defined in their accompanying docker-compose files, `docker-compose.local.yml` and `docker-compose.saml.yml`.

There are a number of files which contribute to the SAML environment, distributed across the `idc-isle-dc` and `idc-isle-buildkit` repositories, and multiple methods used for processing.  The complexity is high for a couple of reasons:
  * multiple applications with different runtimes (java, nginx/php) consume the same SAML parameters (e.g. the cert used to sign SAML assertions is referenced by both the SP and IdP)
  * a single application will use the same parameter inline as well as consume it from a file (so if you want to change a value, and only want to change it in one place, some hoops need to be jumped through)

An example may help: you wish to know how/where the IdP signing key is used.  Using the table above, a starting point would be to search the `idc-isle-buildkit` repo for occurrences of `idp/signing-key` key.  The only hits will be `confd` configuration, where you see that it is written out to `/tmp/idp_signing`.  Perform a second search for `/tmp/idp_signing`, and you'll see it used in the `idp.properties` `confd` template (which in turn writes `idp.properties` to `/opt/shibboleth-idp/conf/idp.properties`).

A second, more complex example: you wish to know how/where the IdP signing cert is used.  Using the table, start by searching the `idc-isle-buildkit` repo for occurrences of `idp/signing-cert` key.  You'll see it referenced by a couple of `confd` templates which in turn will lead you to `idp.properties` (references the value in the file `/tmp/idp_signing.crt`) and `idp-metadata.xml` (the value is used inline).  You will also want to perform a similar search of the `idc-isle-dc` repository.  To cast a wide net, search for the string `signing-cert` (you'll get some hits from both the SP and IdP).  You'll note that the file `shib13-idp-remote.php` uses PHP to parse the value from the `saml_secrets` YAML structure (essentially inline use).  As things evolve, I do not expect the table below to be kept up-to-date, so it is worth understanding how to discover where and how various secrets are used.

Tips:
* Search in both repositories
* Cast a wide net: searching for `/saml-secrets/idp/signing-cert` is not going to find hits in PHP code that reference `[saml-secrets][idp][signing-cert]`
* If `confd` writes the value to a file, perform a subsequent search for references to the file.
* Having a general understanding of the SAML protocol helps:  for example, encryption or signing keys shouldn't be shared between two different containers, but public keys (i.e. those used for verifying signatures) would be.

#### IdP env and secrets processing

The IdP entrypoint uses `confd` to interpolate a number of configuration files that dictate SAML request processing.  Because `saml_secrets` can use environment variables as secret values, the configuration files are subsequently processed through `envsubst`.

Note that the IdP configuration files may refer to any named secrets that are exposed by Docker, not just the secrets present in `saml_secrets`.

Finally, processing logic occurs in the `idp` entrypoint which resides in the `idc-isle-buildkit` repository.  Secrets are defined in the `idc-isle-dc` repository.  The names of secrets are shared between the two repositories; if the name of a secret changes, it must be changed in both.

#### SP env and secrets processing

The Service Provider (SimpleSAMLphp) runs in the `drupal` container, installed as a vendored `composer` dependency.  A number of PHP configuration files have been modified to reference secrets and environment variables where it makes sense.  For example, in `config.php` `'assertion.allowed_clock_skew' => 180` has been changed to `'assertion.allowed_clock_skew' => intval(getenv('DRUPAL_SP_ASSERTIONALLOWEDCLOCKSKEW'))`.  Instead of inlining certificates, `shib-13-idp-remote.php` parses `saml_secrets`.  These modifications reside in a patch file managed in the `idc-isle-dc` repository.

The PHP interpreter executes under PHP-FPM, therefore environment variables must be explicitly passed from NGINX.  Confd is used to process SP-related environment variables (using the env backend) and expose them to PHP-FPM via the include file `drupal_sp_fastcgi_params`.  Confd is executed on container start, and is managed in the `idc-isle-buildkit` repository.

[simplesaml]: https://simplesamlphp.org/docs/1.18/
[simplesaml-webadmin]: https://islandora-idc.traefik.me/simplesaml/index.php
[simplesaml-usersync]: https://islandora-idc.traefik.me/admin/config/people/simplesamlphp_auth/sync
[confd]: http://www.confd.io/
[file-backend]: https://github.com/kelseyhightower/confd/blob/master/docs/quick-start-guide.md#file
[cert-primer]: https://wiki.shibboleth.net/confluence/display/CONCEPT/SAMLKeysAndCertificates
[sp-gen-md]: https://islandora-idc.traefik.me/simplesaml/module.php/saml/sp/metadata.php/default-sp?output=xhtml

=======
Note:  In order for the push to be successful, you need to be "logged in" to the container registry via

    docker login ghcr.io

See the [guide to the github container registry](https://docs.google.com/document/d/13RQR7sKIhkUFpljkypiY5AYmMgeaM1tSYJAyt0APxgk/edit) for more information.
