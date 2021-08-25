import { Selector, t } from "testcafe";

/**
 * Base admin page for media. Contains a button to add media and a list of all
 * media in the system.
 */
class AddMedia {
  constructor() {
    this.addBtn = Selector('[data-drupal-link-system-path="media/add"]');
    this.currentMedia = Selector('table td[headers="view-name-table-column"]');
  }

  async addMedia(mediaType) {
    const link = Selector('a .label').withText(mediaType);
    await t
      .expect(this.addBtn.exists).ok()
      .click(this.addBtn)
      .click(link);
  }
}

/**
 * Base page for entering media data
 */
class Media {
  constructor() {
    this.name = Selector('#edit-name-0-value');
    this.file = Selector('input[type="file"]');
    this.uploadedFile = Selector('span.file');
    this.accessTerms = Selector('#edit-field-access-terms option');
    this.mediaOf = Selector('#edit-field-media-of-0-target-id');
    this.submit = Selector('#edit-submit');

    this.mediaUse = Selector('#edit-field-media-use');
  }

  async toggleMediaUse(mediaUse) {
    // const checkbox = this.mediaUse
    //   .find('label').withText(mediaUse)
    //   .parent().find('input[type="checkbox"]');
    await t.click(this.mediaUse.find('label').withText(mediaUse));
  }

  /**
   *
   * @param {binary} file file bits
   * @param {string} name file name
   * @param {string} parent parent object title
   * @param {string} accessTerm AccessTerm
   * @param {string} mediaUse MediaUse
   */
  async fillInfo(file, name, parent, accessTerm, mediaUse) {
    await t
      .typeText(this.name, name, { paste: true }) // Set media name
      .setFilesToUpload(this.file, file)  // Add file
      .expect(this.uploadedFile.exists).ok()
      .click(this.accessTerms.withText(accessTerm)) // Set access term
      .typeText(this.mediaOf, parent, { paste: true }) // Type name of parent
      .click(Selector('li').withText(parent)); // Click the autocompleted item to set 'media of'

    await this.toggleMediaUse(mediaUse);
  }

  async submitMedia() {
    await t.click(this.submit);
  }
}

/**
 * Admin page for adding an image media
 */
class Image extends Media {
  constructor() {
    super();
    this.altText = Selector('label').withText('Alternative text').parent().find('input[type="text"]');
  }

  async addImage(file, name, parent, accessTerm, mediaUse, altText) {
    await this.fillInfo(file, name, parent, accessTerm, mediaUse);
    await t.typeText(this.altText, altText, { paste: true });
  }
}

export const MediaType = {
  Audio: 'Audio',
  Document: 'Document',
  ExtractedText: 'Extracted Text',
  File: 'File',
  FITS: 'FITS Technical metadata',
  Image: 'Image',
  RemoteVideo: 'Remote video',
  Video: 'Video'
};

export const MediaUse = {
  ExtractedText: 'Extracted Text',
  FITS: 'FITS File',
  Intermediate: 'Intermediate File',
  Original: 'Original File',
  Preservation: 'Preservation Master File',
  Service: 'Service File',
  Thumbnail: 'Thumbnail Image',
  Transcript: 'Transcript'
}

export const AddMediaPage = new AddMedia();
export const MediaPage = new Media();
export const ImagePage = new Image();
