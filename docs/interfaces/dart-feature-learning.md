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

## features/learning/learning_course_page.dart

- `enum LearningCourseTab { resources, announcements, assessments }`
  <sub>enum · features/learning/learning_course_page.dart:16</sub>
- `class LearningCoursePage extends StatefulWidget`
  <sub>class · features/learning/learning_course_page.dart:18</sub>
    - `const LearningCoursePage({ super.key, required this.course, required this.service, this.accountId, required this.saveFile, this.isOwnerCurrent, });`  <sub>:19</sub>
    - `final bool Function()? isOwnerCurrent;`  <sub>:31</sub>
    - `State<LearningCoursePage> createState() => …`  <sub>:33</sub>

## features/learning/learning_page.dart

- `class LearningPage extends StatefulWidget`
  <sub>class · features/learning/learning_page.dart:14</sub>
    - `const LearningPage({ super.key, required this.service, this.accountId, required this.fileActions, });`  <sub>:15</sub>
    - `State<LearningPage> createState() => …`  <sub>:26</sub>

## features/learning/learning_resource_section.dart

- `class LearningResourceSection extends StatelessWidget` — 课程资料的目录浏览区：面包屑、当前页筛选、条目列表与分页。
  <sub>class · features/learning/learning_resource_section.dart:14</sub>
    - `const LearningResourceSection({ super.key, required this.path, required this.page, required this.items, required this.resourceQuery, required this.resources, required this.supported, required this.hasContext, required this.saveFile, required this.contextToken, required this.onQueryChanged, required this.onNavigate, required this.onRefresh, required this.onDownload, required this.isCurrent, });`  <sub>:15</sub>
    - `final void Function(List<CourseResource> nextPath, int nextPage) onNavigate;`  <sub>:43</sub>
    - `final Future<LearningDownload> Function(CourseResource item) onDownload;`  <sub>:45</sub>
    - `final bool Function() isCurrent;`  <sub>:46</sub>
    - `Widget build(BuildContext context) => …`  <sub>:49</sub>

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
  <sub>class · features/learning/learning_widgets.dart:156</sub>
    - `const LearningText( this.text, { super.key, this.heading = false, this.warning = false, });`  <sub>:157</sub>
    - `Widget build(BuildContext context) => …`  <sub>:166</sub>
- `bool presentText(String? value) => …`
  <sub>function · features/learning/learning_widgets.dart:182</sub>
- `Uri? httpsUri(String source) {…}`
  <sub>function · features/learning/learning_widgets.dart:183</sub>
