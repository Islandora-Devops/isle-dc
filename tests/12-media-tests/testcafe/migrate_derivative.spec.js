import {Selector} from 'testcafe';
import {adminUser} from './roles.js';
import {doMigration} from './util.js';
import {migrationType} from './util.js';
import {tryUntilTrue} from './util.js';


fixture`Migration Derivative Tests`
    .page`https://islandora-idc.traefik.me/migrate_source_ui`
    .beforeEach(async t => {
        await t
            .useRole(adminUser);
    });

const selectMigration = Selector('#edit-migrations');
const migrationOptions = selectMigration.find('option');

const contentList = "https://islandora-idc.traefik.me/admin/content";

test('Migrate Images for Derivative Generation', async t => {

    // migrate the test objects into Drupal
    await doMigration(t, migrationType.NEW_COLLECTION, './migrations/derivative-collection.csv');
    await doMigration(t, migrationType.NEW_ITEM, './migrations/derivative-islandora_object.csv');
    await doMigration(t, migrationType.NEW_MEDIA_IMAGE, './migrations/derivative-file.csv');

    // verify the presence of the islandora object
    const io_name = "Derivative Repository Item One"
    await t.navigateTo(contentList)
    const io = Selector('div.view-content').find('a').withText(io_name)
    await t.expect(io.count).eql(1);

    // list its media

    await t.click(io)
    await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Media'))

    // assert the presence of the original media
    const media_name = "Map Image";
    const media = Selector('div.view-content').find('a').withText(media_name);
    await t.expect(media.count).eql(1);

    // assert expected attributes of the original media
    await t.expect(media.parent('tr').child('td').nth(2).innerText).eql('Image')
    await t.expect(media.parent('tr').child('td').nth(3).innerText).eql('image/tiff')
    await t.expect(media.parent('tr').child('td').nth(4).innerText).contains('Preservation File')
    await t.expect(media.parent('tr').child('td').nth(4).innerText).contains('Original File')

    // assert the presence of a derivative thumbnail and service image
    // (increase timeout in case derivatives haven't been created yet?)
    const service_derivative = Selector('div.view-content').find('a').withText('Service File.jpg');
    const thumb_derivative = Selector('div.view-content').find('a').withText('Thumbnail Image.jpg');
    const fits_derivative = Selector('div.view-content').find('a').withText('FITS File.xml');

    console.log("Checking for derivatives ...")

    await t.expect(await tryUntilTrue(async () => {
        const service_count = await service_derivative.count
        const thumb_count = await thumb_derivative.count
        const fits_count = await fits_derivative.count
        console.log("Service_count: ", service_count, ", thumb count: ", thumb_count, ", fits count:", fits_count);
        if (service_count < 1 || thumb_count < 1 || fits_count < 1) {
            await t.eval(() => location.reload(true));
            return false;
        }
        return true;
    })).eql(true, "Derivatives have not appeared");

    await t.expect(service_derivative.count).eql(1);
    await t.expect(thumb_derivative.count).eql(1);
    await t.expect(fits_derivative.count).eql(1);
});

test('Test Derivatives Unique Id Field', async t => {

    // note: FITS media do not have this field.
    const media_list = ['Service File.jpg', 'Thumbnail Image.jpg'];
    const io_name = "Derivative Repository Item One"

    // we know these derivatives already exist from last test, so don't repeat those
    // tests here, just look at deriviatives
    for (const media_text of media_list) {
      await t.navigateTo(contentList);
      const io = Selector('div.view-content').find('a').withText(io_name);
      await t.click(io);
      await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Media'));

      const derivative = Selector('div.view-content').find('a').withText(media_text);

      // just make sure they each have a value for unique id field set.
      await t.click(derivative);
      await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Edit'));
      await t.expect(Selector('#edit-field-unique-id-0-value').value).notEql('');
    }
});

