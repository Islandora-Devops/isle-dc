import { Selector } from 'testcafe';
import { Searchable } from "./searchable";
import FeaturedItems from './featured-items-list';

export class CollectionsList extends Searchable {
  constructor() {
    super();

    this.featuredItems = FeaturedItems;
  }
}

export default new CollectionsList();
