import { RequestLogger, Selector} from 'testcafe';
import { adminUser } from './roles';
import { t } from 'testcafe';
import { readFileSync, writeFileSync } from 'fs';
import { parse, unparse } from './papaparse.min';
import { join as joinPath } from 'path';
import os from 'os';
import { contentList, findNodeIdForTitle, getResponseData, doMigration } from "./util";

fixture`Export Test Migrations`
  .page`https://islandora-idc.traefik.me/migrate_source_ui`
  .beforeEach(async t => {
    await t
      .useRole(adminUser);
  });

const migrate_person_taxonomy = 'idc_ingest_taxonomy_persons';
const migrate_accessrights_taxonomy = 'idc_ingest_taxonomy_accessrights';
const migrate_copyrightanduse_taxonomy = 'idc_ingest_taxonomy_copyrightanduse';
const migrate_genre_taxonomy = 'idc_ingest_taxonomy_genre';
const migrate_geolocation_taxonomy = 'idc_ingest_taxonomy_geolocation';
const migrate_islandora_accessterms_taxonomy = 'idc_ingest_taxonomy_islandora_accessterms';
const migrate_language_taxonomy = 'idc_ingest_taxonomy_language';
const migrate_new_items = 'idc_ingest_new_items';
const migrate_new_collection = 'idc_ingest_new_collection';
const migrate_resource_types = 'idc_ingest_taxonomy_resourcetypes';
const migrate_subject_taxonomy = 'idc_ingest_taxonomy_subject';
const migrate_corporatebody_taxonomy = 'idc_ingest_taxonomy_corporatebody';

const selectMigration = Selector('#edit-migrations');
const migrationOptions = selectMigration.find('option');

test('Perform Repository Object Migration', async t => {
  // Migrate dependencies first

  // access rights
  await doMigration(t, migrate_accessrights_taxonomy, './migrations/set_01-access_rights.csv');

  // access terms
  await doMigration(t, migrate_islandora_accessterms_taxonomy, './migrations/set_01-accessterms.csv');

  // copyright and use
  await doMigration(t, migrate_copyrightanduse_taxonomy, './migrations/set_01-copyright_and_use.csv');

  // corporate body
  await doMigration(t, migrate_corporatebody_taxonomy, './migrations/set_01-corporate_body.csv');

  // genre
  await doMigration(t, migrate_genre_taxonomy, './migrations/set_01-genre.csv');

  // geo location
  await doMigration(t, migrate_geolocation_taxonomy, './migrations/set_01-geo_location.csv');

  // language
  await doMigration(t, migrate_language_taxonomy, './migrations/set_01-language.csv');

  // persons
  await doMigration(t, migrate_person_taxonomy, './migrations/set_01-person.csv');

  // resource types
  await doMigration(t, migrate_resource_types, './migrations/set_01-resource_types.csv');

  // subjects
  await doMigration(t, migrate_subject_taxonomy, './migrations/set_01-subject.csv');

  // collections
  await doMigration(t, migrate_new_collection, './migrations/set_01-collection.csv');

  // Migrate Islandora Repository Objects
  await doMigration(t, migrate_new_items, './migrations/set_01-islandora_object.csv');
});

// This test to see if a general citation (single) one works.
// This also tests the report log for iconv errors, because if we
// see them than there might be an issue with php and iconv
test('Get Citations for Item', async t => {
  const nid = await findNodeIdForTitle(t, 'Zoo Animal B');
  const citationUrl = 'https://islandora-idc.traefik.me/citation?nid='.concat(nid);
  const response = await getResponseData(citationUrl);
  await t.expect(response.statusCode).eql(200);

  const data = JSON.parse(response.rawData)[0];

  // the data in the response should look like this:
  const expected = {
    'nid': nid,
    'field_citable_url': 'https://islandora-idc.traefik.me/node/' + nid,
    'citation_apa': '<div class=\"csl-bib-body\">\n  <div class=\"csl-entry\">Weston, E. , 2 Preferred Name Suffix, &#38; Adams, A. E. , 1 Preferred Name Suffix. (2020). <i>Zoo Animal B</i>. Knoxville Zoo. https://islandora-idc.traefik.me/node/' + nid + '</div>\n</div>',
    'citation_chicago': '<div class=\"csl-bib-body\">\n  <div class=\"csl-entry\">Edward Weston 2 Preferred Name Suffix, and Ansel Easton Adams 1 Preferred Name Suffix. 2020. “Zoo Animal B”. 1. Knoxville Zoo. https://islandora-idc.traefik.me/node/' + nid + '.</div>\n</div>',
    'citation_mla': '<div class=\"csl-bib-body\">\n  <div class=\"csl-entry\">E. Weston 2 Preferred Name Suffix, and A. E. Adams 1 Preferred Name Suffix. <i>Zoo Animal B</i>. Knoxville Zoo, 1 Jan. 2020, https://islandora-idc.traefik.me/node/' + nid + '.</div>\n</div>'
  };

  await t.expect(data.nid).eql(expected.nid);
  await t.expect(data.field_citable_url).eql(expected.field_citable_url);
  await t.expect(data.citation_apa).eql(expected.citation_apa);
  await t.expect(data.citation_chicago).eql(expected.citation_chicago);
  await t.expect(data.citation_mla).eql(expected.citation_mla);

  // now ensure that there are no recent errors about iconv conversions in the log
  await t.navigateTo('https://islandora-idc.traefik.me/admin/reports/dblog');
  const item = Selector('div.view-content').find('a').withText('Notice: iconv(): Wrong charset');
  await t.expect(item.count).eql(0);
});

