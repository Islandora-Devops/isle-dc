import http from 'http';
import { Selector } from 'testcafe';
import { migrate } from '../helpers';
import { localAdmin } from '../roles';

const migrate_new_items = 'idc_ingest_new_items';
const migrate_new_collection = 'idc_ingest_new_collection';
const migrate_media_image = 'idc_ingest_media_image';

const selectMigration = Selector('#edit-migrations');
const migrationOptions = selectMigration.find('option');
const status = Selector('.messages--status').withText('0 failed');

const contentList = "https://islandora-idc.traefik.me/admin/content";

fixture`S3 Tests`
    .page`https://islandora-idc.traefik.me/migrate_source_ui`
    .beforeEach(async t => {
        await t
            .useRole(localAdmin);
    })

test('Verify original file and derivatives are in S3', async t => {

    // migrate the test objects into Drupal
    await migrate(t, 'idc_ingest_taxonomy_islandora_accessterms', '../testdata/s3/access-terms.csv');
    await migrate(t, 'idc_ingest_taxonomy_subject', '../testdata/s3/subject.csv');
    await migrate(t, 'idc_ingest_taxonomy_corporatebody', '../testdata/s3/corporatebody.csv');
    await migrate(t, migrate_new_collection, '../testdata/s3/s3-collection.csv');
    await migrate(t, migrate_new_items, '../testdata/s3/s3-islandora_object.csv');
    await migrate(t, migrate_media_image, '../testdata/s3/s3-file.csv', 30000);

    // verify the presence of the islandora object
    const io_name = "S3 Repository Item 1"
    await t.navigateTo(contentList)
    const io = Selector('div.view-content').find('a').withText(io_name)
    await t.expect(io.count).eql(1);

    // list its media

    await t.click(io)
    await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Media'))

    // assert the presence of the original media
    const media_name = "S3 Image";
    const media = Selector('div.view-content').find('a').withText(media_name);
    await t.expect(media.count).eql(1);

    // assert expected attributes of the original media
    await t.expect(media.parent('tr').child('td').nth(2).innerText).eql('Image')
    await t.expect(media.parent('tr').child('td').nth(3).innerText).eql('image/png')
    await t.expect(media.parent('tr').child('td').nth(4).innerText).contains('Original File')

    // assert the presence of a derivative thumbnail and service image
    // (increase timeout in case derivatives haven't been created yet?)
    const service_derivative = Selector('div.view-content').find('a').withText('Service File.jpg');
    const thumb_derivative = Selector('div.view-content').find('a').withText('Thumbnail Image.jpg');
    const fits_derivative = Selector('div.view-content').find('a').withText('FITS File.xml');

    const service_count = await service_derivative.count
    const thumb_count = await thumb_derivative.count
    const fits_count = await fits_derivative.count

    // if a derivative isn't present yet, it may be because it hasn't been generated yet.
    // in that case, wait 30 seconds and refresh the page, and see if it appears.
    if (service_count < 1 || thumb_count < 1 || fits_count < 1) {
        console.log("Derivatives haven't appeared.  Sleeping for 30 seconds, then trying again ...")
        // sleep 30 seconds, refresh the page
        await t.wait(30000);
        await t.eval(() => location.reload());
    }

    await t.expect(service_derivative.count).eql(1);
    await t.expect(thumb_derivative.count).eql(1);
    await t.expect(fits_derivative.count).eql(1);

    const original_uri = await media.getAttribute('href');
    const thumb_media_uri = await thumb_derivative.getAttribute('href');
    const service_media_uri = await service_derivative.getAttribute('href');

    let uris = {
        original: original_uri,
        thumbnail: thumb_media_uri,
        service: service_media_uri,
    }

    for (const kind in uris) {
        await t.navigateTo(uris[kind]);
        const drupal_src = await Selector('img').withAttribute('typeof', 'foaf:Image').getAttribute('src');
        const minio_src = drupal_src.replace('/system/files',' http://minio:9000/idc/local').trim();
        var statusCode;
        const executeReq = () => {

            const options = {
                method:   'HEAD',
                timeout: 1000
            };

            return new Promise(resolve => {
                const req = http.request(minio_src, options, (res) => {
                    statusCode = res.statusCode;
                    resolve();
                });
                req.end();
            });
        };

        await executeReq();
        await t.expect(statusCode).eql(200, kind + "file not in S3: " + minio_src);
    }

});
