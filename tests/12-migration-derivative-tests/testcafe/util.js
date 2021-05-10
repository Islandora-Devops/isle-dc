import { Selector } from 'testcafe';

const contentList = "https://islandora-idc.traefik.me/admin/content";

/** Find media for a repository object with the given name
 * 
 * Returns an arrat of media listings, with the following structure:
 * <code>
 * {
 *   name: string, // Name of the media
 *   mediaType: string // media type (e.g. Image, Video, etc);
 *   mimeType: string // mime type
 *   pageUrl: string // URL to the media page in Drupal UI
 *   use: string // Islandora media use (from the media usage taxonomy)
 * }
 * </code>
 * @param {TestController} t Testcafe controller
 * @param {string} name Value of the name field for the desired repository object
 * @returns {Promise} Promise of an array of media listings
 * }
 */
export const findMediaOf = async (t, name) => {

    // verify the presence of the islandora object, searching by name
    await t.navigateTo(contentList)
    const item = Selector('div.view-content').find('a').withText(name)
    await t.expect(item.count).eql(1);

    // list its media
    await t.click(item)
    await t.click(Selector('#rid-content').find('a').withText('Media'))

    // assert the presence of the original media
    const media_rows = Selector('.views-table').child('tbody').child('tr');

    let count = await media_rows.count;
    let mediaList = Array();

    // Go through each row of its media table, and collect all metadata
    for (var i = 0; i < count; i++) {

        const row = media_rows.nth(i);

        const usages = row.child('.views-field-field-media-use').child('a');
        const usage_count = await usages.count;

        const mediaInfo = {
            name: (await row.child('.views-field-name').innerText).trim(),
            mediaType: (await row.child('.views-field-bundle').innerText).trim(),
            mimeType: (await row.child('.views-field-field-mime-type').innerText).trim(),
            pageURL: await row.child('.views-field-name').child('a').getAttribute('href'),
        }

        if (usage_count == 0) {
            mediaList.push(mediaInfo);
            continue;
        }

        for (var j = 0; j < usage_count; j++) {
            mediaList.push({
                ...mediaInfo,
                use: await usages.nth(j).innerText
            });
        }
    }
    return mediaList;
}

/** Perform a migration using the given file and migration type
 * 
 * There is no specific feedback as to the success or failure of this operation, unless an exception is thrown
 * 
 * @param {TestController} t Testcafe controller
 * @param {string} migrationType (e.g. idc_ingest_media_file, idc_ingest_new_collection)
 * @param {string} file Path to the cvs file to upload for migration
 */
export const doMigration = async (t, migrationType, file) => {

    await t.navigateTo('https://islandora-idc.traefik.me/migrate_source_ui');

    const selectMigration = Selector('#edit-migrations');
    const migrationOptions = selectMigration.find('option');

    // migrate the test objects into Drupal
    await t
        .click(selectMigration)
        .click(migrationOptions.withAttribute('value', migrationType));

    await t
        .setFilesToUpload('#edit-source-file', [file])
        .click('#edit-import');
}

export const migrationType = {
    'NEW_ITEM': 'idc_ingest_new_items',
    'NEW_COLLECTION': 'idc_ingest_new_collection',
    'NEW_MEDIA_FILE': 'idc_ingest_media_file',
    'NEW_MEDIA_IMAGE': 'idc_ingest_media_image'
}
/**
 * 
 * @param {function} func function to call until it returns a truthy result, or the deadline passes
 * @param {number} deadline_ms deadline in miliseconds
 * @returns 
 */
export const tryUntilTrue = async (func, deadline_ms = process.env.TEST_OPERATION_TIMEOUT_MS) => {
    
    let expired = false;
    setTimeout(() => {
        expired = true;
    }, deadline_ms);

    for (;;) {
        if (expired) {
            return false;
        }

        if (await func()) {
            return true;
        } 
    }
}
