import { Selector } from 'testcafe';
import { Searchable } from "./searchable";
import FeaturedItems from './featured-items-list';

export class CollectionsList extends Searchable {
  constructor() {
    super();

    this.featuredItems = FeaturedItems;

    this.exportItmBtn = Selector('a').withExactText('Export Metadata – Items');
    this.exportColBtn = Selector('a').withExactText('Export Metadata – Collections');
  }
}

export default new CollectionsList();
