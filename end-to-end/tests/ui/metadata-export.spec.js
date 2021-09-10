import { anon, localAdmin } from "../roles";
import { ItemDetails } from "./pages/item-details";

fixture `Metadata export`
  .page `https://islandora-idc.traefik.me/node/54`
  .beforeEach(async t => await t.useRole(localAdmin));

test('Metadata export button renders', async (t) => {
  await t.expect(ItemDetails.exportBtn.exists).ok();
});

test('Export produces download link', async (t) => {
  await t
    .click(ItemDetails.exportBtn)
    .expect(ItemDetails.metadataExportMessageLink.exists)
      .ok('Couldn\'t find download link', { timeout: 30000 });
});

test('Export not present if not logged in', async (t) => {
  await t
    .useRole(anon)
    .expect(ItemDetails.exportBtn.exists).notOk();
});