// make sure citations are not being cached by changing a repository item
// and getting the citation right away
test('Test Citations for Caching', async t => {
  await t.navigateTo(contentList);

  const item = Selector('div.view-content').find('a').withText('Zoo Animal B');
  await t.expect(item.count).eql(1);
  await t.click(item);

  // click on edit tab
  await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Edit'));
  await t
    .typeText('#edit-title-0-value', 'Zoo Animal B - New Title', { replace: true })
    .click('#edit-submit');

  //const nodeUrl = await getUrl();
  const nodeUrl = await t.eval(() => document.documentURI);
  const nid = nodeUrl.substring(nodeUrl.lastIndexOf('/') + 1);
  const citationUrl = 'https://islandora-idc.traefik.me/citation?nid='.concat(nid);
  const response = await getResponseData(citationUrl);
  await t.expect(response.statusCode).eql(200);

  const data = JSON.parse(response.rawData)[0];

  // the data in the response should look like this:
  const expected = {
    'nid': nid,
    'field_citable_url': 'https://islandora-idc.traefik.me/node/' + nid,
    'citation_apa': '<div class=\"csl-bib-body\">\n  <div class=\"csl-entry\">Weston, E. , 2 Preferred Name Suffix, &#38; Adams, A. E. , 1 Preferred Name Suffix. (2020). <i>Zoo Animal B - New Title</i>. Knoxville Zoo. https://islandora-idc.traefik.me/node/' + nid + '</div>\n</div>',
    'citation_chicago': '<div class=\"csl-bib-body\">\n  <div class=\"csl-entry\">Edward Weston 2 Preferred Name Suffix, and Ansel Easton Adams 1 Preferred Name Suffix. 2020. “Zoo Animal B - New Title”. 1. Knoxville Zoo. https://islandora-idc.traefik.me/node/' + nid + '.</div>\n</div>',
    'citation_mla': '<div class=\"csl-bib-body\">\n  <div class=\"csl-entry\">E. Weston 2 Preferred Name Suffix, and A. E. Adams 1 Preferred Name Suffix. <i>Zoo Animal B - New Title</i>. Knoxville Zoo, 1 Jan. 2020, https://islandora-idc.traefik.me/node/' + nid + '.</div>\n</div>'
  };

  await t.expect(data.nid).eql(expected.nid);
  await t.expect(data.field_citable_url).eql(expected.field_citable_url);
  await t.expect(data.citation_apa).eql(expected.citation_apa);
  await t.expect(data.citation_chicago).eql(expected.citation_chicago);
  await t.expect(data.citation_mla).eql(expected.citation_mla);
});

fixture`Export Tests`
 .beforeEach(async t => {
    await t
      .useRole(adminUser);
  });

test('Export Tests - Repository Item Page', async t => {
  const expectedDataStr = await readFileSync(joinPath(__dirname, 'expected/single_repo_item.json'), 'utf-8');
  const expectedData = JSON.parse(expectedDataStr);

  await t.navigateTo(contentList);

  // find the item
  const item = Selector('div.view-content').find('a').withText('Zoo Animal A');
  await t.expect(item.count).eql(1);
  await t.click(item);

  // click on Export Button
  const metadataExportButton = Selector('#item-container').find('a').withText('Export Item Metadata');
  await t.expect(metadataExportButton.count).eql(1);
  await t.click(metadataExportButton);

  // check the files, comparing data
  const fileLink = await Selector(".messages--status", { timeout: 10000}).find('a').withText('here');
  const downloadedFileContent = await getRemoteFileContents(t, fileLink);
  const itemRows = parse(downloadedFileContent, { header: true });

  // only expecting one
  await t.expect(itemRows.data.length).eql(1);
  const itemRow = itemRows.data[0];

  await checkRow(t, expectedData, itemRow);
});


