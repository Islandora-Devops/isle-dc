import { Selector, t } from "testcafe";

export class DownloadsModal {
  constructor() {
    this.container = Selector('#media-downloads-modal-container');

    this.closeBtn = this.container.find('button#media-downloads-modal-exit-button');

    this.links = this.container.find('a');
    this.content = this.container.find('.modal-content > div').child();
  }

  visibility() {
    return this.container.filterVisible();
  }

  async closeModal() {
    await t.click(this.closeBtn);
  }
}

export default new DownloadsModal();
