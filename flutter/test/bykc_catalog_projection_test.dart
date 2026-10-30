import 'package:flutter_test/flutter_test.dart';
import 'package:ginkgo_mirror/features/bykc/bykc_page.dart';
import 'package:ginkgo_mirror/main.dart';

import 'bykc_fixture.dart';

void main() {
  testWidgets(
    'catalog displays the projected semester without inferring dates',
    (tester) async {
      await tester.pumpWidget(
        ginkgoApp(
          home: BykcPage(
            loader: ({required part, required forceRefresh}) async =>
                bykcRead(part, {
                  'terms': [
                    {'name': '原始目录中的另一个学期'},
                  ],
                  'currentTerm': {'name': 'Rust 选定的学期'},
                  'courses': [],
                }),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Rust 选定的学期'), findsOneWidget);
      expect(find.text('原始目录中的另一个学期'), findsNothing);
    },
  );
}
