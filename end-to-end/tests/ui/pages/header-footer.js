import { Selector } from "testcafe";

/**
 * This contains the header + footer that wraps all pages in IDC
 */
export class HeaderFooter {
  constructor() {
    this.title = Selector('title');

    // Should be 2 'nav' elements, one nested in the other
    this.nav = Selector('nav');
    this.navLinks = this.nav.find('a');

    this.logo = Selector('header img');
    this.globalSearch = Selector('header #block-idcsearchblock');

    this.footer = Selector('footer');
    this.footerLinks = this.footer.find('a');

    this.breadcrumbContainer = Selector('.breadcrumb');
    this.breadcrumbs = this.breadcrumbContainer.find('.breadcrumb__link');
  }
}

export default HeaderFooter = new HeaderFooter();
