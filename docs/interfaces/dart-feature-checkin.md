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

## features/checkin/checkin_qr_sheet.dart

- `class CheckinQrSheet extends StatefulWidget` — Live classroom QR modal for scanning in 智慧北航 (either from another screen
  <sub>class · features/checkin/checkin_qr_sheet.dart:18</sub>
    - `const CheckinQrSheet({ super.key, required this.course, required this.dateLabel, required this.service, required this.platformActions, required this.isContextValid, required this.onVerifySigned, });`  <sub>:19</sub>
    - `final bool Function() isContextValid;`  <sub>:33</sub>
    - `final Future<bool> Function() onVerifySigned;`  <sub>:34</sub>
    - `State<CheckinQrSheet> createState() => …`  <sub>:37</sub>
- `class CheckinQrPainter extends CustomPainter`
  <sub>class · features/checkin/checkin_qr_sheet.dart:434</sub>
    - `const CheckinQrPainter({required this.matrixSize, required this.modules});`  <sub>:435</sub>
    - `static const int quietZone = 4;`  <sub>:439</sub>
    - `void paint(Canvas canvas, Size size) {…}`  <sub>:442</sub>
    - `bool shouldRepaint(covariant CheckinQrPainter oldDelegate) => …`  <sub>:473</sub>
- `Future<Uint8List> renderCheckinQrPng({ required int matrixSize, required List<bool> modules, }) async {…}` — Rasterizes a crisp black-on-white QR PNG with a standard 4-module quiet zone.
  <sub>function · features/checkin/checkin_qr_sheet.dart:478</sub>

## features/checkin/checkin_widgets.dart

- `class CheckinCourseRow extends StatelessWidget` — One course with its sign-in status, merged-record notes and the classroom
  <sub>class · features/checkin/checkin_widgets.dart:10</sub>
    - `const CheckinCourseRow({ super.key, required this.course, required this.windowOpen, required this.canSubmit, required this.onSubmit, });`  <sub>:11</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:27</sub>
- `class CheckinStatusSummary extends StatelessWidget` — Day totals: count tile, proportional status meter and readable legend.
  <sub>class · features/checkin/checkin_widgets.dart:135</sub>
    - `const CheckinStatusSummary({ super.key, required this.dateLabel, required this.scopeLabel, required this.signed, required this.notSigned, required this.unknown, required this.fetchedAt, });`  <sub>:136</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:152</sub>
