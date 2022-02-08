import { Selector, t } from 'testcafe';
import { Searchable } from './searchable';

class KeySearch {
  constructor(parent) {
    this.field = parent.find('[data-test-advanced-search-field]');
    this.fields = this.field.find('option');
    this.term = parent.find('input[data-test-advanced-search-query-input]');
  }
}

class ProxySearch {
  constructor(parent) {
    this.termA = parent.find('[data-test-advanced-search-proxy-terma]');
    this.range = parent.find('[data-test-advanced-search-proxy-range]');
    this.termB = parent.find('[data-test-advanced-search-proxy-termb]');
  }
}

class QueryTerm {
  constructor(index) {
    const container = new Selector('[data-test-advanced-search-query-term]').nth(index);

    this.proxy = container.find('input[data-test-advanced-search-proxy]');

    this.nonproxyTerm = new KeySearch(container);
    this.proxyTerm = new ProxySearch(container);

    this.removeBtn = container.find('button[data-test-advanced-search-remove]');

    this.operation = container.find('[data-test-advanced-search-query-operations]');
    this.opAnd = this.operation.find('[data-test-advanced-search-operation-and]');
    this.opOr = this.operation.find('[data-test-advanced-search-operation-or]');
    this.opNot = this.operation.find('[data-test-advanced-search-operation-not]');
  }

  selectedOp() {
    return this.operation.find('button.selected');
  }
}

class CollectionsFilter {
  constructor() {
    const container = new Selector('[data-test-collection-lookup-filter]');
    this.toggle = container.parent().sibling('button');
    this.selectedCollections = container.find('[data-test-collection-lookup-selected-item]');
    this.input = container.find('[data-test-collection-lookup-input]');
    this.clearBtn = this.input.parent().find('button[title="Clear"]');
    this.suggestions = container.find('[data-test-collection-lookup-suggestions] li');
  }
}

export class AdvancedSearch extends Searchable {
  constructor() {
    super();
    const container = new Selector('#idc-search[data-enable-advanced-search="true"]')

    this.collectionsFilter = new CollectionsFilter();

    this.languageFilter = new Selector('[data-test-language-filter]');
    this.languageToggle = this.languageFilter.parent().sibling('button');
    this.langaugeFilterOptions = this.languageFilter.find('[data-test-language-filter-item]');
    this.selectedLanguages = this.languageFilter.find('[data-test-language-filter-item].bg-blue-spirit');

    this.dateFilter = new Selector('[data-test-date-filter]');
    this.dateToggle = this.dateFilter.parent().sibling('button');
    this.dateInput1 = this.dateFilter.find('input').nth(0);
    this.dateInput2 = this.dateFilter.find('input').nth(1);

    this.addTermBtn = container.find('button').withText('Add term');
    this.helpBtn = container.find('button[data-test-advanced-search-help-drawer]');
    this.submitBtn = container.find('button').withExactText('Search');

    // Various clear buttons
    const clearBtns = container.find('button').withText('Clear');
    this.clearListOptions = clearBtns.nth(0);
    this.clearFilters = clearBtns.nth(1);
    this.clearTerms = clearBtns.nth(2);

    this.queryTerms = [
      new QueryTerm(0)
    ];
  }

  /**
   * Get the query term at the given index. If the requested index does not already exist,
   * then create it first.
   *
   * TODO: Not 100% correct, will push one new term if an index is out of bounds, but won't
   * create a set of new terms until the index is reached
   * @param {number} index
   * @returns {QueryTerm}
   */
  queryTerm(index) {
    if ( index >= this.queryTerms.length ) {
      this.queryTerms.push(new QueryTerm(index));
    }

    return this.queryTerms[index];
  }
}

export default new AdvancedSearch();
