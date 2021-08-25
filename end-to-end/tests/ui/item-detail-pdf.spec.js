import { DocumentPage } from "./pages/item-details";

fixture `PDF document`
  .page `https://islandora-idc.traefik.me/node/54`;

test('PDF viewer renders', async (t) => {
  await t.expect(DocumentPage.viewer.exists).ok();
});
