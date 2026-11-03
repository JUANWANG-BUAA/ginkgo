// Standalone Node test; no packages, network, credentials, or application runtime.
const assert = require('node:assert/strict');
const fs = require('node:fs');
const vm = require('node:vm');
const { test } = require('node:test');
const path = require('node:path');
const root = path.join(__dirname, '..');
const source = fs.readFileSync(path.join(root, 'docs/landing.js'), 'utf8');
const base = 'https://github.com/JUANWANG-BUAA/ginkgo/releases/';
function release(version, checksum) {
  const tag = `android-v${version}`;
  const apk = `Ginkgo-${version}-android-arm64.apk`;
  return {
    tag_name: tag, draft: false, published_at: version.includes('beta.6') ? '2026-11-01T16:41:41Z' : '2026-10-31T00:00:00Z',
    html_url: `${base}tag/${tag}`,
    assets: [apk, checksum === 'sidecar' ? `${apk}.sha256` : checksum].filter(Boolean).map(name => ({ name, size: 1, browser_download_url: `${base}download/${tag}/${name}` })),
  };
}
async function run(payload, failure = false) {
  const state = new Map();
  const document = {
    querySelector: () => null, getElementById: () => null, addEventListener: () => {},
    querySelectorAll: selector => {
      if (!state.has(selector)) state.set(selector, { href: 'static-fallback', textContent: 'static-version' });
      return [state.get(selector)];
    },
  };
  const context = { document, URL, AbortController, setTimeout, clearTimeout, fetch: async () => {
    if (failure) throw new Error('synthetic offline');
    return { ok: true, json: async () => payload };
  } };
  vm.runInNewContext(source.replace('void updateReleaseLinks();', 'globalThis.finished = updateReleaseLinks();'), context);
  await context.finished;
  return state;
}
test('latest Android with its own APK sidecar is not skipped for an older checksums.txt release', async () => {
  const latest = release('0.1.0-beta.6', 'sidecar');
  const state = await run([latest, release('0.1.0-beta.4', 'checksums.txt')]);
  assert.equal(state.get('[data-android-version]').textContent, '0.1.0-beta.6');
  assert.equal(state.get('[data-android-checksums]').href, latest.assets[1].browser_download_url);
});
test('an unrelated sidecar does not validate a newer Android release', async () => {
  const state = await run([release('0.1.0-beta.6', 'other.apk.sha256'), release('0.1.0-beta.4', 'checksums.txt')]);
  assert.equal(state.get('[data-android-version]').textContent, '0.1.0-beta.4');
});
test('an untrusted checksum URL does not validate a newer Android release', async () => {
  const latest = release('0.1.0-beta.6', 'sidecar');
  latest.assets[1].browser_download_url = 'https://untrusted.example/checksums.txt';
  const state = await run([latest, release('0.1.0-beta.4', 'checksums.txt')]);
  assert.equal(state.get('[data-android-version]').textContent, '0.1.0-beta.4');
});
test('API failure keeps static links without inventing a version', async () => {
  const state = await run([], true);
  assert.equal(state.has('[data-download-apk]'), false);
});
test('static Android fallback points to the APK sidecar that Beta.6 actually publishes', () => {
  const html = fs.readFileSync(path.join(root, 'docs/index.html'), 'utf8');
  const apk = html.match(/data-download-apk href="([^"]+)"/)[1];
  const checksum = html.match(/data-android-checksums href="([^"]+)"/)[1];
  assert.equal(checksum, `${apk}.sha256`);
});
