# IDC Migration Tests

## Known Issues

### Migrations Admin Menu

The Migrations admin menu can't be used to manage migrations effectively.  This is because the Migrate Source UI plugin dynamically supplies a file source to the migration.

> When a user uploads a CSV file to be migrated, it is stored as a Drupal temporary file, and the migration is dynamically updated to point to the temporary file.

The Migrations admin menu/module errors out when it encounters a migration that does not have a value for the file source (which is all of the migrations supported by these tests).

This does not affect management of migrations, since they are a part of the external configuration.  Unless the Migrations admin menu provides required features, it can probably be disabled for mortal use.

### Multi-value field separators

The vertical pipe `|` is used to separate multiple values, e.g. if an item has multiple alternate names, they will be represented as `Alternate Name One|Alternate Name Two`.  The semi-colon `;` is used to separate components of a value.  If a string field has an associated language (e.g. a field type of `language_value_pair`), it would be represented as `This is the string field;eng`.

The problem is that `|` and `;` become _reserved_ characters and cannot be used in the value itself.  This is especially problematic for the semi-colon, since it could be reasonably used as punctuation in a description or abstract field, or within a URL.

The immediate workaround is to use a different character other than `;` for separating components of a value, such as `^` or `@` that are less likely to appear in a text field.  Longer term there may need to be some mechanism of escaping these reserved characters when they are used in a value.

### Problematic Fields

These are fields for which there is no or incomplete migration support. Resolving these known issues may involve custom Drupal code (e.g. modifying or writing novel migration plugins), restricting the use of local identifiers in favor of URIs for field values, and/or exploring additional parameters to the `migration_lookup` plugin (e.g. supplying multiple migrations to the `migration` configuration key).

|Entity|Bundle|Field (type)|Description|
|---|---|---|---|
|taxonomy_term|geo_location|`field_broader` (`link`)|Values for this field may contain arbitrary URLs to an external resource or internal links to a Drupal resource with the form, e.g. `entity:node/16`.  The current migration for `geo_location` cannot use local ids _and_ arbitrary URLs.|
|taxonomy_term|corporate_body|`field_relationships` (`typed_relation`)|Values for this field may reference multiple taxonomies (i.e. different bundles).  It is problematic to use local ids to reference multiple bundles.|
|taxonomy_term|person|`field_relationships` (`typed_relation`)|Values for this field may reference multiple taxonomies (i.e. different bundles).  It is problematic to use local ids to reference multiple bundles.|
|taxonomy_term|family|`field_relationships` (`typed_relation`)|Values for this field may reference multiple taxonomies (i.e. different bundles).  It is problematic to use local ids to reference multiple bundles.|
|node|islandora_object|`field_creator` (`typed_relation`)|Values for this field may reference multiple taxonomies (i.e. different bundles).  It is problematic to use local ids to reference multiple bundles.|
|node|islandora_object|`field_contributor` (`typed_relation`)|Values for this field may reference multiple taxonomies (i.e. different bundles).  It is problematic to use local ids to reference multiple bundles.|
|node|islandora_object|`field_copyright_holder` (`entity_reference`)|Values for this field may reference multiple taxonomies (i.e. different bundles).  It is problematic to use local ids to reference multiple bundles.|
|node|islandora_object|`field_digital_publisher` (`entity_reference`)|Values for this field may reference multiple taxonomies (i.e. different bundles).  It is problematic to use local ids to reference multiple bundles.|
|node|islandora_object|`field_publisher` (`entity_reference`)|Values for this field may reference multiple taxonomies (i.e. different bundles).  It is problematic to use local ids to reference multiple bundles.|
|node|islandora_object|`field_member_of` (`entity_reference`)|Values for this field may reference different bundles.  It is problematic to use local ids to reference multiple bundles.|
|node|islandora_object|`field_publisher` (`entity_reference`)|Values for this field may reference different bundles.  It is problematic to use local ids to reference multiple bundles.|
|node|islandora_object|`field_subject` (`entity_reference`)|Values for this field may reference different bundles.  It is problematic to use local ids to reference multiple bundles.|

## Invoking the tests

Migration tests may be invoked in isolation by running the `10-migration-backend-tests.sh` script.
> The script should _not_ be invoked from any sub-directories of the `10-migration-backend-tests` directory

The migration tests do participate in the general IDC test framework, and should run automatically when `make test` is invoked.

