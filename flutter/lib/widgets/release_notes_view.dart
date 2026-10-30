/// GitHub Release bodies are Markdown, and the house style is a heading, a few
/// `-` bullets, a notice paragraph and a footer of links. Showing that source
/// verbatim hands the reader `- ` and `**` instead of a list, so this parses
/// exactly that subset and nothing more.
///
/// The source is remote content: it is length-bounded, images are never
/// fetched, and only allow-listed https destinations become tappable.
library;

import 'package:flutter/cupertino.dart';

import 'package:ginkgo_mirror/design/apple_design.dart';
import 'package:ginkgo_mirror/shared/school_links.dart';

/// Remote release copy is bounded before parsing. A malformed or hostile body
/// must not turn into an unbounded widget tree.
const int releaseNotesSourceLimit = 8192;

sealed class NotesBlock {
  const NotesBlock();
}

class NotesHeading extends NotesBlock {
  const NotesHeading(this.level, this.spans);
  final int level;
  final List<NotesSpan> spans;
}

class NotesBullet extends NotesBlock {
  const NotesBullet(this.spans);
  final List<NotesSpan> spans;
}

class NotesParagraph extends NotesBlock {
  const NotesParagraph(this.spans);
  final List<NotesSpan> spans;
}

sealed class NotesSpan {
  const NotesSpan();
}

class NotesText extends NotesSpan {
  const NotesText(this.text, {this.bold = false});
  final String text;
  final bool bold;
}

/// [url] is `null` when the destination failed the allow-list, which renders
/// the label as plain text rather than as a dead or untrusted tap target.
class NotesLink extends NotesSpan {
  const NotesLink(this.text, this.url);
  final String text;
  final String? url;
}

/// Only the project's own GitHub pages may be opened from remote release copy.
///
/// School destinations are deliberately absent: a domain allow-list is upstream
/// policy, and `flutter/lib/widgets/` must not carry it. Release notes follow
/// the house style of linking the project's docs and issue tracker, so anything
/// else — a relative docs link, another repository, a look-alike host, plain
/// http or embedded credentials — stays plain text with no tap target.
bool openableReleaseLink(String url) {
  final parsed = Uri.tryParse(url);
  if (parsed == null ||
      parsed.scheme != 'https' ||
      parsed.userInfo.isNotEmpty ||
      parsed.host != 'github.com') {
    return false;
  }
  return parsed.path.startsWith('/JUANWANG-BUAA/ginkgo');
}

/// Parses `[text](url)` at [start]; `null` when that shape is absent.
({String text, String url, int end})? _linkAt(String input, int start) {
  final textEnd = input.indexOf(']', start + 1);
  if (textEnd < 0 || textEnd + 1 >= input.length || input[textEnd + 1] != '(') {
    return null;
  }
  final urlEnd = input.indexOf(')', textEnd + 2);
  if (urlEnd < 0) return null;
  return (
    text: input.substring(start + 1, textEnd),
    url: input.substring(textEnd + 2, urlEnd),
    end: urlEnd + 1,
  );
}

List<NotesSpan> parseNotesInline(String input) {
  final spans = <NotesSpan>[];
  final buffer = StringBuffer();
  var bold = false;
  var index = 0;

  void flush() {
    if (buffer.isEmpty) return;
    spans.add(NotesText(buffer.toString(), bold: bold));
    buffer.clear();
  }

  while (index < input.length) {
    // An image is never fetched; only its alternative text is shown.
    if (input.startsWith('![', index)) {
      final image = _linkAt(input, index + 1);
      if (image != null) {
        flush();
        if (image.text.isNotEmpty) spans.add(NotesText(image.text, bold: bold));
        index = image.end;
        continue;
      }
    }
    if (input.startsWith('[', index)) {
      final link = _linkAt(input, index);
      if (link != null) {
        flush();
        final url = openableReleaseLink(link.url) ? link.url : null;
        spans.add(NotesLink(link.text.isEmpty ? link.url : link.text, url));
        index = link.end;
        continue;
      }
    }
    if (input.startsWith('**', index)) {
      flush();
      bold = !bold;
      index += 2;
      continue;
    }
    buffer.write(input[index]);
    index += 1;
  }
  flush();
  return spans;
}

