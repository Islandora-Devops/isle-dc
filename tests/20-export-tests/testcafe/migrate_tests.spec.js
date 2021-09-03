import {Selector} from 'testcafe';
import {adminUser} from './roles.js';
import { t } from 'testcafe';
import fs from 'fs';
import { join as joinPath } from 'path';
import os from 'os';
import {contentList, findNodeIdForTitle, getResponseData, doMigration} from "./util";


//const fs   = require('fs');
//const path = require('path');

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
    'citation_chicago': '<div class=\"csl-bib-body\">\n  <div class=\"csl-entry\">Edward Weston 2 Preferred Name Suffix, and Ansel Easton Adams 1 Preferred Name Suffix. 2020. <i>Zoo Animal B</i>. 1. Knoxville Zoo. https://islandora-idc.traefik.me/node/' + nid + '.</div>\n</div>',
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
    'citation_chicago': '<div class=\"csl-bib-body\">\n  <div class=\"csl-entry\">Edward Weston 2 Preferred Name Suffix, and Ansel Easton Adams 1 Preferred Name Suffix. 2020. <i>Zoo Animal B - New Title</i>. 1. Knoxville Zoo. https://islandora-idc.traefik.me/node/' + nid + '.</div>\n</div>',
    'citation_mla': '<div class=\"csl-bib-body\">\n  <div class=\"csl-entry\">E. Weston 2 Preferred Name Suffix, and A. E. Adams 1 Preferred Name Suffix. <i>Zoo Animal B - New Title</i>. Knoxville Zoo, 1 Jan. 2020, https://islandora-idc.traefik.me/node/' + nid + '.</div>\n</div>'
  };

  await t.expect(data.nid).eql(expected.nid);
  await t.expect(data.field_citable_url).eql(expected.field_citable_url);
  await t.expect(data.citation_apa).eql(expected.citation_apa);
  await t.expect(data.citation_chicago).eql(expected.citation_chicago);
  await t.expect(data.citation_mla).eql(expected.citation_mla);
});


// SKIP FOR NOW - not working.
fixture.skip `Export Tests`

/*
  Element we want to grab:

  <a download="" href="http://islandora-idc.traefik.me/system/files/views_data_export/export_metadata_data_export_1/1-1621620562/idc-data-export-repo-items.csv" data-download-enabled="true" id="vde-automatic-download">here</a>

 */
const fileDownloadSelector = Selector('#vde-automatic-download');

// TODO -- is this location for the tmp file even remotely accurate?
const DOWNLOAD_DIR = joinPath(process.env.HOME || process.env.USERPROFILE, 'downloads/');

test
    .page`https://islandora-idc.traefik.me/export_items?query=zoo`
    ('Export Tests - Repository Item', async () => {

        //console.log("waiting for 60s");
        //await t.wait(60000);
        //console.log("done waiting");
        // Run this test only with the Google Chrome browser to simplify the searching of the downloaded file.
        if (t.browser.name !== 'Chrome')
            return;

        var filename = fileDownloadSelector.getAttribute('href');
        console.log("filename is " + filename);
        filename.textContent().replace(/^.*\//g,"");

        const file_path = joinPath(DOWNLOAD_DIR, filename);
        await t.expect(fs.existsSync(file_path)).ok();

        await t.click(fileDownloadSelector);

        await waitForFileDownload(downloadedFilePath);

        console.log("in theory we have the file");
/*
        var rawFile = new XMLHttpRequest();
        var allText = null;
        rawFile.open("GET",filename,false);
        rawFile.onreadystatechange = function() {
            if(rawFile.readyState === 4) {
                if(rawFile.status === 200 || rawFile.status === 0)
                {
                    allText = rawFile.responseText;
                    console.log(allText);
                }
            }
        }
        rawFile.send(null);
        // now we have the file, read it in and test it out.
 */
    });

async function readCsvFile(file) {
  var text = null;
  var csvFile = fs.readFileSync(file, { encoding: "utf8" });
  var theData = parser.parse(csvFile, { header: true });

  // returns json formatted data
  return theData;
}


//
// Old attempts below - kept in (for now) in case it's helpful to someone
//
/*
import http from 'http';

const runExport = (url) => new Promise((resolve, reject) => {
    console.log("running export: " + url);
    http.get(url, res => {
        const { statusCode } = res;
        const contentType = res.headers['content-type'];

        res.setEncoding('utf8');
        let rawData = '';
        res.on('data', (chunk) => { rawData += chunk; });
        res.on('end', () => resolve({ statusCode, contentType, rawData }));
    }).on('error', e => reject(e));
});

test('Export Tests - Repository Item Export', async t => {
    const response = await runExport('https://islandora-idc.traefik.me/export_items?query=zoo')
    await t
        .expect(response.statusCode).eql(200);

        var filename = fileDownloadSelector.getAttribute('href');
        console.log("filename is " + filename);
        filename.textContent().replace(/^.*\//g,"");

        const file_path = joinPath(DOWNLOAD_DIR, filename);
        await t.expect(fs.existsSync(file_path)).ok();

        await t.click(fileDownloadSelector);

        await waitForFileDownload(downloadedFilePath);

        console.log("in theory we have the file");
}); */


/*
 *
 *
 *  document.querySelector("#myLink").addEventListener("click", function(event){
        event.preventDefault();
        var file = document.getElementById("myLink").getAttribute("href");
        console.log(file)
        var rawFile = new XMLHttpRequest();
        rawFile.open("GET",file,false);
          rawFile.onreadystatechange = function() {
              if(rawFile.readyState === 4) {
                  if(rawFile.status === 200 || rawFile.status === 0)
                  {
                      var allText = rawFile.responseText;
                      console.log(allText);
                  }
              }
          }
          rawFile.send(null);
    .before(async () => {
        downloadedFilePath = joinPath(os.homedir(), 'Downloads', 'exported-data-items.csv');

        if (fs.existsSync(downloadedFilePath))
            fs.unlinkSync(downloadedFilePath);
*/
/*
async function waitForFileDownload (path) {
    for (let i = 0; i < 10; i++) {
        if (fs.existsSync(path))
            return true;

        await t.wait(500);
    }

    return fs.existsSync(path);
}
*/
/*
import { RequestLogger } from 'testcafe';

const url = 'http://localhost:3000/download-file';

const logger = RequestLogger({ url, method: 'GET' }, {
    logResponseHeaders:    true,
    logResponseBody:       true,
    stringifyResponseBody: true
});
fixture `Download file`
    .page('./index.html')
    .requestHooks(logger);

test('Check file name and content', async t => {

    const fileNameRegEx = /attachment; filename=.*.txt/;

    const downloadSelector = Selector('#vde-automatic-download')
    await t
        .click(downloadSelector)
        .expect(logger.contains(r => {
            if (r.response.statusCode !== 200)
                return false;

            const requestInfo = logger.requests[0];

            if (!requestInfo)
                return false;

            const downloadedFileName = requestInfo.response.headers['content-disposition'];

            if (!downloadedFileName)
                false;

            if (!fileNameRegEx.test(downloadedFileName))
                return false;

            const downloadedFileContent = logger.requests[0].response.body;

            return downloadedFileContent === 'Test content';
        })).ok();
});
*/



