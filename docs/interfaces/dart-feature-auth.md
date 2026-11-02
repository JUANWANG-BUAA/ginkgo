# Flutter 功能域：auth

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。
`flutter/lib/features/auth/` 的页面、域内组件与模型。

## features/auth/login_credential_field.dart

- `Widget loginCredentialField({ required BuildContext context, required bool busy, required bool challengeBusy, required bool showPassword, required VoidCallback togglePassword, required Key key, required TextEditingController controller, required String placeholder, required String label, bool obscure = false, TextInputAction? textInputAction, Iterable<String>? autofillHints, ValueChanged<String>? onSubmitted, }) => …`
  <sub>function · features/auth/login_credential_field.dart:3</sub>

## features/auth/login_feedback.dart

- `class LoginFeedback extends StatelessWidget`
  <sub>class · features/auth/login_feedback.dart:6</sub>
    - `const LoginFeedback({super.key, required this.message});`  <sub>:7</sub>
    - `Widget build(BuildContext context) => …`  <sub>:11</sub>
- `class LoginNetworkNote extends StatelessWidget`
  <sub>class · features/auth/login_feedback.dart:38</sub>
    - `const LoginNetworkNote({super.key});`  <sub>:39</sub>
    - `Widget build(BuildContext context) => …`  <sub>:41</sub>

## features/auth/login_page.dart

- `class LoginPage extends StatefulWidget`
  <sub>class · features/auth/login_page.dart:19</sub>
    - `const LoginPage({ super.key, required this.service, required this.onSignedIn, required this.onDemo, this.initialMessage, this.initialCaptcha = false, this.challengeGateway, });`  <sub>:20</sub>
    - `State<LoginPage> createState() => …`  <sub>:38</sub>

## features/auth/login_retry_pause.dart

- `class LoginRetryPause` — Local pacing after explicit password rejection; network/captcha errors do
  <sub>class · features/auth/login_retry_pause.dart:7</sub>
    - `final void Function() onTick;`  <sub>:9</sub>
    - `int rejected = 0;`  <sub>:10</sub>
    - `int remaining = 0;`  <sub>:11</sub>
    - `String get message => …`  <sub>:13</sub>
    - `bool record(FailureCode? failure) {…}`  <sub>:16</sub>
    - `void dispose() => …`  <sub>:34</sub>

## features/auth/login_route_selector.dart

- `class LoginRouteSelector extends StatelessWidget` — Persistent network-route choice shown on the login page.
  <sub>class · features/auth/login_route_selector.dart:8</sub>
    - `const LoginRouteSelector({ super.key, required this.route, required this.onChanged, });`  <sub>:9</sub>
    - `Widget build(BuildContext context) {…}`  <sub>:19</sub>
