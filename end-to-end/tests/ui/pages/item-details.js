import { Selector, t } from "testcafe";
import ContactModal from "./contact-modal";

export class ItemDetail {
  constructor() {
    this.container = Selector('#item-container');

    this.title = this.container.find('h3').nth(0);
    this.description = this.container.find('#item-description');

    const actions = this.container.find('button');
    this.downloadBtn = actions.withText('Download Item');
    this.exportBtn = actions.withText('Export Metadata');
    this.contactBtn = actions.withText('Ask the Collection Admin');

    this.metadata = this.container.find('.node--id-49 div.field').filterVisible();

    this.contactModal = ContactModal;
  }
}

export class ImageDetail extends ItemDetail {
  constructor() {
    super();
    this.image = this.container.find('field-media--field-media-image');
  }
}

export class BookDetail extends ItemDetail {
  constructor() {
    super();

    this.viewer = this.container.find('#mirador-container');
    this.content = this.viewer.find('main.mirador-viewer');

    this.thumbnails = this.content.find('[data-canvas-id]')
  }
}

export class VideoDetail extends ItemDetail {
  constructor() {
    super();

    this.viewer = this.container.find('video');
    this.source = this.viewer.find('source');
  }
}

export class PDFDetail extends ItemDetail {
  constructor() {
    super();

    this.viewer = this.container.find('iframe[data-test-pdf-viewer]');
  }
}

export class AudioDetail extends ItemDetail {
  constructor() {
    super();

    this.docViewer = this.container.find('iframe[data-test-pdf-viewer]');
    this.audioPlayer = this.container.find('audio');
    this.audioSrc = this.audioPlayer.find('source');
  }
}

export const ItemDetails = new ItemDetail();
export const ImagePage = new ImageDetail();
export const BookPage = new BookDetail();
export const VideoPage = new VideoDetail();
export const DocumentPage = new PDFDetail();
export const AudioPage = new AudioDetail();