## How the tests work - an overview

The `10-migration-backend-tests.sh` script is the "controller" of the tests.  It is responsible for executing the various test frameworks and controls the shell exit code.  Each test framework executes in a Docker container, so there are no dependencies or configuration required to perform the tests, except for a working Docker.

The controller script invokes testcafe first, which will perform migrations that result in resources being created in Drupal.  Next, the controller will invoke Go tests which verify the resources were created correctly (e.g. that the data in the migration CSV files are present in the Drupal resources).

Because one test framework creates resources and another test framework verifies the resources, there is unfortunate coupling that may not be readily apparent.  If the CSV files in testcafe are modified, the verification code must almost certainly be updated to account for the changes in the Drupal resources.

### Testcafe performs the migration

The testcafe framework is used to perform a series of migrations.  The _data_ to be migrated resides under the `testcafe` directory in CSV files. The migration _definitions_ are defined in the Drupal active configuration; that is, they're baked in to Drupal already.

The migrations occur just as if someone from the JHU digital collections team were performing a migration.  They must be performed in order so that child resources can reliably refer to their parents.

The Testcafe tests few things
* the presence of the baked in migrations
* the presence of the Migrate Source UI module
* the authorization of an admin user to perform a migration

### Go tests verify the migration

The Go tests are used to verify that the migration performed by testcafe resulted in the creation of the expected Drupal resource.  The Go tests are used to verify the migration definitions baked into Drupal's configuration.

Go verification directly tests things like:
* Did a given piece of data in the migration CSV file get properly translated to a Drupal field
* Were the relationships present in the migration CSV data properly translated to links between Drupal resources

The Go verification tests rely on the Drupal JSONAPI module to retrieve migrated resources, and compare the JSONAPI response with a bespoke JSON format representing the expected response.

## Testing details (i.e. gotchas)

### Coupling of test data

As mentioned above, if the migration CSV is updated to add a new field, merge an existing field, or remove a field, or if values change, it is likely that the verification code will need to be updated to accommodate this change.

The CSV test data is present in the `testcafe/migrations` directory, and the Go verification JSON is present in the `verification/expected` directory.  Depending on the nature of the changes to the CSV data, only minor modifications to the verification JSON may be necessary.

However, if the CSV is modified in any non-trivial way (like adding a row, changing a field name or adding a field), the Go verification code itself will need to be updated, along with updated the verification JSON.

### Use of URIs in test data

Drupal does not make it easy to determine the URI of a migrated resource.  Even if the URI of a migrated resource could be determined by the testcafe code, it would be difficult - or at least unorthodox and ungainly - to share the URI of that resource with the verification code.

> To do that properly, a service of some kind would need to be developed which consults the Drupal database, and that's too time-consuming for the moment

Therefore, verification code can't retrieve resources using their URI; instead, it queries for a resource using unique values.  For example, it will retrieve a Person taxonomy term by filtering on the first and last name, or retrieve a node by filtering on its title.

An additional consequence of this is that the migration CSV files _cannot_ refer to resources by their URI.  In a _production_ environment, a migration definition could leverage URIs.  For example, to establish that one Person `schema:knows` another Person, the target of the `schema:knows` relationship could be a URI.  This is made possible by the migration definition expecting and operating on URIs, and by the author of the CSV; the author of the CSV logs into IDC, finds the URI of the target Person, and copies it into the CSV.

However, because URIs are not known in advance in the _test_ environment, relationships like the one illustrated here cannot be established using URIs.  They must be established using some other property, and in this case the migration definitions use _local identifiers_ established by the author of the CSV to create these relationships.

The consequence is that the production environment cannot use URIs to create relationships _and_ have a reliable test for the migration.

### Use of JSONAPI filters

JSONAPI filters are used by the Go verification code to find a single resource based on unique characteristics of the resource.  For example, to filter for a single Person using the JSONAPI, a filter like `filter[name]=Ansel Adams` would be used.  To filter for a Node with a given UUID, a filter like `filter[id]=adb236e4-23d0-4f91-b986-860cad20ed9d`.

The "gotcha" here is that the author of test CSV must bear this in mind when creating test data for migration.  As long as the author uses reasonable values (for example, the string "Moo" is not used as a name for two different Persons, and nodes receive unique titles), this should not be a problem.

As far as I know, there is no easy way to use the JSONAPI to filter for a resource given its URI.
