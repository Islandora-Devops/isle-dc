import { Selector } from 'testcafe';

export class FeaturedItems {
  constructor() {
    this.list = Selector('#featured-items');

    this.title = this.list.find('h3');
    this.items = this.list.find('[data-test-featured-item]');
  }
}

export default new FeaturedItems();
