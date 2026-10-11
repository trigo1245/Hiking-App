import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hiking_app/app/app.dart';

void main() {
  testWidgets('하단 탭으로 홈 / 기록 / 내 정보 화면을 오갈 수 있다', (tester) async {
    await tester.pumpWidget(const ProviderScope(child: HikingApp()));
    await tester.pumpAndSettle();

    // 처음에는 홈 화면
    expect(find.text('홈 화면을 준비하고 있어요'), findsOneWidget);

    await tester.tap(find.text('기록'));
    await tester.pumpAndSettle();
    expect(find.text('아직 등산 기록이 없어요'), findsOneWidget);

    await tester.tap(find.text('내 정보').last);
    await tester.pumpAndSettle();
    expect(find.text('내 정보 화면을 준비하고 있어요'), findsOneWidget);

    await tester.tap(find.text('홈').last);
    await tester.pumpAndSettle();
    expect(find.text('홈 화면을 준비하고 있어요'), findsOneWidget);
  });
}
