import { AudioPage } from "./pages/item-details";

fixture `Audio item with transcription`
  .page `https://islandora-idc.traefik.me/node/56`;

test('Audio player and PDF viewer are present', async (t) => {
  await t
    .expect(AudioPage.docViewer.exists).ok()
    .expect(AudioPage.audioPlayer.exists).ok()
    .expect(AudioPage.audioSrc.exists).ok()
    .expect(AudioPage.audioSrc.withAttribute('type', 'audio/mpeg').exists).ok()
    .expect((await AudioPage.audioSrc.getAttribute('src')).includes('Service%20File.mp3')).ok();
});
