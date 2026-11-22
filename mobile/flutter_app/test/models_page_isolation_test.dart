import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:cutawan_mobile/screens/home_shell/models_page.dart';

void main() {
  test('model center is exposed as an independent Flutter screen', () {
    const page = ModelsPage();
    expect(page, isA<Widget>());
  });
}