test('Test Video Derivative Generation Conditions', async t => {
    await doMigration(t, migrationType.NEW_COLLECTION, './migrations/derivative-collection.csv');
    await doMigration(t, migrationType.NEW_ITEM, './migrations/derivative-islandora_object.csv');
    await doMigration(t, migrationType.NEW_MEDIA_VIDEO, './migrations/derivative-video.csv');
    await doMigration(t, migrationType.NEW_MEDIA_AUDIO, './migrations/derivative-audio.csv');

    // This is a 4 part test: 
    // 1) there should be one video with a deriv
    // 2) there should be one video w/o a deriv
    // 3) there should be one audio file with a deriv
    // 4) there should be one audio file w/o a deriv

    //
    // 1) there should be one video with a deriv
    //
    let io_name = "Derivative Repository Item Video With Deriv";
    await t.navigateTo(contentList)
    let io = Selector('div.view-content').find('a').withText(io_name)
    await t.expect(io.count).eql(1);

    // list its media
    try { 
        await t.click(io)
        await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Media'))
    } catch (err){
        console.log(err);
        if (!err.errStack.includes("Error: Quick Edit")) {
            throw err;
        } else {
            // else ignore this type of error and try again
            await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Media'))
        }
    }

    // assert the presence of the original media
    let media = Selector('div.view-content').find('a').withText("Video With Deriv");
    await t.expect(media.count).eql(1);

    // assert expected attributes of the original media
    await t.expect(media.parent('tr').child('td').nth(2).innerText).eql('Video')
    await t.expect(media.parent('tr').child('td').nth(3).innerText).eql('video/mp4')
    await t.expect(media.parent('tr').child('td').nth(4).innerText).contains('Original File')
    await t.expect(media.parent('tr').child('td').nth(4).innerText).notContains('Service File');

    // assert the presence of a derivative thumbnail and service image
    // (increase timeout in case derivatives haven't been created yet?)
    let service_derivative = Selector('div.view-content').find('a').withText('Service File.mp4');
    let thumb_derivative = Selector('div.view-content').find('a').withText('Thumbnail Image.jpg');
    let fits_derivative = Selector('div.view-content').find('a').withText('FITS File.xml');

    console.log("Checking for derivatives ...")

    await t.expect(await tryUntilTrue(async () => {
        const service_count = await service_derivative.count
        const thumb_count = await thumb_derivative.count
        const fits_count = await fits_derivative.count
        console.log("Service_count: ", service_count, ", thumb count: ", thumb_count, ", fits count:", fits_count);
        if (service_count < 1 || thumb_count < 1 || fits_count < 1) {
            await t.eval(() => location.reload(true));
            return false;
        }
        return true;
    })).eql(true, "Derivatives have not appeared");

    await t.expect(service_derivative.count).eql(1);
    await t.expect(thumb_derivative.count).eql(1);
    await t.expect(fits_derivative.count).eql(1);

    //
    // 2) there should be one video w/o a deriv
    //
    io_name = "Derivative Repository Item Video With No Deriv";
    await t.navigateTo(contentList)
    io = Selector('div.view-content').find('a').withText(io_name)
    await t.expect(io.count).eql(1);

    // list its media
    try { 
        await t.click(io)
        await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Media'))
    } catch (err){
        if (!err.errStack.includes("Error: Quick Edit")) {
            throw err;
        } else {
            // else ignore this type of error and try again
            await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Media'))
        }
    }

    // assert the presence of the original media
    media = Selector('div.view-content').find('a').withText("Video No Deriv");
    await t.expect(media.count).eql(1);

    // assert expected attributes of the original media
    await t.expect(media.parent('tr').child('td').nth(2).innerText).eql('Video')
    await t.expect(media.parent('tr').child('td').nth(3).innerText).eql('video/mp4')
    await t.expect(media.parent('tr').child('td').nth(4).innerText).contains('Original File')
    await t.expect(media.parent('tr').child('td').nth(4).innerText).contains('Service File');

    // assert the presence of a derivative thumbnail and service image
    // (increase timeout in case derivatives haven't been created yet?)
    service_derivative = Selector('div.view-content').find('a').withText('Service File.mp4');
    thumb_derivative = Selector('div.view-content').find('a').withText('Thumbnail Image.jpg');
    fits_derivative = Selector('div.view-content').find('a').withText('FITS File.xml');

    console.log("Checking for derivatives ...")

    await t.expect(await tryUntilTrue(async () => {
        const service_count = await service_derivative.count
        const thumb_count = await thumb_derivative.count
        const fits_count = await fits_derivative.count
        console.log("Service_count: ", service_count, ", thumb count: ", thumb_count, ", fits count:", fits_count);
        if (thumb_count < 1 || fits_count < 1) {
            await t.eval(() => location.reload(true));
            return false;
        }
        return true;
    })).eql(true, "Derivatives have not appeared");

    // there should be no service file. It could show up later, so this might be a weak test. 
    await t.expect(service_derivative.count).eql(0);
    await t.expect(thumb_derivative.count).eql(1);
    await t.expect(fits_derivative.count).eql(1);

    //
    // 3) there should be one audio file with a deriv
    //
    io_name = "Derivative Repository Item Audio With Deriv";
    await t.navigateTo(contentList)
    io = Selector('div.view-content').find('a').withText(io_name)
    await t.expect(io.count).eql(1);

    // list its media
    try { 
        await t.click(io)
        await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Media'))
    } catch (err){
        if (!err.errStack.includes("Error: Quick Edit")) {
            throw err;
        } else {
            // else ignore this type of error and try again
            await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Media'))
        }
    }

    // assert the presence of the original media
    media = Selector('div.view-content').find('a').withText("Audio With Deriv");
    await t.expect(media.count).eql(1);

    // assert expected attributes of the original media
    await t.expect(media.parent('tr').child('td').nth(2).innerText).eql('Audio')
    await t.expect(media.parent('tr').child('td').nth(3).innerText).eql('audio/mp3')
    await t.expect(media.parent('tr').child('td').nth(4).innerText).contains('Original File')
    await t.expect(media.parent('tr').child('td').nth(4).innerText).notContains('Service File');

    // assert the presence of a derivative service image and FITS file
    // (increase timeout in case derivatives haven't been created yet?)
    service_derivative = Selector('div.view-content').find('a').withText('Service File.mp3');
    fits_derivative = Selector('div.view-content').find('a').withText('FITS File.xml');

    console.log("Checking for derivatives ...")

    await t.expect(await tryUntilTrue(async () => {
        const service_count = await service_derivative.count
        const fits_count = await fits_derivative.count
        console.log("Service_count: ", service_count, ", fits count:", fits_count);
        if (service_count < 1 || fits_count < 1) {
            await t.eval(() => location.reload(true));
            return false;
        }
        return true;
    })).eql(true, "Derivatives have not appeared");

    await t.expect(service_derivative.count).eql(1);
    await t.expect(fits_derivative.count).eql(1);

    //
    // 4) there should be one audio file w/o a deriv
    //
    io_name = "Derivative Repository Item Audio With No Deriv";
    await t.navigateTo(contentList)
    io = Selector('div.view-content').find('a').withText(io_name)
    await t.expect(io.count).eql(1);

    // list its media
    try { 
        await t.click(io)
        await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Media'))
    } catch (err){
        if (!err.errStack.includes("Error: Quick Edit")) {
            throw err;
        } else {
            // else ignore this type of error and try again
            await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Media'))
        }
    }

    // assert the presence of the original media
    media = Selector('div.view-content').find('a').withText("Audio No Deriv");
    await t.expect(media.count).eql(1);

    // assert expected attributes of the original media
    await t.expect(media.parent('tr').child('td').nth(2).innerText).eql('Audio')
    await t.expect(media.parent('tr').child('td').nth(3).innerText).eql('audio/mp3')
    await t.expect(media.parent('tr').child('td').nth(4).innerText).contains('Original File')
    await t.expect(media.parent('tr').child('td').nth(4).innerText).contains('Service File');

    // check for the presence of a Service and FITs file. Though there should not be 
    // a separate Service File
    service_derivative = Selector('div.view-content').find('a').withText('Service File.mp3');
    fits_derivative = Selector('div.view-content').find('a').withText('FITS File.xml');

    console.log("Checking for derivatives ...")

    await t.expect(await tryUntilTrue(async () => {
        const service_count = await service_derivative.count
        const fits_count = await fits_derivative.count
        console.log("Service_count: ", service_count, ", fits count:", fits_count);
        if (fits_count < 1) {
            await t.eval(() => location.reload(true));
            return false;
        }
        return true;
    })).eql(true, "Derivatives have not appeared");

    // there should be no service file. It could show up later, so this might be a weak test. 
    await t.expect(service_derivative.count).eql(0);
    await t.expect(fits_derivative.count).eql(1);
});