test('Export Tests - Collection Object Page', async t => {
  const expectedDataStr = await readFileSync(joinPath(__dirname, 'expected/single_collection_item.json'), 'utf-8');
  const expectedData = JSON.parse(expectedDataStr);

  await t.navigateTo(contentList);

  // find the item
  const item = Selector('td.views-field-title').find('a').withText('Collection A (Animals)');
  await t.expect(item.count).eql(1);
  await t.click(item);

  // click on Export Button
  const metadataExportButton = Selector('#about-collection-button-group').find('a').withText('Export Collection Metadata');
  await t.expect(metadataExportButton.count).eql(1);
  await t.click(metadataExportButton);

  // check the files, comparing data
  const fileLink = await Selector(".messages--status", { timeout: 10000}).find('a').withText('here');

  const downloadedFileContent = await getRemoteFileContents(t, fileLink);
  const itemRows = parse(downloadedFileContent, { header: true });

  // only expecting one
  await t.expect(itemRows.data.length).eql(1);
  const itemRow = itemRows.data[0];

  await checkRow(t, expectedData, itemRow);
});

test('Export Tests - Search Results Repository Items', async t => {
  const expectedDataStr = await readFileSync(joinPath(__dirname, 'expected/search_items.json'), 'utf-8');
  const expectedData = JSON.parse(expectedDataStr);

  await t.navigateTo('https://islandora-idc.traefik.me/search?query=animal');

  // click on metadata export link for repository items
  const metadataExportButton = Selector('#idc-search').find('a').withText('Export Metadata – Items');
  await t.expect(metadataExportButton.count).eql(1);
  await t.click(metadataExportButton);

  // check the files, comparing data
  const fileLink = await Selector(".messages--status", { timeout: 10000}).find('a').withText('here');

  // download it
  const downloadedFileContent = await getRemoteFileContents(t, fileLink);
  const itemRows = parse(downloadedFileContent, { header: true });

  // expecting 4 values
  await t.expect(itemRows.data.length).eql(4, `Expect 4 rows in csv, but only received ${itemRows.data.length}`);

  for (const row of itemRows.data) {
      const expectedItemArray = expectedData.items[row.unique_id];
      //const expectedItemArray = Object.entries(expectedData.items[row.unique_id]);
      await checkRow(t, expectedItemArray, row);
  }
});

test('Export Tests - Search Results Collection Objects', async t => {
  const expectedDataStr = await readFileSync(joinPath(__dirname, 'expected/search_collections.json'), 'utf-8');
  const expectedData = JSON.parse(expectedDataStr);

  await t.navigateTo('https://islandora-idc.traefik.me/search?query=animal');

  // click on metadata export link for repository items
  const metadataExportButton = Selector('#idc-search').find('a').withText('Export Metadata – Collections');
  await t.expect(metadataExportButton.count).eql(1);
  await t.click(metadataExportButton);

  // check the files, comparing data
  const fileLink = await Selector(".messages--status", { timeout: 10000}).find('a').withText('here');

  const downloadedFileContent = await getRemoteFileContents(t, fileLink);
  const itemRows = parse(downloadedFileContent, { header: true });

  // expecting 4 values
  await t.expect(itemRows.data.length).eql(5, `Expect 5 rows in csv, but only received ${itemRows.data.length}`);

  for (const row of itemRows.data) {
      const expectedItemArray = expectedData.collections[row.unique_id];
      //const expectedItemArray = Object.entries(expectedData.items[row.unique_id]);
      await checkRow(t, expectedItemArray, row);
  }
});

