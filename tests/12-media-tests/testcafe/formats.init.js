import { adminUser } from "./roles.js";
import { doMigration } from "./util.js";
import { migrationType } from "./util.js";

fixture`Ingest Media Formats`
  .page`https://islandora-idc.traefik.me/migrate_source_ui`.beforeEach(
  async (t) => {
    await t.useRole(adminUser);
  }
);

test("Migrate Images for testing format support", async (t) => {
  await doMigration(
    t,
    migrationType.NEW_COLLECTION,
    "./migrations/media-format-collection.csv"
  );
  await doMigration(
    t,
    migrationType.NEW_ITEM,
    "./migrations/media-format-objects.csv"
  );
  await doMigration(
    t,
    migrationType.NEW_MEDIA_IMAGE,
    "./migrations/media-format-image.csv"
  );
  await doMigration(
    t,
    migrationType.NEW_MEDIA_FILE,
    "./migrations/media-format-file.csv"
  );

  await doMigration(
    t,
    migrationType.NEW_ACCESS_TERMS,
    "./migrations/media-format-accessterms.csv")
});

test("Migrate Images for testing filename support", async (t) => {
  await doMigration(
    t,
    migrationType.NEW_ACCESS_TERMS,
    "./migrations/media-fn-accessterms.csv"
  );
  await doMigration(
    t,
    migrationType.NEW_ACCESS_RIGHTS,
    "./migrations/media-fn-accessrights.csv"
  );
  await doMigration(
    t,
    migrationType.NEW_SUBJECTS,
    "./migrations/media-fn-subjects.csv"
  );
  await doMigration(
    t,
    migrationType.NEW_COLLECTION,
    "./migrations/media-fn-collection.csv"
  );
  await doMigration(
    t,
    migrationType.NEW_ITEM,
    "./migrations/media-fn-islandora-object.csv"
  );
  await doMigration(
    t,
    migrationType.NEW_MEDIA_AUDIO,
    "./migrations/media-fn-audio.csv"
  );
  await doMigration(
    t,
    migrationType.NEW_MEDIA_DOCUMENT,
    "./migrations/media-fn-document.csv"
  );
  await doMigration(
    t,
    migrationType.NEW_MEDIA_EXTRACTED_TEXT,
    "./migrations/media-fn-extracted-text.csv"
  );
  await doMigration(
    t,
    migrationType.NEW_MEDIA_FILE,
    "./migrations/media-fn-file.csv"
  );
  await doMigration(
    t,
    migrationType.NEW_MEDIA_IMAGE,
    "./migrations/media-fn-image.csv"
  );
  await doMigration(
    t,
    migrationType.NEW_MEDIA_VIDEO,
    "./migrations/media-fn-video.csv"
  );
});

