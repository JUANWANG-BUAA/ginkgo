# Flutter 功能域：checkin

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/checkin/` 的页面、域内组件与模型。

## features/checkin/checkin_loading.dart

- `class CheckInLoading extends StatefulWidget` — Polls local progress only; never sends another authentication/read request.
  <sub>class · features/checkin/checkin_loading.dart:10</sub>
    - `const CheckInLoading({ super.key, required this.isDemo, required this.service, });`  <sub>:11</sub>
    - `State<CheckInLoading> createState() => …`  <sub>:19</sub>

## features/checkin/checkin_page.dart

- `class CheckInPage extends StatefulWidget` — Per-course classroom QR generation with智慧北航 scan guidance and status readback.
  <sub>class · features/checkin/checkin_page.dart:24</sub>
    - `const CheckInPage({ super.key, required this.service, this.platformActions = const PlatformActions(), this.history = false, this.clock, });`  <sub>:25</sub>
    - `final DateTime Function()? clock;`  <sub>:35</sub>
    - `State<CheckInPage> createState() => …`  <sub>:37</sub>

## features/checkin/checkin_qr_render.dart

- `class CheckinQrPainter extends CustomPainter` — Paints a black-on-white ISO 18004 QR matrix with a standard 4-module quiet zone.
  <sub>class · features/checkin/checkin_qr_render.dart:13</sub>
    - `const CheckinQrPainter({required this.matrixSize, required this.modules});`  <sub>:14</sub>
    - `static const int quietZone = 4;`  <sub>:18</sub>
    - `void paint(Canvas canvas, Size size) {…}`  <sub>:21</sub>
    - `bool shouldRepaint(covariant CheckinQrPainter oldDelegate) => …`  <sub>:52</sub>
- `Future<Uint8List> renderCheckinQrPng({ required int matrixSize, required List<bool> modules, }) async {…}` — Rasterizes a crisp black-on-white QR PNG with a standard 4-module quiet zone.
  <sub>function · features/checkin/checkin_qr_render.dart:57</sub>
- `class CheckinQrQuickHelperBanner extends StatelessWidget`
  <sub>class · features/checkin/checkin_qr_render.dart:85</sub>
    - `const CheckinQrQuickHelperBanner({ super.key, required this.status, required this.secondary, });`  <sub>:86</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:96</sub>
- `class CheckinQrConfirmedView extends StatelessWidget`
  <sub>class · features/checkin/checkin_qr_render.dart:135</sub>
    - `const CheckinQrConfirmedView({super.key});`  <sub>:136</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:139</sub>
- `class CheckinQrDisplayCard extends StatelessWidget`
  <sub>class · features/checkin/checkin_qr_render.dart:160</sub>
    - `const CheckinQrDisplayCard({ super.key, required this.courseName, required this.ticket, required this.loadingQr, required this.isDemo, required this.issue, required this.secondary, required this.onRetry, });`  <sub>:161</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:181</sub>

## features/checkin/checkin_qr_sheet.dart

- `class CheckinQrSheet extends StatefulWidget` — Live classroom QR modal for scanning in 智慧北航 (either from another screen,
  <sub>class · features/checkin/checkin_qr_sheet.dart:20</sub>
    - `const CheckinQrSheet({ super.key, required this.course, required this.dateLabel, required this.service, required this.platformActions, required this.isContextValid, required this.onVerifySigned, });`  <sub>:21</sub>
    - `final bool Function() isContextValid;`  <sub>:35</sub>
    - `final Future<bool> Function() onVerifySigned;`  <sub>:36</sub>
    - `State<CheckinQrSheet> createState() => …`  <sub>:39</sub>

## features/checkin/checkin_widgets.dart

- `class CheckinCourseRow extends StatelessWidget` — One course with its sign-in status, merged-record notes and the classroom
  <sub>class · features/checkin/checkin_widgets.dart:10</sub>
    - `const CheckinCourseRow({ super.key, required this.course, required this.windowOpen, required this.canSubmit, required this.onSubmit, });`  <sub>:11</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:27</sub>
- `class CheckinStatusSummary extends StatelessWidget` — Day totals: count tile, proportional status meter and readable legend.
  <sub>class · features/checkin/checkin_widgets.dart:135</sub>
    - `const CheckinStatusSummary({ super.key, required this.dateLabel, required this.scopeLabel, required this.signed, required this.notSigned, required this.unknown, required this.fetchedAt, });`  <sub>:136</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:152</sub>
