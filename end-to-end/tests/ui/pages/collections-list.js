import { Selector } from 'testcafe';
import { Searchable } from "./searchable";
import FeaturedItems from './featured-items-list';

export class CollectionsList extends Searchable {
  constructor() {
    super();

    this.featuredItems = FeaturedItems;

    this.exportItmBtn = Selector('a').withExactText('Export Item Metadata');
    this.exportColBtn = Selector('a').withExactText('Export Collection Metadata');
  }
}

export default new CollectionsList();
