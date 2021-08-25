import { Selector } from 'testcafe';
import { Searchable } from "./searchable";

class FeaturedItems {
  constructor() {
    this.list = Selector('#featured-items');

    this.title = this.list.find('h3');
    this.items = this.list.find('[data-test-featured-item]');
  }
}

export class CollectionsList extends Searchable {
  constructor() {
    super();

    this.featuredItems = new FeaturedItems();
  }
}

export default new CollectionsList();
