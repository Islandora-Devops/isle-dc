import { Selector } from "testcafe";
import fs from "fs";
import path from "path";
import url from "url";
import http from "http";

const contentList = "https://islandora-idc.traefik.me/admin/content";

/** Find media for a repository object with the given name
 *
 * Returns an array of media listings, with the following structure:
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
  await navigateToMediaPage(t, name);

  await t.click(
    Selector("#block-idcui-local-tasks").find("a").withText("Media")
  );

  // assert the presence of the original media
  const media_rows = Selector(".views-table").child("tbody").child("tr");

  let count = await media_rows.count;
  let mediaList = Array();

  // Go through each row of its media table, and collect all metadata
  for (var i = 0; i < count; i++) {
    const row = media_rows.nth(i);

    const usages = row.child(".views-field-field-media-use").child("a");
    const usage_count = await usages.count;

    const mediaInfo = {
      name: (await row.child(".views-field-name").innerText).trim(),
      mediaType: (await row.child(".views-field-bundle").innerText).trim(),
      mimeType: (
        await row.child(".views-field-field-mime-type").innerText
      ).trim(),
      pageURL: await row
        .child(".views-field-name")
        .child("a")
        .getAttribute("href"),
    };

    if (usage_count == 0) {
      mediaList.push(mediaInfo);
      continue;
    }

    for (var j = 0; j < usage_count; j++) {
      mediaList.push({
        ...mediaInfo,
        use: await usages.nth(j).innerText,
      });
    }
  }
  return mediaList;
};

const navigateToMediaPage = async (t, name) => {
  // verify the presence of the islandora object, searching by name
  await t.navigateTo(contentList);
  const item = Selector("div.view-content").find("a").withText(name);
  await t.expect(item.count).eql(1);

  // list its media
  await t.click(item);
};

/** Perform a migration using the given file and migration type
 *
 * There is no specific feedback as to the success or failure of this operation, unless an exception is thrown
 *
 * @param {TestController} t Testcafe controller
 * @param {string} migrationType (e.g. idc_ingest_media_file, idc_ingest_new_collection)
 * @param {string} file Path to the cvs file to upload for migration
 */
export const doMigration = async (t, migrationType, file) => {

  console.log('loading migration file: ', file);

  await t.navigateTo("https://islandora-idc.traefik.me/migrate_source_ui");

  const selectMigration = Selector("#edit-migrations");
  const migrationOptions = selectMigration.find("option");

  // migrate the test objects into Drupal
  await t
    .click(selectMigration)
    .click(migrationOptions.withAttribute("value", migrationType))
    .setFilesToUpload("#edit-source-file", [file])
    .click("#edit-import");

  // Now, wait until we see messages on screen that everything has migrated successfully
  await t
    .expect(
      await tryUntilTrue(async () => {
        let status_div = await Selector(".messages--status", { timeout: 1000});
        let status_count = await status_div.count;
        let error_div = await Selector(".messages--error", { timeout: 1000});
        let error_count = await error_div.count;

        console.log("status: ", status_count, ", error: ", error_count);

        // If there is no status block, we're not done
        if (status_count < 1) {
          console.log("no status section present");
          return false;
        }

        // Something failed and was kind enough to leave a message
        if (error_count > 0) {
          let error_msg_count = await Selector(".messages--error").find(".messages__list").count;
          // We need to ignore messages for Drupal security updates as well as module security updates
          // which are formatted slightly differently
          let update_warning_present = await Selector(".messages--error")
            .find(".messages__list")
            .withText("security update").count;

          console.log("error message count: ", error_msg_count);
          if (update_warning_present == 0 || update_warning_present == 1 && error_msg_count > 1) {
            throw "Error performing migrations!";
          } else {
            console.log("Ignoring Drupal Update message");
          }
        }

        // look for the message containing '0 failed', if it's not there, then there was an issue
        await t.expect(
          Selector(".messages")
            .withText(`done with "${migrationType}"`)
            .withText('0 failed').count
        ).eql(1, "Migration didn't finish successfully: some objects failed to import")
        .then(() => console.log(`Migration Done => ${migrationType} : ${file}`));

        return true;
      })
    ).eql(true, "Could not perform migration!");
};

