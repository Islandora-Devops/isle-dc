import { Selector } from 'testcafe';

export class GlobalSearch {
  constructor() {
    this.container = Selector('header #block-idcsearchblock');

    this.input = this.container.find('input[type="text"]');
    this.submitBtn = this.container.find('input[type="submit"]');

    this.advancedSearchLink = this.container.find('a');
  }

  async search(term, testcafe) {
    return await testcafe
      .typeText(this.input, term, { paste: true, replace: true })
      .click(this.submitBtn);
  }
}

export default new GlobalSearch();
