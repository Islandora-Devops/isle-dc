import { Selector } from 'testcafe';
import { claUser } from "./roles.js";
import { workbenchContentList } from "./util.js";

fixture`Media file rename tests`
  .page`https://islandora-idc.traefik.me/admin/workbench/content/all`
  .beforeEach(
    async (t) => {
      // user created in format.init.js
      await t.useRole(claUser);
  });

const checkFilename = async (t, itemName, mediaName, filename) => {
  const item = Selector("div.view-content").find("a").withText(itemName);
  await t.expect(item.count).eql(1);
  await t.click(item); 
  await t.click(Selector('#block-idcui-local-tasks').find('a').withText('Media'));

  // assert the presence of the original media
  const media = Selector('div.view-content').find('a').withText(mediaName);
  await t.expect(media.count).eql(1);

  await t.click(Selector(media.parent('tr').child('td').nth(6).find('a').withText('Edit')));

  // assert that the filename is found on the page (orig name was moo.mp3)
  const file = Selector('#block-seven-content').find('a').withText(filename);
  await t.expect(file.count).eql(1);
}

test("Filename setting via migration - Audio", async (t) => {
  await checkFilename(t, "Filename Test Item - Changed", 'Moo Cow New Name', "CowMoo.mp3")
  await t.navigateTo(workbenchContentList);
  await checkFilename(t, "Filename Test Item - Original", 'Moo Cow Orig Name', "moo.mp3")
});

test("Filename setting via migration - Document", async (t) => {
  await checkFilename(t, "Filename Test Item - Changed", "Fuji Acros Datasheet", "ThePDF.pdf")
  await t.navigateTo(workbenchContentList);
  await checkFilename(t, "Filename Test Item - Original", "Fuji Acros Datasheet", "Fuji_acros.pdf")
});

test("Filename setting via migration - Extracted Text", async (t) => {
  await checkFilename(t, "Filename Test Item - Changed", "Hello World", "hiyaworld.txt");
  await t.navigateTo(workbenchContentList);
  await checkFilename(t, "Filename Test Item - Original", "Hello World", "hello_world.txt");
});

test("Filename setting via migration - File", async (t) => {
  await checkFilename(t, "Filename Test Item - Changed", "Geo Tif file", "NewName.tfw");
  await t.navigateTo(workbenchContentList);
  await checkFilename(t, "Filename Test Item - Original", "Geo Tif file", "NEFF1851_GEO.tfw");
});

test("Filename setting via migration - Image", async (t) => {
  await checkFilename(t, "Filename Test Item - Changed", "Looking For Fossils", "family_trip.jpg");
  await t.navigateTo(workbenchContentList);
  await checkFilename(t, "Filename Test Item - Original", "Tiff Image", "tiff.tif");
});

test("Filename setting via migration - Video", async (t) => {
  await checkFilename(t, "Filename Test Item - Changed", "Chair Pop Video", "ChairVideo.mp4");
  await t.navigateTo(workbenchContentList);
  await checkFilename(t, "Filename Test Item - Original", "Chair Pop Video", "chair-pop-gif.mp4");
});
