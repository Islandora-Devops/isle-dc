import { Selector } from 'testcafe';

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
    .expect(Selector("title").innerText).match(/.+?\| Default$/);

  // Title contains a styled <span>, which could break up the text with \n or similar
  const mainTitle = Selector('h1').innerText;
  await t
    .expect(mainTitle).contains('DIGITAL REPOSITORIES')
    .expect(mainTitle).contains('@ JHU');

  const contentLinks = Selector('div.dialog-off-canvas-main-canvas a');
  await t
    .expect(contentLinks.count).eql(2)
    .expect(contentLinks.withText('Library Collections').exists).ok()
    .expect(contentLinks.withText('Contact Us').exists).ok();
});

test('Header has expected elements', async (t) => {
  const nav = Selector('nav');
  const links = Selector('nav a');

  await t
    .expect(nav.count).eql(2, 'Should have a nav within a nav')
    .expect(links.count).eql(7, 'Should contain 7 links')
    .expect(links.withText('Sheridan Libraries').exists).ok();

  await t
    .expect(Selector('header img').exists).ok('Library logo is present')
    .expect(Selector('header #block-idcsearchblock').exists).ok('Global search is present');
});

test('Footer has expected elements', async (t) => {
  const text = Selector('footer').innerText;

  await t
    .expect(text).contains('The Sheridan Libraries')
    .expect(text).contains('Johns Hopkins University');

  await t
    .expect(Selector('footer a').count).eql(13);
});
