import { ItemDetails } from "./pages/item-details";

fixture `metadata export`
  .page `https://islandora-idc.traefik.me/node/54`;

test('Metadata export button renders', async (t) => {
  await t.expect(ItemDetails.exportBtn.exists).ok();
});

test('Export produces download link', async (t) => {
  await t
    .click(ItemDetails.exportBtn)
    .expect(ItemsDetails.metadataExportMessageLink.exists).ok();
});
