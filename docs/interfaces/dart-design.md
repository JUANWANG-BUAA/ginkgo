# 设计系统（flutter/lib/design）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
token 层与视觉常量。

## design/apple_design.dart

- `abstract final class AppleDesign` — Product values measured against the repository's iOS 27 reference capture.
  <sub>class · design/apple_design.dart:14</sub>
    - `static const groupRadius = GinkgoRadii.group;`  <sub>:15</sub>
    - `static const rowHeight = GinkgoLayout.rowHeight;`  <sub>:16</sub>
    - `static const pageInset = GinkgoSpacing.pageInset;`  <sub>:17</sub>
    - `static bool desktop(BuildContext context) => …`  <sub>:19</sub>
    - `static double panelRadius(BuildContext context) => …`  <sub>:21</sub>
    - `static const accent = GinkgoColors.accent;`  <sub>:24</sub>
    - `static const resourceBlue = GinkgoColors.resourceBlue;`  <sub>:25</sub>
    - `static const resourcePurple = GinkgoColors.resourcePurple;`  <sub>:26</sub>
    - `static const resourceTeal = GinkgoColors.resourceTeal;`  <sub>:27</sub>
    - `static const statusSuccess = GinkgoColors.statusSuccess;`  <sub>:31</sub>
    - `static const statusPending = GinkgoColors.statusPending;`  <sub>:32</sub>
    - `static const statusUncertain = GinkgoColors.statusUncertain;`  <sub>:33</sub>
    - `static const statusDanger = GinkgoColors.statusDanger;`  <sub>:34</sub>
    - `static const statusInactive = GinkgoColors.statusInactive;`  <sub>:35</sub>
    - `static const font = GinkgoTypography.font;`  <sub>:37</sub>
    - `static const fallback = GinkgoTypography.fallback;`  <sub>:38</sub>
    - `static const body = GinkgoTypography.body;`  <sub>:39</sub>
    - `static const bodyCondensedSize = GinkgoTypography.bodyCondensedSize;`  <sub>:40</sub>
    - `static const calloutSize = GinkgoTypography.calloutSize;`  <sub>:41</sub>
    - `static const bodyCondensed = GinkgoTypography.bodyCondensed;`  <sub>:42</sub>
    - `static const callout = GinkgoTypography.callout;`  <sub>:43</sub>
    - `static const subheadline = GinkgoTypography.subheadline;`  <sub>:44</sub>
    - `static const footnote = GinkgoTypography.footnote;`  <sub>:45</sub>
    - `static const caption = GinkgoTypography.caption;`  <sub>:46</sub>
    - `static const caption2 = GinkgoTypography.caption2;`  <sub>:47</sub>
    - `static const largeTitle = GinkgoTypography.largeTitle;`  <sub>:50</sub>
    - `static const title = GinkgoTypography.title;`  <sub>:51</sub>
    - `static const title2 = GinkgoTypography.title2;`  <sub>:52</sub>
    - `static const headline = GinkgoTypography.headline;`  <sub>:53</sub>
    - `static Duration duration(BuildContext context, int milliseconds) => …`  <sub>:55</sub>

## design/ginkgo_theme.dart

- `CupertinoThemeData ginkgoTheme([ Brightness? brightness, Color accent = GinkgoColors.accent, ]) => …`
  <sub>function · design/ginkgo_theme.dart:18</sub>

## design/tokens/colors.dart

