# Flutter 功能域：learning

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/learning/` 的页面、域内组件与模型。

## features/learning/learning_announcement_page.dart

- `class LearningAnnouncementPage extends StatefulWidget`
  <sub>class · features/learning/learning_announcement_page.dart:12</sub>
    - `const LearningAnnouncementPage({ super.key, required this.service, required this.course, required this.announcement, required this.isCurrent, this.column, this.saveFile, });`  <sub>:13</sub>
    - `final bool Function() isCurrent;`  <sub>:26</sub>
    - `State<LearningAnnouncementPage> createState() => …`  <sub>:29</sub>
- `class LearningAnnouncementPageState extends State<LearningAnnouncementPage>`
  <sub>class · features/learning/learning_announcement_page.dart:33</sub>
    - `final detail = RefreshSection<CourseAnnouncementDetail>();`  <sub>:34</sub>
    - `void initState() {…}`  <sub>:36</sub>
    - `void dispose() {…}`  <sub>:82</sub>
    - `Widget build(BuildContext context) => …`  <sub>:88</sub>

## features/learning/learning_cards.dart

- `Color learningCourseAccent(String seed) {…}` — Deterministic accent palette for SPOC courses so each course keeps a stable
  <sub>function · features/learning/learning_cards.dart:12</sub>
- `class LearningCourseCard extends StatelessWidget` — Tactile course card on the SPOC Learning root list.
  <sub>class · features/learning/learning_cards.dart:35</sub>
    - `const LearningCourseCard({ super.key, required this.course, required this.onTap, });`  <sub>:36</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:48</sub>
- `class LearningCourseHeroCard extends StatelessWidget` — Identity hero banner at the top of LearningCoursePage.
  <sub>class · features/learning/learning_cards.dart:127</sub>
    - `const LearningCourseHeroCard({ super.key, required this.course, this.onOpenSource, });`  <sub>:128</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:142</sub>
- `class LearningAnnouncementCard extends StatelessWidget` — Announcement row card inside a SPOC course.
  <sub>class · features/learning/learning_cards.dart:269</sub>
    - `const LearningAnnouncementCard({ super.key, required this.announcement, required this.onTap, });`  <sub>:270</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:283</sub>
- `class LearningAssessmentCard extends StatelessWidget` — Read-only assessment card with color-coded metadata pills.
  <sub>class · features/learning/learning_cards.dart:336</sub>
    - `const LearningAssessmentCard({ super.key, required this.item, required this.fallbackSummary, });`  <sub>:337</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:349</sub>

## features/learning/learning_course_page.dart

- `enum LearningCourseTab { resources, announcements, assessments }`
  <sub>enum · features/learning/learning_course_page.dart:17</sub>
- `class LearningCoursePage extends StatefulWidget`
  <sub>class · features/learning/learning_course_page.dart:19</sub>
    - `const LearningCoursePage({ super.key, required this.course, required this.service, this.accountId, required this.saveFile, this.isOwnerCurrent, });`  <sub>:20</sub>
    - `final bool Function()? isOwnerCurrent;`  <sub>:32</sub>
    - `State<LearningCoursePage> createState() => …`  <sub>:34</sub>

## features/learning/learning_page.dart

- `class LearningPage extends StatefulWidget`
  <sub>class · features/learning/learning_page.dart:15</sub>
    - `const LearningPage({ super.key, required this.service, this.accountId, required this.fileActions, });`  <sub>:16</sub>
    - `State<LearningPage> createState() => …`  <sub>:28</sub>

## features/learning/learning_resource_section.dart

- `class LearningResourceSection extends StatelessWidget` — 课程资料的目录浏览区：面包屑、当前页筛选、条目列表与分页。
  <sub>class · features/learning/learning_resource_section.dart:76</sub>
    - `const LearningResourceSection({ super.key, required this.path, required this.page, required this.items, required this.resourceQuery, required this.resources, required this.supported, required this.hasContext, required this.saveFile, required this.contextToken, required this.onQueryChanged, required this.onNavigate, required this.onRefresh, required this.onDownload, required this.isCurrent, });`  <sub>:77</sub>
    - `final void Function(List<CourseResource> nextPath, int nextPage) onNavigate;`  <sub>:105</sub>
    - `final Future<LearningDownload> Function(CourseResource item) onDownload;`  <sub>:107</sub>
    - `final bool Function() isCurrent;`  <sub>:108</sub>
    - `Widget build(BuildContext context) => …`  <sub>:111</sub>

## features/learning/learning_snapshots_page.dart

- `class LearningSnapshotsPage extends StatefulWidget`
  <sub>class · features/learning/learning_snapshots_page.dart:7</sub>
    - `const LearningSnapshotsPage({super.key, required this.gateway});`  <sub>:8</sub>
    - `State<LearningSnapshotsPage> createState() => …`  <sub>:11</sub>

## features/learning/learning_widgets.dart

- `class LearningFileButton extends StatefulWidget`
  <sub>class · features/learning/learning_widgets.dart:11</sub>
    - `const LearningFileButton({ super.key, required this.download, required this.saveFile, required this.isCurrent, required this.contextToken, });`  <sub>:12</sub>
    - `final Future<LearningDownload> Function() download;`  <sub>:19</sub>
    - `final bool Function() isCurrent;`  <sub>:21</sub>
    - `State<LearningFileButton> createState() => …`  <sub>:24</sub>
- `class LearningFileButtonState extends State<LearningFileButton>`
  <sub>class · features/learning/learning_widgets.dart:27</sub>
    - `bool busy = false;`  <sub>:28</sub>
    - `int epoch = 0;`  <sub>:31</sub>
    - `bool current(int e) => …`  <sub>:32</sub>
    - `void didUpdateWidget(covariant LearningFileButton oldWidget) {…}`  <sub>:38</sub>
    - `Future<void> save() async {…}`  <sub>:48</sub>
    - `Future<void> open() async {…}`  <sub>:78</sub>
    - `void dispose() {…}`  <sub>:89</sub>
    - `Widget build(BuildContext context) => …`  <sub>:95</sub>
- `class LearningReadStatus<T> extends StatelessWidget`
  <sub>class · features/learning/learning_widgets.dart:112</sub>
    - `const LearningReadStatus({ super.key, required this.title, required this.section, required this.supported, required this.onRefresh, });`  <sub>:113</sub>
    - `Widget build(BuildContext context) => …`  <sub>:125</sub>
- `class LearningText extends StatelessWidget`
  <sub>class · features/learning/learning_widgets.dart:146</sub>
    - `const LearningText( this.text, { super.key, this.heading = false, this.warning = false, });`  <sub>:147</sub>
    - `Widget build(BuildContext context) => …`  <sub>:156</sub>
- `bool presentText(String? value) => …`
  <sub>function · features/learning/learning_widgets.dart:172</sub>
- `Uri? httpsUri(String source) {…}`
  <sub>function · features/learning/learning_widgets.dart:173</sub>
