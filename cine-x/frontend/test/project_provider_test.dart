import 'package:cine_x/providers/project_provider.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('ProjectProvider safely exposes empty state before repository attach', () async {
    final provider = ProjectProvider.empty();

    await provider.load();

    expect(provider.loading, isFalse);
    expect(provider.projects, isEmpty);
    expect(provider.error, isNull);
  });
}
