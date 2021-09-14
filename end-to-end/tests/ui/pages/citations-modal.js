import { Selector, t } from "testcafe";

export class CitationsModal {
  constructor() {
    this.container = Selector('#citations-modal-container');

    this.closeBtn = this.container.find('button#citations-modal-exit-button');

    this.citations = this.container.find('.csl-entry');
  }

  visibility() {
    return this.container.filterVisible();
  }

  async closeModal() {
    await t.click(this.closeBtn);
  }
}

export default new CitationsModal();
