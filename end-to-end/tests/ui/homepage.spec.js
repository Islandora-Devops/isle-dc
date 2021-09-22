import Homepage from './pages/home';
import HeaderFooter from './pages/header-footer';

/**
 * Test static some elements
 *  - the homepage
 *  - header / footer
 *
 * Note: Seems like Selector('cssSelector').filter('cssSelector') doesn't
 * work as expected. Need a timeout?
 */

fixture`Homepage`
  .page`https://islandora-idc.traefik.me`;

test('Homepage has expected text', async (t) => {
  // Check page title
  await t
    .expect(HeaderFooter.title.innerText).match(/.+?\| Default$/);

  // Title contains a styled <span>, which could break up the text with \n or similar
  const mainTitle = Homepage.mainTitle.innerText;
  await t
    .expect(mainTitle).contains('HOPKINS DIGITAL LIBRARY');

  const contentLinks = Homepage.contentLinks;
  await t
    .expect(contentLinks.count).eql(4)
    .expect(contentLinks.withText('Library Collections').exists).ok()
    .expect(contentLinks.withText('Contact Us').exists).ok();
});

test('Header has expected elements', async (t) => {
  const nav = HeaderFooter.nav;
  const links = HeaderFooter.navLinks;

  await t
    .expect(nav.count).eql(2, 'Should have a nav within a nav')
    .expect(links.count).eql(7, 'Should contain 7 links')
    .expect(links.withText('Sheridan Libraries').exists).ok();

  await t
    .expect(HeaderFooter.logo.exists).ok('Library logo is present')
    .expect(HeaderFooter.globalSearch.exists).ok('Global search is present');
});

test('Footer has expected elements', async (t) => {
  const text = HeaderFooter.footer.innerText;

  await t
    .expect(text).contains('The Sheridan Libraries')
    .expect(text).contains('Johns Hopkins University');

  await t
    .expect(HeaderFooter.footerLinks.count).eql(13);
});
