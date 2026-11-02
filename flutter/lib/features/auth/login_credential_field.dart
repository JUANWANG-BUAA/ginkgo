import 'package:flutter/cupertino.dart';

Widget loginCredentialField({
  required BuildContext context,
  required bool busy,
  required bool challengeBusy,
  required bool showPassword,
  required VoidCallback togglePassword,
  required Key key,
  required TextEditingController controller,
  required String placeholder,
  required String label,
  bool obscure = false,
  TextInputAction? textInputAction,
  Iterable<String>? autofillHints,
  ValueChanged<String>? onSubmitted,
}) => Semantics(
  textField: true,
  label: label,
  child: CupertinoTextField(
    key: key,
    controller: controller,
    placeholder: placeholder,
    enabled: !busy && !challengeBusy,
    obscureText: obscure && !showPassword,
    prefix: Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Icon(
        obscure ? CupertinoIcons.lock : CupertinoIcons.person,
        size: 20,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
    suffix: !obscure
        ? null
        : CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            onPressed: busy ? null : togglePassword,
            child: Icon(
              showPassword ? CupertinoIcons.eye_slash : CupertinoIcons.eye,
              size: 20,
              semanticLabel: showPassword ? '隐藏密码' : '显示密码',
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
    enableSuggestions: !obscure,
    autocorrect: false,
    textInputAction: textInputAction,
    autofillHints: autofillHints,
    onSubmitted: onSubmitted,
    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 18),
    decoration: const BoxDecoration(),
  ),
);
