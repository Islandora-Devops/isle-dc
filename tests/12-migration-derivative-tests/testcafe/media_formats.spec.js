import { adminUser } from "./roles.js";
import { findMediaOf } from "./util.js";
import { tryUntilTrue } from "./util.js";
import { download } from "./util.js";
import { uploadImageInUI } from "./util.js";

fixture`Media format tests`
  .page`https://islandora-idc.traefik.me/migrate_source_ui`.beforeEach(
  async (t) => {
    await t.useRole(adminUser);
  }
);

test("Migrate tiff", async (t) => {
  await t
    .expect(
      await tryUntilTrue(async () => {
        const media = await findMediaOf(t, "Migrated Tiff Object");
        return media.length == 3;
      })
    )
    .eql(true, "Did not find TIFF derivatives");
});

test("Upload tiff in UI", async (t) => {
  const file = await download(
    "http://migration-assets/assets/image/formats/tiff.tif"
  );
  await uploadImageInUI(t, "Uploaded Tiff Object", file);

  await t
    .expect(
      await tryUntilTrue(async () => {
        const media = await findMediaOf(t, "Uploaded Tiff Object");
        return media.length == 3;
      })
    )
    .eql(true, "Did not find TIFF derivatives");
});

test("Migrate jpeg 2000", async (t) => {
  await t
    .expect(
      await tryUntilTrue(async () => {
        const media = await findMediaOf(t, "Migrated JPEG2000 Object");
        return media.length == 3;
      })
    )
    .eql(true, "Did not find JPEG 2000 derivatives");
});

test("Upload jpeg 2000 in UI", async (t) => {
  const file = await download(
    "http://migration-assets/assets/image/formats/jp2.jp2"
  );
  await uploadImageInUI(t, "Uploaded JPEG2000 Object", file);

  await t
    .expect(
      await tryUntilTrue(async () => {
        const media = await findMediaOf(t, "Uploaded JPEG2000 Object");
        return media.length == 3;
      })
    )
    .eql(true, "Did not find TIFF derivatives");
});
