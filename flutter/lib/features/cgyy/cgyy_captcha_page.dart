import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/widgets/apple_widgets.dart';
import 'package:ginkgo_mirror/features/cgyy/cgyy_models.dart';
import 'package:ginkgo_mirror/widgets/loading_widgets.dart';
import 'package:ginkgo_mirror/application/mirror_service.dart';

/// School jigsaw verification. The drag is performed manually by the user;
/// leaving never submits, and an unknown result keeps local protection on.
class CgyyCaptchaPage extends StatefulWidget {
  const CgyyCaptchaPage({
    super.key,
    required this.gateway,
    required this.challenge,
    required this.summary,
    required this.consumedChallenges,
  });
  final CgyyBookingGateway gateway;
  final CgyyChallenge challenge;
  final String summary;
  final Set<String> consumedChallenges;
  @override
  State<CgyyCaptchaPage> createState() => _CgyyCaptchaPageState();
}

class _CgyyCaptchaPageState extends State<CgyyCaptchaPage> {
  Uint8List? background, piece;
  double width = 310, height = 155, pieceWidth = 60, pieceHeight = 155, x = 0;
  String? error;
  bool busy = false, attempted = false, dragged = false, allowExit = false;
  @override
  void initState() {
    super.initState();
    if (widget.consumedChallenges.contains(widget.challenge.id)) {
      error = '此验证已使用，请返回后重新准备预约';
    } else {
      decode();
    }
  }

  Future<void> decode() async {
    try {
      Uint8List bytes(String value) {
        if (value.length > 3000000) throw const FormatException();
        return base64Decode(
          value.contains(',') ? value.split(',').last : value,
        );
      }

      final a = bytes(widget.challenge.background),
          b = bytes(widget.challenge.jigsaw);
      final ac = await ui.instantiateImageCodec(a),
          bc = await ui.instantiateImageCodec(b);
      try {
        final af = await ac.getNextFrame(), bf = await bc.getNextFrame();
        final w = af.image.width.toDouble(),
            h = af.image.height.toDouble(),
            pw = bf.image.width.toDouble(),
            ph = bf.image.height.toDouble();
        af.image.dispose();
        bf.image.dispose();
        if (w <= pw ||
            w > 1000 ||
            h > 1000 ||
            ph > h ||
            pw <= 0 ||
            ph <= 0 ||
            widget.challenge.id.isEmpty) {
          throw const FormatException();
        }
        if (mounted) {
          setState(() {
            background = a;
            piece = b;
            width = w;
            height = h;
            pieceWidth = pw;
            pieceHeight = ph;
          });
        }
      } finally {
        ac.dispose();
        bc.dispose();
      }
    } catch (_) {
      if (mounted) setState(() => error = '验证图片无法显示，请返回后重新准备预约');
    }
  }

  Future<void> exit([CgyyActionResult? result]) async {
    if (!mounted || allowExit) return;
    setState(() => allowExit = true);
    await WidgetsBinding.instance.endOfFrame;
    if (mounted) Navigator.pop(context, result);
  }

  Future<void> submit() async {
    if (busy ||
        attempted ||
        !dragged ||
        x.round() <= 0 ||
        background == null ||
        piece == null ||
        error != null ||
        widget.consumedChallenges.contains(widget.challenge.id)) {
      return;
    }
    setState(() => busy = true);
    try {
      final confirmed = await showCupertinoDialog<bool>(
        context: context,
        builder: (context) => CupertinoAlertDialog(
          title: const Text('提交预约？'),
          content: Text(
            '${widget.summary}\n\n将验证你手动拖动的拼图并提交一次预约。受理不等于审批成功，提交后需回查。',
          ),
          actions: [
            CupertinoDialogAction(
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.pop(context, false);
                }
              },
              child: const Text('取消'),
            ),
            CupertinoDialogAction(
              isDefaultAction: true,
              onPressed: () {
                if (ModalRoute.of(context)?.isCurrent ?? false) {
                  Navigator.pop(context, true);
                }
              },
              child: const Text('提交一次'),
            ),
          ],
        ),
      );
      if (!mounted || confirmed != true) return;
      // A challenge is consumed even on rejection or transport failure.
      attempted = true;
      widget.consumedChallenges.add(widget.challenge.id);
      var outcome = CgyyActionResult.fromState(
        'uncertain',
        '结果待核实，请在我的预约回查，勿重复提交',
      );
      try {
        final response = await widget.gateway.executeCgyy({
          'action': 'submit',
          'challenge_id': widget.challenge.id,
          // Device/image pixels are normalized to the 310-wide protocol
          // coordinate by Rust; the width travels with the offset.
          'x': x,
          'width': width,
        });
        if (response.payload != null && response.failure == null) {
          final result = cgyyActionResult(response.payload!);
          if (result.isKnown) outcome = result;
        }
      } catch (_) {
        // Could fail before captcha/check, or after submit. Never claim success.
      }
      if (mounted) await exit(outcome);
    } finally {
      if (mounted && !attempted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope<CgyyActionResult>(
    canPop: allowExit,
    onPopInvokedWithResult: (didPop, result) {
      if (!didPop && !busy) exit();
    },
    child: CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        automaticallyImplyLeading: false,
        leading: CupertinoButton(
          key: const Key('captcha-back'),
          minimumSize: const Size(48, 48),
          padding: EdgeInsets.zero,
          onPressed: busy ? null : () => exit(),
          child: const Text('返回'),
        ),
        middle: const Text('学校拼图验证'),
      ),
      child: SafeArea(
        child: ListView(
          children: [
            AppleSection(
              header: const Text('拖动拼图对齐缺口'),
              footer: const Text(
                '验证由你手动完成，有效期约两分钟。返回不会自动提交；未发送最终预约时，返回后仍需核对并解除本机保护。',
              ),
              children: [
                if (background == null && error == null)
                  const Padding(
                    padding: EdgeInsets.all(24),
                    child: GinkgoActivity(size: 17),
                  ),
                if (background != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: SizedBox(
                      height: 180,
                      child: FittedBox(
                        fit: BoxFit.contain,
                        child: SizedBox(
                          width: width,
                          height: height,
                          child: Stack(
                            children: [
                              Image.memory(
                                background!,
                                width: width,
                                height: height,
                              ),
                              Positioned(
                                left: x,
                                top: 0,
                                child: Image.memory(
                                  piece!,
                                  width: pieceWidth,
                                  height: pieceHeight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                if (background != null)
                  Semantics(
                    label: '拼图横向位置',
                    child: SizedBox(
                      height: 48,
                      child: CupertinoSlider(
                        value: x,
                        min: 0,
                        max: width - pieceWidth,
                        onChanged: busy || attempted || error != null
                            ? null
                            : (value) => setState(() {
                                x = value;
                              }),
                        onChangeEnd: (value) =>
                            setState(() => dragged = value.round() > 0),
                      ),
                    ),
                  ),
                if (error != null) AppleListTile(title: Text(error!)),
                CupertinoButton(
                  minimumSize: const Size(48, 48),
                  onPressed:
                      busy ||
                          attempted ||
                          !dragged ||
                          x.round() <= 0 ||
                          background == null ||
                          error != null
                      ? null
                      : submit,
                  child: busy ? const Text('处理中…') : const Text('验证并提交一次'),
                ),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
