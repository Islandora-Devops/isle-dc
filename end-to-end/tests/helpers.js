import { ClientFunction, Selector } from 'testcafe';
import fs from "fs";
import path from "path";
import url from "url";
import http from "http";

export const getCurrentUrl = ClientFunction(() => window.location.href);

export async function clearCache(t) {
  return await t
    .click('#toolbar-item-devel')
    .click('a[data-drupal-link-system-path="devel/cache/clear"]')
    .expect(Selector('.messages').withText('Cache cleared').exists).ok();
}

const httpget = (uri, file) => {
  return new Promise((resolve) => {
    http.get(uri, (response) => response.pipe(file));
    resolve();
  });
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

/**
 * This function assumes the test is already on the '/migrate_source_ui' page.
 *
 * Execute a migration in the UI, then wait for a status message to appear
 * on screen comfirming it was run. This makes no distinction between a
 * successfull or failed migration.
 *
 * Note, if a migration is run multiple times, the system should overwrite or
 * update already existing nodes.
 *
 * @param t testcafe class
 * @param {string} migrationId system ID of the desired migration
 * @param {string} sourceFile file path of the migration data
 * @param {number} timeout (OPTIONAL) time in ms to wait for migration status message
 *                  Default: 10000 (10 seconds)
 */
export async function migrate(t, migrationId, sourceFile, timeout = 10000) {
  const selectMigration = Selector('#edit-migrations');
  const migrationOptions = selectMigration.find('option');
  const fileInput = Selector('#edit-source-file');

  await t
    .expect(sourceFile).ok('No file path was provided')
    .click(selectMigration)
    .click(migrationOptions.withAttribute('value', migrationId))
    .setFilesToUpload(fileInput, [ sourceFile ])
    .click('#edit-import')
    // .takeScreenshot(`Migration-result-${migrationId}.png`)
    .expect(
      Selector('.messages--status')
        .withText(`done with "${migrationId}"`)
        .withText('0 failed')
        .exists
    ).ok(
      `Failed migration => (${migrationId} : ${sourceFile})`,
      { timeout: timeout }
    )
    .then(() => console.log(`  - Migration done => ${migrationId} : ${sourceFile}`))
    .catch(async (e) => {
      const messagesLink = Selector('.messages a').withText('here');
      const errorScreenshot = `Migration_error_${migrationId}--${sourceFile}.png`;

      if (messagesLink.exists) {
        await t
          .click(messagesLink)
          .takeScreenshot(errorScreenshot);
      } else {
        await t.takeScreenshot(errorScreenshot);
      }

      console.log(`#### Something went wrong: see screenshot ${errorScreenshot} ####`);
      console.log(e);
    });
}
