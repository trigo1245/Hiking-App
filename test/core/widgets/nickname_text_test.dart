import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/core/design/design.dart';
import 'package:hiking_app/core/widgets/nickname_text.dart';

void main() {
  testWidgets('태그는 닉네임보다 연한 색으로, (나)는 닉네임 색으로 붙인다', (tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: NicknameText(nickname: '등산왕', tag: '0421', suffix: ' (나)'),
      ),
    );
    expect(find.text('등산왕#0421 (나)'), findsOneWidget);

    final spans = (tester.widget<Text>(find.byType(Text)).textSpan! as TextSpan)
        .children!
        .cast<TextSpan>();
    expect(spans.map((s) => s.text), ['등산왕', '#0421', ' (나)']);
    expect(spans[0].style, isNull);
    expect(spans[1].style!.color, AppColors.textTertiary);
    expect(spans[2].style, isNull);
  });
}
