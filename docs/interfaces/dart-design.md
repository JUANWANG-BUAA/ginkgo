# 设计系统（flutter/lib/design）

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

token 层与视觉常量。

## 目录

- [design/academic_widgets.dart](#designacademicwidgetsdart) (4)
- [design/apple_design.dart](#designappledesigndart) (1)
- [design/ginkgo_mark.dart](#designginkgomarkdart) (1)
- [design/ginkgo_visuals.dart](#designginkgovisualsdart) (2)
- [design/tokens/colors.dart](#designtokenscolorsdart) (1)
- [design/tokens/layout.dart](#designtokenslayoutdart) (1)
- [design/tokens/motion.dart](#designtokensmotiondart) (1)
- [design/tokens/radii.dart](#designtokensradiidart) (1)
- [design/tokens/spacing.dart](#designtokensspacingdart) (1)
- [design/tokens/typography.dart](#designtokenstypographydart) (1)

## design/academic_widgets.dart

- `class AcademicBadge extends StatelessWidget` — Quiet semantic labels that wrap with text size; color never carries status  
  <sub>class · design/academic_widgets.dart:11</sub>
    - `const AcademicBadge(this.label, {…}`  <sub>:12</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:18</sub>
- `class AcademicFactRow extends StatelessWidget` — Readable label/value alignment, stacking before large text gets squeezed.  
  <sub>class · design/academic_widgets.dart:52</sub>
    - `const AcademicFactRow( {…}`  <sub>:53</sub>
    - `Widget build(BuildContext context) => Padding( padding: const EdgeInsets.symmetric(hori … ), child: LayoutBuilder( builder: (context, constraints) {…}`  <sub>:58</sub>
- `class AcademicMetric extends StatelessWidget`  
  <sub>class · design/academic_widgets.dart:93</sub>
    - `const AcademicMetric( {…}`  <sub>:94</sub>
    - `Widget build(BuildContext context) => Column( crossAxisAlignment: CrossAxisAlignment.st … tFeatures: const [FontFeature.tabularFigures()], ), ), ], );`  <sub>:103</sub>
- `class AcademicMetricGrid extends StatelessWidget`  
  <sub>class · design/academic_widgets.dart:126</sub>
    - `const AcademicMetricGrid( {…}`  <sub>:127</sub>
    - `Widget build(BuildContext context) => LayoutBuilder( builder: (context, constraints) {…}`  <sub>:135</sub>

## design/apple_design.dart

- `abstract final class AppleDesign` — Product values measured against the repository's iOS 27 reference capture.  
  <sub>class · design/apple_design.dart:14</sub>
    - `static const groupRadius = GinkgoRadii.group;`  <sub>:15</sub>
    - `static const rowHeight = GinkgoLayout.rowHeight;`  <sub>:16</sub>
    - `static const pageInset = GinkgoSpacing.pageInset;`  <sub>:17</sub>
    - `static bool desktop(BuildContext context) => GinkgoLayout.isDesktop(context);`  <sub>:19</sub>
    - `static double panelRadius(BuildContext context) => GinkgoLayout.panelRadius(context);`  <sub>:21</sub>
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
    - `static const title = GinkgoTypography.largeTitle;`  <sub>:40</sub>
    - `static Duration duration(BuildContext context, int milliseconds) => GinkgoMotion.duration(context, milliseconds);`  <sub>:42</sub>

## design/ginkgo_mark.dart

- `class GinkgoMark extends StatelessWidget` — Ginkgo 品牌标记：银杏叶的矢量绘制，与 Android 启动图标、主页 logo 同源。  
  <sub>class · design/ginkgo_mark.dart:9</sub>
    - `const GinkgoMark( {…}`  <sub>:10</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:31</sub>

## design/ginkgo_visuals.dart

- `class GinkgoIconTile extends StatelessWidget` — A rounded tinted base for a single glyph. The glyph follows text scaling  
  <sub>class · design/ginkgo_visuals.dart:5</sub>
    - `const GinkgoIconTile( {…}`  <sub>:6</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:24</sub>
- `class GinkgoBadge extends StatelessWidget` — A compact tinted label. The text always carries the meaning; color is only  
  <sub>class · design/ginkgo_visuals.dart:60</sub>
    - `const GinkgoBadge( {…}`  <sub>:61</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:75</sub>

## design/tokens/colors.dart

- `abstract final class GinkgoColors` — Semantic colors for Ginkgo across light and dark brightness modes.  
  <sub>class · design/tokens/colors.dart:5</sub>
    - `static const accent = CupertinoDynamicColor.withBrightness( color: Color(0xff189840), darkColor: Color(0xff47bd6b), );`  <sub>:7</sub>
    - `static const accentSubtle = CupertinoDynamicColor.withBrightness( color: Color(0x1a189840), darkColor: Color(0x2447bd6b), );`  <sub>:12</sub>
    - `static const windowBackground = CupertinoColors.systemBackground;`  <sub>:18</sub>
    - `static const groupedBackground = CupertinoColors.systemGroupedBackground;`  <sub>:19</sub>
    - `static const secondaryGroupedBackground = CupertinoColors.secondarySystemGroupedBackground;`  <sub>:20</sub>
    - `static const tertiarySystemFill = CupertinoColors.tertiarySystemFill;`  <sub>:22</sub>
    - `static const separator = CupertinoColors.separator;`  <sub>:25</sub>
    - `static const borderLight = CupertinoDynamicColor.withBrightness( color: Color(0x1f000000), darkColor: Color(0x26ffffff), );`  <sub>:26</sub>
    - `static const panelBorder = CupertinoDynamicColor.withBrightness( color: Color(0x403c3c43), darkColor: Color(0x40545458), );`  <sub>:30</sub>
    - `static const label = CupertinoColors.label;`  <sub>:36</sub>
    - `static const secondaryLabel = CupertinoColors.secondaryLabel;`  <sub>:37</sub>
    - `static const tertiaryLabel = CupertinoColors.tertiaryLabel;`  <sub>:38</sub>
    - `static const statusSuccess = CupertinoDynamicColor.withBrightness( color: Color(0xff125a2d), darkColor: Color(0xff72d991), );`  <sub>:42</sub>
    - `static const statusPending = CupertinoDynamicColor.withBrightness( color: Color(0xff713900), darkColor: Color(0xffffbd70), );`  <sub>:47</sub>
    - `static const statusDanger = CupertinoDynamicColor.withBrightness( color: Color(0xff982020), darkColor: Color(0xffffaaa4), );`  <sub>:52</sub>
    - `static const statusUncertain = CupertinoDynamicColor.withBrightness( color: Color(0xff4a4f58), darkColor: Color(0xffc4c8d0), );`  <sub>:57</sub>
    - `static const statusInactive = CupertinoDynamicColor.withBrightness( color: Color(0xff4a4f58), darkColor: Color(0xffc4c8d0), );`  <sub>:62</sub>
    - `static const resourceBlue = CupertinoDynamicColor.withBrightness( color: Color(0xff0066cc), darkColor: Color(0xff69adff), );`  <sub>:68</sub>
    - `static const resourcePurple = CupertinoDynamicColor.withBrightness( color: Color(0xff7446b8), darkColor: Color(0xffcfadff), );`  <sub>:73</sub>
    - `static const resourceTeal = CupertinoDynamicColor.withBrightness( color: Color(0xff08777c), darkColor: Color(0xff66d9df), );`  <sub>:78</sub>
    - `static const connectionOnline = Color(0xff34c759);`  <sub>:83</sub>
    - `static const connectionOffline = CupertinoColors.systemOrange;`  <sub>:84</sub>

## design/tokens/layout.dart

- `abstract final class GinkgoLayout` — Layout breakpoints and structural dimensions.  
  <sub>class · design/tokens/layout.dart:6</sub>
    - `static const double desktopBreakpoint = 760.0;`  <sub>:8</sub>
    - `static const double wideBreakpoint = 1200.0;`  <sub>:9</sub>
    - `static const double desktopSidebarWidth = 248.0;`  <sub>:12</sub>
    - `static const double mobileTabBarHeight = 50.0;`  <sub>:13</sub>
    - `static const double rowHeight = 52.0;`  <sub>:16</sub>
    - `static const double headerIconSize = 44.0;`  <sub>:17</sub>
    - `static const double contentMaxWidth = 900.0;`  <sub>:18</sub>
    - `static const double todayContentMaxWidth = 820.0;`  <sub>:19</sub>
    - `static const double formMaxWidth = 420.0;`  <sub>:20</sub>
    - `static bool isDesktop(BuildContext context) => MediaQuery.sizeOf(context).width >= desktopBreakpoint;`  <sub>:23</sub>
    - `static double panelRadius(BuildContext context) => isDesktop(context) ? GinkgoRadii.panel : GinkgoRadii.group;`  <sub>:26</sub>

## design/tokens/motion.dart

- `abstract final class GinkgoMotion` — Motion tokens respecting system accessibility reduce-motion settings.  
  <sub>class · design/tokens/motion.dart:4</sub>
    - `static const fast = Duration(milliseconds: 140);`  <sub>:5</sub>
    - `static const normal = Duration(milliseconds: 180);`  <sub>:6</sub>
    - `static const deliberate = Duration(milliseconds: 260);`  <sub>:7</sub>
    - `static const curveFast = Curves.easeOut;`  <sub>:9</sub>
    - `static const curveNormal = Curves.easeInOut;`  <sub>:10</sub>
    - `static const curveSnappy = Curves.easeOutCubic;`  <sub>:11</sub>
    - `static Duration duration(BuildContext context, int milliseconds) => MediaQuery.disableAnimationsOf(context)`  <sub>:13</sub>

## design/tokens/radii.dart

- `abstract final class GinkgoRadii` — Corner radius tokens using continuous Apple superellipse curves.  
  <sub>class · design/tokens/radii.dart:4</sub>
    - `static const double pill = 2.0;`  <sub>:5</sub>
    - `static const double badge = 7.0;`  <sub>:6</sub>
    - `static const double button = 8.0;`  <sub>:7</sub>
    - `static const double navigationItem = 10.0;`  <sub>:8</sub>
    - `static const double panel = 12.0;`  <sub>:9</sub>
    - `static const double dialog = 18.0;`  <sub>:10</sub>
    - `static const double group = 26.0;`  <sub>:11</sub>
    - `static final borderRadiusPill = BorderRadius.circular(pill);`  <sub>:13</sub>
    - `static final borderRadiusBadge = BorderRadius.circular(badge);`  <sub>:14</sub>
    - `static final borderRadiusButton = BorderRadius.circular(button);`  <sub>:15</sub>
    - `static final borderRadiusNavigationItem = BorderRadius.circular( navigationItem, );`  <sub>:16</sub>
    - `static final borderRadiusPanel = BorderRadius.circular(panel);`  <sub>:19</sub>
    - `static final borderRadiusDialog = BorderRadius.circular(dialog);`  <sub>:20</sub>
    - `static final borderRadiusGroup = BorderRadius.circular(group);`  <sub>:21</sub>

## design/tokens/spacing.dart

- `abstract final class GinkgoSpacing` — 4pt / 8pt spatial layout scale matching Apple Human Interface Guidelines.  
  <sub>class · design/tokens/spacing.dart:4</sub>
    - `static const double xxs = 2.0;`  <sub>:5</sub>
    - `static const double xs = 4.0;`  <sub>:6</sub>
    - `static const double sm = 8.0;`  <sub>:7</sub>
    - `static const double md = 12.0;`  <sub>:8</sub>
    - `static const double base = 16.0;`  <sub>:9</sub>
    - `static const double lg = 20.0;`  <sub>:10</sub>
    - `static const double xl = 24.0;`  <sub>:11</sub>
    - `static const double xxl = 32.0;`  <sub>:12</sub>
    - `static const double xxxl = 48.0;`  <sub>:13</sub>
    - `static const pageInset = 16.0;`  <sub>:16</sub>
    - `static const desktopPageInset = 24.0;`  <sub>:17</sub>
    - `static const edgeInsetsPage = EdgeInsets.symmetric(horizontal: pageInset);`  <sub>:19</sub>
    - `static const edgeInsetsDesktopPage = EdgeInsets.fromLTRB( desktopPageInset, 22, desktopPageInset, 6, );`  <sub>:20</sub>
    - `static const edgeInsetsCard = EdgeInsets.all(base);`  <sub>:26</sub>
    - `static const edgeInsetsListTile = EdgeInsets.symmetric( horizontal: base, vertical: 10, );`  <sub>:27</sub>
    - `static const edgeInsetsListTileCompact = EdgeInsets.symmetric( horizontal: base, vertical: 6, );`  <sub>:31</sub>
    - `static const edgeInsetsSidebarItem = EdgeInsets.symmetric( horizontal: 4, vertical: 2, );`  <sub>:35</sub>
    - `static const edgeInsetsSidebarItemInner = EdgeInsets.symmetric( horizontal: 11, vertical: 8, );`  <sub>:39</sub>

## design/tokens/typography.dart

- `abstract final class GinkgoTypography` — Semantic typography scale matching Apple Human Interface Guidelines.  
  <sub>class · design/tokens/typography.dart:6</sub>
    - `static const font = 'Ginkgo Sans';`  <sub>:7</sub>
    - `static const fallback = ['Ginkgo Han'];`  <sub>:8</sub>
    - `static const largeTitle = TextStyle( inherit: false, fontFamily: font, fontFamilyFallba … ght.w700, letterSpacing: -0.8, color: GinkgoColors.label, );`  <sub>:10</sub>
    - `static const title = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: f … ght.w600, letterSpacing: -0.5, color: GinkgoColors.label, );`  <sub>:20</sub>
    - `static const title2 = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: … ght.w600, letterSpacing: -0.3, color: GinkgoColors.label, );`  <sub>:30</sub>
    - `static const headline = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback … ght.w600, letterSpacing: -0.4, color: GinkgoColors.label, );`  <sub>:40</sub>
    - `static const body = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: fa … ize: 17, letterSpacing: -0.25, color: GinkgoColors.label, );`  <sub>:50</sub>
    - `static const subheadline = TextStyle( inherit: false, fontFamily: font, fontFamilyFallb … ize: 14, letterSpacing: -0.15, color: GinkgoColors.label, );`  <sub>:59</sub>
    - `static const footnote = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback … letterSpacing: -0.08, color: GinkgoColors.secondaryLabel, );`  <sub>:68</sub>
    - `static const caption = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback: … , letterSpacing: 0.0, color: GinkgoColors.secondaryLabel, );`  <sub>:77</sub>
    - `static const caption2 = TextStyle( inherit: false, fontFamily: font, fontFamilyFallback … , letterSpacing: 0.06, color: GinkgoColors.tertiaryLabel, );`  <sub>:86</sub>
    - `static const tabularDigits = [FontFeature.tabularFigures()];`  <sub>:95</sub>
