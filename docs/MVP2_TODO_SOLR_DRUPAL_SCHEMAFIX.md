Installing Search API Solr Search
=================================

The search_api_solr module manages its dependencies and class loader via
composer. So if you simply downloaded this module from drupal.org you have to
delete it and install it again via composer!

Simply change into Drupal directory and use composer to install search_api_solr:

```
cd $DRUPAL
composer require drupal/search_api_solr
```

**Warning!** Unless https://www.drupal.org/project/drupal/issues/2876675 is
committed to Drupal Core and released you need to modify the composer command:

```
cd $DRUPAL
composer require symfony/event-dispatcher:"4.3.4 as 3.4.99" drupal/search_api_solr
```

Setting up Solr (single core)
-----------------------------

In order for this module to work, you need to set up a Solr server.
For this, you can either purchase a server from a web Solr hosts or set up your
own Solr server on your web server (if you have the necessary rights to do so).
If you want to use a hosted solution, a number of companies are listed on the
module's [project page](https://drupal.org/project/search_api_solr). Otherwise,
please follow the instructions in this section.

Note: A more detailed set of instructions is available at:
* https://lucene.apache.org/solr/guide/8_4/installing-solr.html
* https://lucene.apache.org/solr/guide/8_4/taking-solr-to-production.html
* https://lucene.apache.org/solr/guide/ - list of other version specific guides

As a pre-requisite for running your own Solr server, you'll need a Java JRE.

Download the latest version of Solr 8.x from
https://lucene.apache.org/solr/downloads.html and unpack the archive
somewhere outside of your web server's document tree. The unpacked Solr
directory is named `$SOLR` in these instructions.

Note: Solr 6.x is still supported by search_api_solr but strongly discouraged.
That version has been declared end-of-life by the Apache Solr project and is
thus no longer supported by them.

Before creating the Solr core (`$CORE`) you will have to make sure it uses the
proper configuration files. They aren't always static but vary on your Drupal
setup.
But the Search API Solr Search module will create the correct configs for you!

1. Create a Search API Server according to the search_api documentation using
   "Solr" as Backend and the connector that meets your setup.
2. Download the config.zip from the server's details page or by using
   `drush solr-gsc` with proper options, for example for a server named
   "my_solr_server": `drush solr-gsc my_solr_server config.zip 8.4`.
3. Copy config.zip to the Solr server and extract. The unpacked configuration
   directory is named `$CONF` in these instructions.

Now you can create a Solr core using this config-set on a running Solr server.
There're different ways to do so. For most Linux distributions you can run
```
sudo -u solr $SOLR/bin/solr create_core -c $CORE -d $CONF
```

You will see something like
```
$ sudo -u solr /opt/solr/bin/solr create_core -c test-core -d /tmp/solr-conf

Copying configuration to new core instance directory:
/var/solr/data/test-core
```

Note: Every time you add a new language to your Drupal instance or add a custom
Solr Field Type you have to update your core configuration files. Using the
example above they will be located in /var/solr/data/test-core/conf. The Drupal
admin UI should inform you about the requirement to update the  configuration.
Reload the core after updating the config using
`curl -k http://localhost:8983/solr/admin/cores?action=RELOAD&core=$CORE` on
the command line or enable the search_api_admin sub-module to do it from the
Drupal admin UI.

Note: There's file called `solrcore.properties` within the set of generated
config files. If you need to fine tune some setting you should do it within this
file if possible instead of modifying `solrconf.xml`.

Afterwards, go to `http://localhost:8983/solr/#/$CORE` in your web browser to
ensure Solr is running correctly.

CAUTION! For production sites, it is vital that you somehow prevent outside
access to the Solr server. Otherwise, attackers could read, corrupt or delete
all your indexed data. Using the server as described below WON'T prevent this by
default! If it is available, the probably easiest way of preventing this is to
disable outside access to the ports used by Solr through your server's network
configuration or through the use of a firewall.
Other options include adding basic HTTP authentication or renaming the solr/
directory to a random string of characters and using that as the path.

For configuring indexes and searches you have to follow the documentation of
search_api.


Setting up Solr Cloud
---------------------

Instead of a single core you have to create a collection in your Solr Cloud
instance. To do so you have to read the Solr handbook.

1. Create a Search API Server according to the search_api documentation using
   "Solr" or "Multilingual Solr" as Backend and the "Solr Cloud" or
   "Solr Cloud with Basic Auth" Connector.
2. Download the config.zip from the server's details page or by using
   `drush solr-gsc
3. Deploy the config.zip via zookeeper.


Using Linux specific Solr Packages
----------------------------------

Note: The paths where the config.zip needs to be extracted to might differ from
the instructions above as well. For some distributions a directory like
`/var/solr` or `/usr/local/solr` exists.
