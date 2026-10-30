# Flutter 功能域：reservations

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/reservations/` 的页面、域内组件与模型。

## features/reservations/reservation_widgets.dart

- `class ReservationActionButton extends StatefulWidget` — The shared reservation action control, aligned with native button styles:
  <sub>class · features/reservations/reservation_widgets.dart:11</sub>
    - `const ReservationActionButton({ super.key, this.buttonKey, required this.label, required this.icon, required this.onPressed, this.tint, this.primary = false, this.busy = false, this.compact = false, });`  <sub>:12</sub>
    - `State<ReservationActionButton> createState() => …`  <sub>:30</sub>

## features/reservations/reservations_page.dart

- `class ReservationsPage extends StatelessWidget` — Resource hub does not start all service logins in the background.
  <sub>class · features/reservations/reservations_page.dart:11</sub>
    - `const ReservationsPage({ super.key, required this.service, this.bookingGateway, });`  <sub>:12</sub>
    - `void open(BuildContext context, Widget page) => …`  <sub>:20</sub>
    - `Widget build(BuildContext context) => …`  <sub>:25</sub>
