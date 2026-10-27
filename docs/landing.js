"use strict";

// Native links/details remain usable without JavaScript.
const mobileNavigation = document.querySelector(".mobile-nav");
mobileNavigation?.querySelectorAll("a").forEach((link) => {
  link.addEventListener("click", () => {
    mobileNavigation.open = false;
  });
});
document.addEventListener("keydown", (event) => {
  if (event.key === "Escape" && mobileNavigation?.open) {
    mobileNavigation.open = false;
    mobileNavigation.querySelector("summary")?.focus();
  }
});

const preview = document.getElementById("lightbox");
const previewImage = preview?.querySelector("img");
let previewTrigger = null;
if (preview && previewImage && typeof preview.showModal === "function") {
  document.querySelectorAll("[data-preview]").forEach((link) => {
    link.addEventListener("click", (event) => {
      // Preserve open-in-new-tab gestures and the plain image-link fallback.
      if (
        event.button !== 0 ||
        event.ctrlKey ||
        event.metaKey ||
        event.shiftKey ||
        event.altKey
      )
        return;
      const source = link.querySelector("img");
      if (!source) return;
      event.preventDefault();
      previewTrigger = link;
      previewImage.src = source.currentSrc || source.src;
      previewImage.alt = source.alt;
      document.getElementById("preview-title").textContent = source.alt;
      preview.showModal();
    });
  });
  preview.addEventListener("click", (event) => {
    if (event.target === preview) {
      const bounds = preview.getBoundingClientRect();
      if (
        event.clientX < bounds.left ||
        event.clientX > bounds.right ||
        event.clientY < bounds.top ||
        event.clientY > bounds.bottom
      )
        preview.close();
    }
  });
  preview.addEventListener("close", () => {
    previewTrigger?.focus();
  });
}

// Mac, Android and Windows are independent release streams. A newer build on one
// platform must never replace another platform's CTA. Verified static assets
// survive API/network failure.
const releaseRoot = "/JUANWANG-BUAA/ginkgo/releases/";
function trustedReleaseURL(value, prefix) {
  if (typeof value !== "string") return false;
  try {
    const url = new URL(value);
    return (
      url.origin === "https://github.com" &&
      !url.username &&
      !url.password &&
      url.pathname.startsWith(releaseRoot + prefix)
    );
  } catch {
    return false;
  }
}
function releaseAsset(release, suffix) {
  return (Array.isArray(release.assets) ? release.assets : []).find(
    (item) =>
      item &&
      typeof item.name === "string" &&
      item.name.endsWith(suffix) &&
      item.size > 0 &&
      trustedReleaseURL(item.browser_download_url, "download/"),
  );
}
function updateLinks(selector, value) {
  document.querySelectorAll(selector).forEach((link) => {
    link.href = value;
  });
}
function updateText(selector, value) {
  document.querySelectorAll(selector).forEach((element) => {
    element.textContent = value;
  });
}
async function updateReleaseLinks() {
  const controller = new AbortController();
  const timeout = setTimeout(() => controller.abort(), 8000);
  try {
    const response = await fetch(
      "https://api.github.com/repos/JUANWANG-BUAA/ginkgo/releases?per_page=100",
      {
        headers: { Accept: "application/vnd.github+json" },
        signal: controller.signal,
      },
    );
    if (!response.ok) return;
    const payload = await response.json();
    const releases = (Array.isArray(payload) ? payload : [])
      .filter(
        (item) => item && !item.draft && typeof item.tag_name === "string",
      )
      .sort(
        (a, b) =>
          (Date.parse(b.published_at) || 0) - (Date.parse(a.published_at) || 0),
      );
    const mac = releases.find(
      (item) => /^v\d/.test(item.tag_name) && releaseAsset(item, ".dmg"),
    );
    const android = releases.find(
      (item) =>
        /^android-v\d/.test(item.tag_name) &&
        releaseAsset(item, "-android-arm64.apk") &&
        releaseAsset(item, "checksums.txt") &&
        trustedReleaseURL(item.html_url, "tag/android-v"),
    );
    const windows = releases.find(
      (item) =>
        /^windows-v\d/.test(item.tag_name) &&
        (releaseAsset(item, "-windows-x64-setup.exe") ||
          releaseAsset(item, "-windows-x64.zip")),
    );
    if (mac) {
      updateLinks(
        "[data-download-dmg]",
        releaseAsset(mac, ".dmg").browser_download_url,
      );
      updateText("[data-latest-version]", mac.tag_name);
      const zip = releaseAsset(mac, ".zip");
      const sums = releaseAsset(mac, "checksums.txt");
      if (zip) updateLinks("[data-download-zip]", zip.browser_download_url);
      if (sums) updateLinks("[data-checksums]", sums.browser_download_url);
    }
    if (android) {
      const apk = releaseAsset(
        android,
        "-android-arm64.apk",
      ).browser_download_url;
      updateLinks("[data-download-apk]", apk);
      updateLinks("[data-download-apk-proxy]", "https://gh-proxy.com/" + apk);
      updateText(
        "[data-android-version]",
        android.tag_name.slice("android-v".length),
      );
      const channel = android.tag_name.includes("-beta.")
        ? "Beta"
        : android.tag_name.includes("-alpha.")
          ? "Alpha"
          : "Release";
      updateText("[data-android-channel]", channel);
      if (trustedReleaseURL(android.html_url, "tag/android-v"))
        updateLinks("[data-android-release]", android.html_url);
      const sums = releaseAsset(android, "checksums.txt");
      if (sums)
        updateLinks("[data-android-checksums]", sums.browser_download_url);
    }
    if (windows) {
      const installer = releaseAsset(windows, "-windows-x64-setup.exe");
      const zip = releaseAsset(windows, "-windows-x64.zip");
      const primary = (installer || zip).browser_download_url;
      updateLinks("[data-download-windows]", primary);
      updateLinks(
        "[data-download-windows-proxy]",
        "https://gh-proxy.com/" + primary,
      );
      if (zip)
        updateLinks("[data-download-windows-zip]", zip.browser_download_url);
      updateText(
        "[data-windows-version]",
        windows.tag_name.slice("windows-v".length),
      );
      if (trustedReleaseURL(windows.html_url, "tag/windows-v"))
        updateLinks("[data-windows-release]", windows.html_url);
      const sums = releaseAsset(windows, "checksums.txt");
      if (sums)
        updateLinks("[data-windows-checksums]", sums.browser_download_url);
    }
  } catch {
    // Static, verified download URLs stay available when GitHub cannot be reached.
  } finally {
    clearTimeout(timeout);
  }
}
void updateReleaseLinks();