/**
 * Map of known migration types
 */
export const migrationType = {
  NEW_ITEM: "idc_ingest_new_items",
  NEW_COLLECTION: "idc_ingest_new_collection",
  NEW_MEDIA_FILE: "idc_ingest_media_file",
  NEW_MEDIA_IMAGE: "idc_ingest_media_image",
};

/** Download the contents of a url into a file
 *
 * @param {string} uri a URL from which to download content to a file
 * @returns {string} file path of downloaded file
 */
export const download = async (uri) => {
  const basedir = "/tmp/testcafe/" + process.pid;

  await fs.promises.mkdir(basedir, { recursive: true });
  const filename = path.basename(url.parse(uri).pathname);

  const saveTo = basedir + "/" + filename;
  const file = fs.createWriteStream(saveTo);

  await httpget(uri, file);
  return saveTo;
};

/** Upload an Image media type using the admin GUI as media of the given repository object
 *
 * @param {TestController} t Testcafe test controller
 * @param {string} name Name of the repository object for whom to upload an image to
 * @param {string} file path of the file to upload, on disk.
 * @param {string} access term that should be applied to the media that's created
 */
export const uploadImageInUI = async (t, name, file, accessTerm) => {
  await navigateToMediaPage(t, name);
  await t.click(
    Selector("#block-idcui-local-tasks").find("a").withText("Media")
  );
  await t.click(Selector(".button"));
  await t.click(Selector(".admin-list").find("a").withText("local images"));
  await t.click(Selector("#edit-field-media-use-17"));
  await t.expect(Selector("#edit-field-media-use-17").checked).ok();
  await t.click(Selector("#edit-field-access-terms").find("option").withText(accessTerm));
  await t.setFilesToUpload("#edit-field-media-image-0-upload", file);
  await t.click("#edit-submit");
};

/** Upload a File media type using the admin GUI as media of the given repository object
 *
 * @param {TestController} t Testcafe test controller
 * @param {string} name Name of the repository object for whom to upload a file to
 * @param {string} file path of the file to upload, on disk.
 * @param {string} access term that should be applied to the media that's created
 */
export const uploadFileInUI = async (t, name, file, accessTerm) => {
  await navigateToMediaPage(t, name);
  await t.click(
    Selector("#block-idcui-local-tasks").find("a").withText("Media")
  );
  await t.click(Selector(".button"));
  await t.click(Selector(".admin-list").find("a").withText("local files"));
  await t.click(Selector("#edit-field-media-use-17"));
  await t.expect(Selector("#edit-field-media-use-17").checked).ok();
  await t.click(Selector("#edit-field-access-terms").find("option").withText(accessTerm));
  await t.setFilesToUpload("#edit-field-media-file-0-upload", file);
  await t.click("#edit-submit");
};

const httpget = (uri, file) => {
  return new Promise((resolve) => {
    http.get(uri, (response) => response.pipe(file));
    resolve();
  });
};

/** Tries given function repeatedly until it returns true; throwing an exception if success isn't achieved until deadline_ms milliseconds
 *
 * @param {function} func function to call until it returns a truthy result, or the deadline passes
 * @param {number} deadline_ms deadline in miliseconds
 * @returns
 */
export const tryUntilTrue = async (
  func,
  deadline_ms = process.env.TEST_OPERATION_TIMEOUT_MS
) => {
  console.log("tryUntilTrue timeout: ", deadline_ms);
  if (deadline_ms == undefined) {
    deadline_ms = 30000;
  }
  console.log("tryUntilTrue timeout: ", deadline_ms);
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
};
