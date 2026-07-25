import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:mdi_build/app/app.dart';

void main() {
  testWidgets('MdiBuildApp builds without throwing', (WidgetTester tester) async {
    await tester.pumpWidget(const ProviderScope(child: MdiBuildApp()));
    await tester.pump();

    expect(find.byType(MdiBuildApp), findsOneWidget);
  });
}
