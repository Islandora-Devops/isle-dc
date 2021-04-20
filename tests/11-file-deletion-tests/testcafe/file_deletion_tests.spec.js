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
    const fileToDelete = Selector('div.view-content').find('a').withText('FP4 Datasheet');
    await t.expect(fileToDelete.count).eql(1);
    const tr = fileToDelete.parent('tr');
    const referenceCell = tr.child('td').nth(-1);
    await t.expect(referenceCell.innerText).eql('1 place');

    // Navigate to Media listing, verify Media is present containing the File to be deleted
    await t.navigateTo(mediaListing);
    const mediaToDelete = Selector('div.view-content').find('a').withText('FP4 Datasheet');
    await t.expect(mediaToDelete.count).eql(1);

    // Delete the Media and the File
    await t.click(mediaToDelete.parent('tr').find('input'));
    await t.click(Selector('div.view-content').find('input').withAttribute('name', 'op'));
    await t.click(Selector('input').withAttribute('name', 'op').withAttribute('value', 'Delete'));

    // After deleting the media, there are two messages that show on the flash:
    // 'Deleted 2 items.' (A green informational message)
    // '1 item has not been deleted because you do not have the necessary permissions.' (A yellow warning message)

    await t.expect(Selector('div').withAttribute('aria-label', 'Status message').innerText)
        .contains('Deleted 2 items.')
    await t.expect(Selector('div').withAttribute('aria-label', 'Warning message').innerText)
        .contains('1 item has not been deleted because you do not have the necessary permissions.')

    // The two items that would normally be deleted are the Media and the File, but the warning message indicates the
    // that something (the File, in this case) *was not* deleted.

    // Verify the Media is gone
    await t.expect(mediaToDelete.count).eql(0);

    // Navigate to the File listing, verify File is present with zero references (although we wanted the file to be
    // deleted, apparently it can't be due to some permissions issue that is not understood).
    await t.navigateTo(fileListing);
    await t.expect(fileToDelete.count).eql(1);
    await t.expect(referenceCell.innerText).eql('0 places');

    // It isn't clear as to why the File entity survives.  The warning message claims it is a permissions issue, but
    // we are logged in as the admin.  Logging into the container and examining the filesystem permissions shows that
    // the nginx user ought to be able to delete the file (and in fact, you can test this is true by execing into the
    // container as the nginx user and rm'ing a file).

    // Perform HEAD on File's URL and verify it is a 200 (i.e. the bytes are still there)

    let url = await fileToDelete.getAttribute('href');
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

    // When a file is deleted on the s3fs-backed private FS, reading its
    // bytes results in a 403, apparently
    await t.expect(403).eql(statusCode);
});
