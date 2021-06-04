# IDC Export Tests

WIP

## Known Issues

### Export includes more information than ingest might

There are a few fields that might include more data in the quad when exported than was there during import.  Export needs to be specific with a few
fields, so the bundle data might be there, whereas it wasn't there on ingest. 

The formatting for any field that has more than one bundle type looks like this: 

`<entity_type>:<bundle>:<value_key>:<value>`

For example, if during ingest the data in a column looked like this: 

`:::Collection A`

There are some defaults applied upon default for the parts of the quad, so the above will work.

Export will include more data to be specific about bundle.  It will look like this: 

`:collection_object::Collection A`

The data is sematically the same, just more detailed upon export to ensure that ingest will do the right thing and no assumptions are made. 

#### Field Formatters for quads

To render the content correctly for export, a few FieldFormatters were created. 

In the Export Metadata view is where these formatters are set, on a per-field basis. 

Only fields that use the `parse_entity_lookup` on ingest will have their fields exported with these formatters.  

##### NodeEntityReferenceCSVFormatter

The NodeEntityReferenceFormatter assumes that the `entity_type` is `node`, so it doesn't include it.  It also assumes that `value_key` is `title` and also doesn't include it. But since it doesn't know if the field accepts more than one bundle type, it includes the `<bundle>` in the quad. That logic could be added later.  They end up looking like this: 

`:collection_object::Collection A`

##### TaxonomyTermEntityReferenceCSVFormatter

The TaxonomyTermEntityReferenceFormatter assumes that the `entity_type` is `taxonomy_term` and that `value_key` is `name`, so it doesn't include either of those.  It does include `bundle` and `value`. They end up looking like this:

`:subject::Farm`

##### LanguageValuePairCSVFormatter

This formatter will format a Language Value Pair like so:

`The string of content;eng`

Where the language code of the taxonomy term associated with the string is displayed. 

##### TypedRelationCSVFormatter

This formatter will format a Typed Relation field like so: 

`relators:art;:person::Adams, Ansel Easton, 1902-1984`

Notice that it includes the quad formatting for the taxonomy term entity reference. 

## Invoking the tests

To invoke the tests, run `make test test=20-export-tests.sh` from the main `idc-isle-dc` directory.

The migration tests do participate in the general IDC test framework, and should run automatically when `make test` is invoked.
