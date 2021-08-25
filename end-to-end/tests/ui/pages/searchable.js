import { Selector, t } from 'testcafe';

const pagerSelector = Selector('[data-test-search-pager]');

class Pager {
  constructor(index) {
    this.pager = pagerSelector.nth(index);
    this.buttons = this.pager.find('button');
    this.prev = this.buttons.nth(0);
    this.next = this.buttons.nth(-1);
  }
}

class Dropdown {
  constructor(selector) {
    this.select = selector;
    this.options = this.select.find('option');
  }

  async setValue(value) {
    await t
      .click(this.select)
      .click(this.options.filter(`[value="${value}"]`))
  }
}

class ListOptions {
  constructor() {
    this.list = Selector('[data-test-search-options]');

    this.header = this.list.find('h3');
    this.clearBtn = this.list.find('button'); // The only button present

    this.sortBy = new Dropdown(this.list.find('#sort-by'));
    this.sortOrder = new Dropdown(this.list.find('#sort-order'));
    this.itemsPerPage = new Dropdown(this.list.find('#items-per-page'));
    this.currentPage = new Dropdown(this.list.find('#current-page'));
  }
}

/**
 * Represents pages that utilze our GlimmerJS based search component.
 * This should include
 *    - /collections
 *    - /node/## (collections details page)
 *    - /advanced-search
 */
export class Searchable {
  /**
   * @param {number} facets (OPTIONAL) expected number of facets. Default: 0
   */
  constructor() {
    this.searchInput = Selector('[data-test-search-input] input');
    this.searchSubmit = Selector('[data-test-search-input] button');
    this.pagers = [ new Pager(0), new Pager(1) ];
    this.results = Selector('[data-test-search-results-item]');

    this.listOptions = new ListOptions();

    this.facetCategories = Selector('[data-test-facets-category]');
  }

  facetToggle(category) {
    return this.facetCategories.withText(category).find('button:not([data-test-facet-value])');
  }

  facetValueContainer(category) {
    return this.facetCategories.withText(category).find('ul');
  }

  facetValues(category) {
    return this.facetCategories.withText(category).find('[data-test-facet-value]');
  }

  async selectFacet(category, value) {
    await t.click(this.facetValues(category).withText(value));
  }
}

export default new Searchable();
