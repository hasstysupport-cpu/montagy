import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:montagy/app.dart';

void main() {
  testWidgets('التطبيق يقلع ويعرض الرئيسية', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(MontagyApp(prefs: prefs));
    await tester.pump(const Duration(milliseconds: 600));
    expect(find.text('مونتاجي'), findsWidgets);
    expect(find.text('مشروع جديد'), findsWidgets);
  });
}
