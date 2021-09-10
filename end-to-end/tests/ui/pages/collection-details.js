import { Selector, t } from "testcafe";
import { Searchable } from './searchable';
import ContactModal from "./contact-modal";
import FeaturedItems from "./featured-items-list";

/**
 * The collections details page has all the features of the /collections
 * list, but also displays metadata and related functions for an individual
 * collection.
 *
 * This page also has facets present on the search component, unlike the
 * /collections list.
 */
export class CollectionDetails extends Searchable {
  constructor() {
    super();

    // TODO: Use a data-test- attribute to name this
    this.description = Selector('#block-idcui-content > div:first-of-type .col-span-2');

    const collectionActions = Selector('#about-collection-button-group button');
    this.contactBtn = collectionActions.nth(0);
    this.copyUrlBtn = collectionActions.nth(1);
    this.downloadBtn = collectionActions.nth(2);

    const detailsDrawer = Selector('[data-test-collection-details-drawer]');
    this.drawerToggle = detailsDrawer.find('button');
    this.drawerContent = detailsDrawer.find('#drawer-content');
    this.metadata = this.drawerContent.child('div');

    const facetsContainer = Selector('[data-test-facets-container]');
    this.facetCategories = facetsContainer.child('[data-test-facets-category]');

    this.contactModal = ContactModal;

    this.featuredItems = FeaturedItems;

    this.exportItmBtn = Selector('a').withExactText('Export Item Metadata');
    this.exportColBtn = Selector('a').withExactText('Export Collection Metadata');
  }

  async toggleMetadata() {
    await t.click(this.drawerToggle);
  }

  async openContact() {
    await t.click(this.contactBtn);
  }
}

export default new CollectionDetails();
