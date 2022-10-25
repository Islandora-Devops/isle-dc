import https from 'https';
import {Selector} from 'testcafe';
import {adminUser} from './roles.js';


fixture`File Deletion Tests`
  .page`https://islandora-idc.traefik.me/migrate_source_ui`
  .beforeEach(async t => {
    await t
      .useRole(adminUser);
  });

const migrate_new_items = 'idc_ingest_new_items';
const migrate_new_collection = 'idc_ingest_new_collection';
const migrate_media_file = 'idc_ingest_media_file';

const selectMigration = Selector('#edit-migrations');
const migrationOptions = selectMigration.find('option');


test('Migrate Files to be Deleted', async t => {
    // Migrate the Collection and Repository Object the Media will be attached to

    await t
        .click(selectMigration)
        .click(migrationOptions.withAttribute('value', migrate_new_collection));

    await t
        .setFilesToUpload('#edit-source-file', [
            './migrations/filedeletion-collection.csv'
        ])
        .click('#edit-import');

    await t
        .click(selectMigration)
        .click(migrationOptions.withAttribute('value', migrate_new_items));

    await t
        .setFilesToUpload('#edit-source-file', [
            './migrations/filedeletion-islandora_object.csv'
        ])
        .click('#edit-import');

    await t
        .click(selectMigration)
        .click(migrationOptions.withAttribute('value', migrate_media_file));

    // Migrate the File to be deleted

    await t
        .setFilesToUpload('#edit-source-file', [
            './migrations/filedeletion-file.csv'
        ])
        .click('#edit-import');

    let fileListing = 'https://islandora-idc.traefik.me/admin/content/files/';
    let mediaListing = 'https://islandora-idc.traefik.me/admin/content/media';

    // Navigate to Files listing, verify File is present, and used in one place
    await t.navigateTo(fileListing);
    const fileToDelete = Selector('div.view-content').find('a').withText('NEFF1851_GEO.tfw');
    // get url for later
    let url = await fileToDelete.getAttribute('href');
    await t.expect(fileToDelete.count).eql(1);
    const tr = fileToDelete.parent('tr');
    const referenceCell = tr.child('td').nth(-1);
    await t.expect(referenceCell.innerText).eql('1 place');

    // Navigate to Media listing, verify Media is present containing the File to be deleted
    await t.navigateTo(mediaListing);
    const mediaToDelete = Selector('div.view-content').find('a').withText('Test Geo Tif File');
    await t.expect(mediaToDelete.count).eql(1);

    // Delete the Media and the File
    await t.click(mediaToDelete.parent('tr').find('input'));
    await t.click(Selector('div.view-content').find('input').withAttribute('name', 'op'));
    await t.click(Selector('input').withAttribute('name', 'op').withAttribute('value', 'Delete'));

    // After deleting the media, there are two messages that show on the flash:
    // 'Deleted 3 items.' (A green informational message)
    await t.expect(Selector('div').withAttribute('aria-label', 'Status message').innerText)
        .contains('Deleted 3 items.')

    // Verify the Media is gone
    await t.expect(mediaToDelete.count).eql(0);

    // Navigate to the File listing and verify the File is gone, too.
    await t.navigateTo(fileListing);
    await t.expect(fileToDelete.count).eql(0);

    // check that the file is no longer in minio (based on url captured from earlier)
    var statusCode = -1;
    const executeReq = () => {
        url = url.replace('http:', 'https:')
        console.log(url);

        const options = {
            method:   'HEAD'
        };

        return new Promise(resolve => {
            const req = https.request(url, options, (res) => {
                statusCode = res.statusCode;
                resolve();
                res.on('data', () => {
                    // do nothing
                })
            });
            req.end();
        })
    };

    await executeReq();

    await t.expect(404).eql(statusCode);
});