- `abstract final class GinkgoColors` — Semantic colors for Ginkgo across light and dark brightness modes.
  <sub>class · design/tokens/colors.dart:5</sub>
    - `static const accent = CupertinoDynamicColor.withBrightness( color: Color(0xff189840), darkColor: Color(0xff47bd6b), );`  <sub>:7</sub>
    - `static const accentSubtle = CupertinoDynamicColor.withBrightness( color: Color(0x1a189840), darkColor: Color(0x2447bd6b), );`  <sub>:12</sub>
    - `static const secondaryGroupedBackground = CupertinoColors.secondarySystemGroupedBackground;`  <sub>:18</sub>
    - `static const tertiarySystemFill = CupertinoColors.tertiarySystemFill;`  <sub>:20</sub>
    - `static const separator = CupertinoColors.separator;`  <sub>:23</sub>
    - `static const label = CupertinoColors.label;`  <sub>:26</sub>
    - `static const secondaryLabel = CupertinoColors.secondaryLabel;`  <sub>:27</sub>
    - `static const tertiaryLabel = CupertinoColors.tertiaryLabel;`  <sub>:28</sub>
    - `static const statusSuccess = CupertinoDynamicColor.withBrightness( color: Color(0xff125a2d), darkColor: Color(0xff72d991), );`  <sub>:32</sub>
    - `static const statusPending = CupertinoDynamicColor.withBrightness( color: Color(0xff713900), darkColor: Color(0xffffbd70), );`  <sub>:37</sub>
    - `static const statusDanger = CupertinoDynamicColor.withBrightness( color: Color(0xff982020), darkColor: Color(0xffffaaa4), );`  <sub>:42</sub>
    - `static const statusUncertain = CupertinoDynamicColor.withBrightness( color: Color(0xff4a4f58), darkColor: Color(0xffc4c8d0), );`  <sub>:47</sub>
    - `static const statusInactive = statusUncertain;`  <sub>:52</sub>
    - `static const resourceBlue = CupertinoDynamicColor.withBrightness( color: Color(0xff0066cc), darkColor: Color(0xff69adff), );`  <sub>:55</sub>
    - `static const resourcePurple = CupertinoDynamicColor.withBrightness( color: Color(0xff7446b8), darkColor: Color(0xffcfadff), );`  <sub>:60</sub>
    - `static const resourceTeal = CupertinoDynamicColor.withBrightness( color: Color(0xff08777c), darkColor: Color(0xff66d9df), );`  <sub>:65</sub>
    - `static const connectionOnline = Color(0xff34c759);`  <sub>:70</sub>
    - `static const connectionOffline = CupertinoColors.systemOrange;`  <sub>:71</sub>

## design/tokens/layout.dart

- `abstract final class GinkgoLayout` — Layout breakpoints and structural dimensions.
  <sub>class · design/tokens/layout.dart:6</sub>
    - `static const double desktopBreakpoint = 760.0;`  <sub>:8</sub>
    - `static const double desktopSidebarWidth = 248.0;`  <sub>:11</sub>
    - `static const double rowHeight = 52.0;`  <sub>:14</sub>
    - `static const double formMaxWidth = 420.0;`  <sub>:15</sub>
    - `static bool isDesktop(BuildContext context) => …`  <sub>:18</sub>
    - `static double panelRadius(BuildContext context) => …`  <sub>:21</sub>

## design/tokens/motion.dart

- `abstract final class GinkgoMotion` — Motion tokens respecting system accessibility reduce-motion settings.
  <sub>class · design/tokens/motion.dart:4</sub>
    - `static const normal = Duration(milliseconds: 180);`  <sub>:5</sub>
    - `static Duration duration(BuildContext context, int milliseconds) => …`  <sub>:7</sub>

## design/tokens/radii.dart

- `abstract final class GinkgoRadii` — Corner radius tokens using continuous Apple superellipse curves.
  <sub>class · design/tokens/radii.dart:4</sub>
    - `static const double badge = 7.0;`  <sub>:5</sub>
    - `static const double button = 8.0;`  <sub>:6</sub>
    - `static const double compact = 10.0;`  <sub>:7</sub>
    - `static const double panel = 12.0;`  <sub>:8</sub>
    - `static const double dialog = 18.0;`  <sub>:9</sub>
    - `static const double group = 26.0;`  <sub>:10</sub>
    - `static final borderRadiusDialog = BorderRadius.circular(dialog);`  <sub>:12</sub>

## design/tokens/spacing.dart