List<NotesBlock> parseReleaseNotes(String source) {
  final bounded = source.length > releaseNotesSourceLimit
      ? source.substring(0, releaseNotesSourceLimit)
      : source;
  final blocks = <NotesBlock>[];
  List<NotesSpan>? paragraph;

  void closeParagraph() {
    if (paragraph == null) return;
    final spans = paragraph!;
    paragraph = null;
    if (spans.isNotEmpty) blocks.add(NotesParagraph(spans));
  }

  for (final rawLine in bounded.split('\n')) {
    final line = rawLine.trimRight();
    if (line.trim().isEmpty) {
      closeParagraph();
      continue;
    }
    final heading = RegExp(r'^(#{1,6})\s+(.*)$').firstMatch(line);
    if (heading != null) {
      closeParagraph();
      blocks.add(
        NotesHeading(
          heading.group(1)!.length,
          parseNotesInline(heading.group(2)!.trim()),
        ),
      );
      continue;
    }
    final bullet = RegExp(r'^[-*+]\s+(.*)$').firstMatch(line);
    if (bullet != null) {
      closeParagraph();
      blocks.add(NotesBullet(parseNotesInline(bullet.group(1)!.trim())));
      continue;
    }
    // Consecutive plain lines are one paragraph, matching Markdown's own rule.
    (paragraph ??= <NotesSpan>[]).addAll(parseNotesInline(line));
  }
  closeParagraph();
  return blocks;
}

/// Renders parsed release notes.
///
/// Links use [WidgetSpan] rather than a [TapGestureRecognizer]: recognisers are
/// owned objects that would have to be disposed on every rebuild, and release
/// notes carry at most a couple of links.
class ReleaseNotesView extends StatelessWidget {
  const ReleaseNotesView({super.key, required this.source});
  final String source;

  TextStyle _body(BuildContext context) => AppleDesign.callout.copyWith(
    color: CupertinoColors.secondaryLabel.resolveFrom(context),
    height: 1.5,
  );

  Future<void> _open(BuildContext context, String url) async {
    if (!await openSchoolLink(url) && context.mounted) {
      await showSchoolLinkError(context);
    }
  }

  InlineSpan _span(BuildContext context, NotesSpan span, TextStyle style) {
    switch (span) {
      case NotesText(:final text, :final bold):
        return TextSpan(
          text: text,
          style: bold ? style.copyWith(fontWeight: FontWeight.w600) : style,
        );
      // A link the allow-list rejected keeps its label but loses the tap target.
      case NotesLink(:final text, url: null):
        return TextSpan(text: text, style: style);
      case NotesLink(:final text, url: final String url):
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Semantics(
            link: true,
            child: GestureDetector(
              onTap: () => _open(context, url),
              child: Text(
                text,
                style: style.copyWith(
                  color: CupertinoColors.systemBlue.resolveFrom(context),
                ),
              ),
            ),
          ),
        );
    }
  }

  List<Widget> _blocks(BuildContext context, NotesBlock block) {
    final style = _body(context);
    InlineSpan span(NotesSpan value) => _span(context, value, style);
    return switch (block) {
      NotesHeading(:final level, :final spans) => [
        Padding(
          padding: EdgeInsets.only(
            top: GinkgoSpacing.md,
            bottom: GinkgoSpacing.xs,
          ),
          child: Semantics(
            header: true,
            child: Text.rich(
              TextSpan(
                style: level == 1
                    ? AppleDesign.headline
                    : AppleDesign.subheadline.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                children: [for (final value in spans) span(value)],
              ),
            ),
          ),
        ),
      ],
      NotesBullet(:final spans) => [
        Padding(
          padding: EdgeInsets.only(bottom: GinkgoSpacing.xs),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(right: GinkgoSpacing.small),
                child: Text('•', style: style),
              ),
              Expanded(
                child: Text.rich(
                  TextSpan(
                    style: style,
                    children: [for (final value in spans) span(value)],
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
      NotesParagraph(:final spans) => [
        Padding(
          padding: EdgeInsets.only(top: GinkgoSpacing.small),
          child: Text.rich(
            TextSpan(
              style: style,
              children: [for (final value in spans) span(value)],
            ),
          ),
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    if (source.trim().isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: GinkgoSpacing.edgeInsetsCard,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final block in parseReleaseNotes(source))
            ..._blocks(context, block),
        ],
      ),
    );
  }
}
