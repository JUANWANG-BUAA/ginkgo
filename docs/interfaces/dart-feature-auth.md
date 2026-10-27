# Flutter 功能域：auth

> 本文件由 `scripts/generate-interface-index.py` 从源码生成，请勿手工编辑。
> 修改接口后运行 `python3 scripts/generate-interface-index.py` 重新生成；
> 手工总览与分层说明见 [INTERFACE-INDEX.md](../INTERFACE-INDEX.md)。

`flutter/lib/features/auth/` 的页面、域内组件与模型。

## LoginPage (class)

- `class LoginPage extends StatefulWidget {`  
  <sub>features/auth/login_page.dart:10</sub>
    - `const LoginPage({ super.key, required this.service, required this.onSignedIn, required this.onDemo, this.initialMessage, this.initialCaptcha = false,…`  <sub>:11</sub>
    - `State<LoginPage> createState() => _LoginPageState();`  <sub>:29</sub>