- `abstract final class GinkgoSpacing` — 4pt / 8pt spatial layout scale matching Apple Human Interface Guidelines.
  <sub>class · design/tokens/spacing.dart:4</sub>
    - `static const double md = 12.0;`  <sub>:5</sub>
    - `static const double base = 16.0;`  <sub>:6</sub>
    - `static const double xl = 24.0;`  <sub>:7</sub>
    - `static const double xxl = 32.0;`  <sub>:8</sub>
    - `static const pageInset = 16.0;`  <sub>:11</sub>
    - `static const desktopPageInset = 24.0;`  <sub>:12</sub>
    - `static const edgeInsetsPage = EdgeInsets.symmetric(horizontal: pageInset);`  <sub>:14</sub>
    - `static const edgeInsetsDesktopPage = EdgeInsets.fromLTRB( desktopPageInset, 22, desktopPageInset, 6, );`  <sub>:15</sub>
    - `static const edgeInsetsCard = EdgeInsets.all(base);`  <sub>:21</sub>
    - `static const edgeInsetsListTile = EdgeInsets.symmetric( horizontal: base, vertical: 10, );`  <sub>:22</sub>
    - `static const edgeInsetsBadge = EdgeInsets.symmetric( horizontal: 8, vertical: 5, );`  <sub>:26</sub>
    - `static const edgeInsetsFact = EdgeInsets.symmetric( horizontal: 16, vertical: 13, );`  <sub>:30</sub>
    - `static const double xs = 4.0;`  <sub>:35</sub>
    - `static const double compact = 5.0;`  <sub>:36</sub>
    - `static const double small = 6.0;`  <sub>:37</sub>
    - `static const double factLabelWidth = 124.0;`  <sub>:38</sub>
    - `static const double metricColumnWidth = 108.0;`  <sub>:39</sub>
    - `static const double metricGridSpacing = 18.0;`  <sub>:40</sub>
    - `static EdgeInsets badgeInsets({ required bool compact, required bool largeText, }) => …`  <sub>:42</sub>

## design/tokens/typography.dart

- `abstract final class GinkgoTypography` — Semantic typography scale matching Apple Human Interface Guidelines.
  <sub>class · design/tokens/typography.dart:6</sub>
    - `static const font = 'Ginkgo Sans';`  <sub>:7</sub>
    - `static const fallback = ['Ginkgo Han'];`  <sub>:8</sub>
    - `static const largeTitle = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: fallback, fontSize: 34, fontWeight: FontWeight.w700, letterSpacing: -0.8, color: GinkgoColors.label, );`  <sub>:10</sub>
    - `static const title = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: fallback, fontSize: 26, fontWeight: FontWeight.w600, letterSpacing: -0.5, color: GinkgoColors.label, );`  <sub>:20</sub>
    - `static const title2 = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: fallback, fontSize: 22, fontWeight: FontWeight.w600, letterSpacing: -0.3, color: GinkgoColors.label, );`  <sub>:30</sub>
    - `static const headline = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: fallback, fontSize: 17, fontWeight: FontWeight.w600, letterSpacing: -0.4, color: GinkgoColors.label, );`  <sub>:40</sub>
    - `static const body = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: fallback, fontSize: 17, letterSpacing: -0.25, color: GinkgoColors.label, );`  <sub>:50</sub>
    - `static const bodyCondensedSize = 16.0;`  <sub>:59</sub>
    - `static const calloutSize = 15.0;`  <sub>:60</sub>
    - `static const metricSize = 24.0;`  <sub>:61</sub>
    - `static const metricProminentSize = 32.0;`  <sub>:62</sub>
    - `static const bodyCondensed = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: fallback, fontSize: bodyCondensedSize, letterSpacing: -0.2, color: GinkgoColors.label, );` — Dense rows and sidebars. 16 and 15 are the two most used sizes in the  <sub>:67</sub>
    - `static const callout = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: fallback, fontSize: calloutSize, letterSpacing: -0.18, color: GinkgoColors.label, );`  <sub>:76</sub>
    - `static const subheadline = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: fallback, fontSize: 14, letterSpacing: -0.15, color: GinkgoColors.label, );`  <sub>:85</sub>
    - `static const footnote = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: fallback, fontSize: 13, letterSpacing: -0.08, color: GinkgoColors.secondaryLabel, );`  <sub>:94</sub>
    - `static const caption = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: fallback, fontSize: 12, letterSpacing: 0.0, color: GinkgoColors.secondaryLabel, );`  <sub>:103</sub>
    - `static const caption2 = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: fallback, fontSize: 11, letterSpacing: 0.06, color: GinkgoColors.tertiaryLabel, );`  <sub>:112</sub>
    - `static const tabularDigits = [FontFeature.tabularFigures()];`  <sub>:121</sub>