test('Export Tests - Round trip a Repository Item', async t => {
  await t.navigateTo(contentList);

  // find the item
  let item = Selector('div.view-content').find('a').withText('Zoo Animal A');
  await t.expect(item.count).eql(1);
  await t.click(item);

  // click on Export Button
  let metadataExportButton = Selector('#item-container').find('a').withText('Export Item Metadata');
  await t.expect(metadataExportButton.count).eql(1);
  await t.click(metadataExportButton);

  // check the files, comparing data
  let fileLink = await Selector(".messages--status", { timeout: 10000}).find('a').withText('here');

  // download the csv file
  let downloadedFileContent = await getRemoteFileContents(t, fileLink);
  const itemRows = parse(downloadedFileContent, { header: true });

  itemRows.data[0].title = "Zoo Animal ABC";
  itemRows.data[0].date_available = "2021-10-10";

  // note the nid so that we can verify that the migration does
  // an update and does not create a new node
  const origNodeId = itemRows.data[0].node_id;

  // reformat to CVS and save a new file for migration to use
  const changedCSV = unparse(itemRows.data);
  try {
    //const data = await writeFileSync(joinPath(__dirname, 'migrations/single_item_migration.csv'), changedCSV);
    const data = await writeFileSync('/tmp/single_item_migration.csv', changedCSV);
    //file written successfully
  } catch (err) {
    console.error(err)
  }

  // run the new migration (update, really, since we are changing an object)
  //await doMigration(t, migrate_new_items, joinPath(__dirname,'migrations/single_item_migration.csv'));
  await doMigration(t, migrate_new_items, '/tmp/single_item_migration.csv');

  // find the item, again, to ensure it's changed
  await t.navigateTo(contentList);
  item = Selector('div.view-content').find('a').withText('Zoo Animal ABC');
  await t.expect(item.count).eql(1);
  // check the nid so we know we are examining the same node as before.
  const href = await item.getAttribute("href");
  await t.expect(origNodeId).eql(href.substring(href.lastIndexOf('/') + 1),
      "The node id on the object does not match the original node id");
  await t.click(item);

  // click on Export Button
  metadataExportButton = Selector('#item-container').find('a').withText('Export Item Metadata');
  await t.expect(metadataExportButton.count).eql(1);
  await t.click(metadataExportButton);
  // check the files, comparing data
  fileLink = await Selector(".messages--status", { timeout: 10000}).find('a').withText('here');

  // Export it and check again
  downloadedFileContent = await getRemoteFileContents(t, fileLink);
  const changedItemRows = parse(downloadedFileContent, { header: true });
  const expectedDataStr = await readFileSync(joinPath(__dirname, 'expected/single_repo_item_changed.json'), 'utf-8');
  const expectedData = JSON.parse(expectedDataStr);

  // only expecting one
  await t.expect(changedItemRows.data.length).eql(1);
  const cItemRow = changedItemRows.data[0];

  await checkRow(t, expectedData, cItemRow);
});


/**
 * Compares the two objects passed in, field by field.  The comparison will be
 * drive by the fields in the first object (expectedObj).
 *
 * @param {TestCafe} t
 * @param {Object} expectedObj Object that is the foundObj is expected to look like
 * @param {Object} foundObj Object being compared to expected object
 */
async function checkRow(t, expectedObj, foundObj) {

  for (const [field, fieldVal] of Object.entries(expectedObj)) {
    let exportVal = foundObj[field];
    const expectedVal = fieldVal;

    // we are expecting a value in this field, so the exported field can't be empty
    await t.expect(exportVal != undefined).ok(`Value for ${field} in exported data row ${expectedObj.unique_id} not set`);

    const splitVal = exportVal.split('||');
    if (splitVal.length > 1) {
      exportVal = splitVal;
    }

    if (Array.isArray(expectedVal)) {
      await t.expect(Array.isArray(exportVal)).ok(`Expected value for field ${field} in exported data row to be an array and it was not: ${exportVal}`);
      for (const x of exportVal) {
        await t.expect(expectedVal.includes(x)).ok(`Exported value for field ${field}'s value of ${x} was not found in expected data array`);
      }
    } else {
      await t.expect(exportVal).eql(expectedVal, `Values for ${field} did not match. Expected ${expectedVal}, Exported: ${exportVal}`);
    }
  }
}

/**
 * Fetches the content of a remote file
 *
 * @param {Testcafe} t
 * @param {A href link} fileLink
 * @returns String of remote file content
 */
async function getRemoteFileContents(t, fileLink) {

  let fileContents = "";
  const href = await fileLink.getAttribute("href");
  const fileName = href.substring(href.lastIndexOf('/') + 1);
  await t.expect(fileLink.count).eql(1);

  const logger = RequestLogger({ href, method: 'GET' }, {
    logResponseHeaders:    true,
    logResponseBody:       true,
    stringifyResponseBody: true
  });

  await t.addRequestHooks(logger);
  await t.click(fileLink)
    .expect(logger.contains(r => {
      if (r.response.statusCode !== 200)
          return false;

      const requestInfo = logger.requests[0];

      if (!requestInfo)
          return false;

      fileContents = logger.requests[0].response.body;
      return true;
    })).ok();

    return fileContents;
}
