# Troubleshooting

This document lists common ISLE problems and their solutions. It is currently a stub and should be added to.

## Logging

To view the Drupal logs from the shell, from your `isle-dc` directory, enter `docker-compose logs -f drupal`. That last argument is the service name, which can be swapped out or can actually be multiple (e.g. `drupal solr fcrepo`) or it can be empty, in which case you will see ALL logs.

## "Your clock is ahead/behind" certificate error

Issue: Your browser will not let you access your site because it claims your computer's clock is incorrect,
even when your clock is correct.

Solution: In your isle directory, run the following commands:

```
curl http://traefik.me/fullchain.pem -o certs/cert.pem
curl http://traefik.me/privkey.pem -o certs/privkey.pem
```

Then restart the containers.

## Errors doing `drush config:import -y`:

**Error:**

```html
Site UUID in source storage does not match the target Storage.
```

This occurs when your configuration has come from a site other than the one that
is currently installed. You can run the following command to override the site
`uuid` so that you can import your configuration:

```bash
make set-site-uuid
```

**Error:**

```html
Entities exist of type <em class="placeholder">Shortcut link</em> and <em class="placeholder">Shortcut set</em>
<em class="placeholder">Default</em>. These entities need to be deleted before importing
```

These are entities created by the `standard` installation profile, you can delete
them with the following command in the codebase folder:

```bash
make delete-shortcut-entities
```

**Error:**

```bash
Error: Call to a member function getConfigDependencyName() on null in ... Entity/EntityDisplayBase.php on line 325 #0 ... /codebase/web/core/lib/Drupal/Core/Config/Entity/ConfigEntityBase.php(318): Drupal\Core\Entity\EntityDisplayBase->calculateDependencies()
```

There is some bug in the dependencies of the various modules. Until those
dependencies issues are resolved just rerun the command until they go away.

```bash
drush config:import -y
```

## Errors when doing an `drush sql:dump`:

**Error:**

This arises from our use of [MariaDB] for the database in Docker, not matching
the same client on your host system. Which probably uses the [MySQL] clients
`mysqldump` executable. You can specify the following command using drush to get
around it:

```bash
drush sql:dump --extra-dump="--column-statistics=0" > /tmp/dump.sql
```

Or you can use the provided method in the [Makefile](./Makefile) which should be
more portable.

```bash
make database-dump DEST=/tmp/dump.sql
```

## Drupal can't connect to a valid Solr container:

**Error:**

The server configured at `/admin/config/search/search-api` shows a failed connection to a properly configured Solr container.

This can sometimes be caused by Docker containers not inheriting the DNS configurations from the host machine.

To fix edit `/etc/resolv.conf` in both the Drupal and the Solr containers by adding a valid DNS entry ie `nameserver 223.5.5.5`


## Image or other derivatives are not produced, due to insufficient timeout limits

**Symptoms:**

Houdini converts images which is needed to produce image derivatives.  Output from `docker-compose logs -f houdini` 
such as this which is repeats (even when no further media have been uploaded) is an indication that the timeout 
is exceeded, and alpaca is re-attempting:

```
houdini_1     | [2022-01-05 21:41:03] app.INFO: Convert request. [] []
houdini_1     | [2022-01-05 21:41:03] app.DEBUG: X-Islandora-Args: {"args":"-thumbnail 100x100"} []
houdini_1     | [2022-01-05 21:41:03] app.DEBUG: Content Types: [] []
houdini_1     | [2022-01-05 21:41:03] app.DEBUG: Content Type Chosen: {"type":"image/jpeg"} []
houdini_1     | [2022-01-05 21:41:03] app.INFO: Imagemagick Command: {"cmd":"convert - -thumbnail 100x100 jpeg:-"} []
...
```

Output from `docker-compose logs -f alpaca` like this, which shows that it has hit a timeout and is giving up:

```
alpaca_1      | 2022-01-05 21:42:52,863 | ERROR | nnector-houdini] | DefaultErrorHandler              
| 56 - org.apache.camel.camel-core - 2.20.4 | Failed delivery for (MessageId: 
queue_islandora-connector-houdini_ID_94ca62ced546-38129-1641418608853-3_6_-1_1_5 on ExchangeId: 
ID-bea81bcc2a4e-1641418615223-3-11). Exhausted after delivery attempt: 11 caught: 
java.net.SocketTimeoutException: Read timed out. Processed by failure processor: 
FatalFallbackErrorHandler[Channel[Log(ca.islandora.alpaca.connector.derivative.DerivativeConnector)
[Error connecting generating derivative with http://houdini:8000/convert: ${exception.message}
```

To fix this:

 * edit your .env file, an increase ALPACA_HOUDINI_TIMEOUT (and other similar timeouts if necessary).  Note these values are in milliseconds.
 * make docker-compose.yml  (this is necessary to pick up the change and re-write docker-compose.yml)
 * restart containers
