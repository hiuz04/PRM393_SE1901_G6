import 'package:cine_x/core/network/api_client.dart';
import 'package:cine_x/core/storage/token_storage.dart';
import 'package:cine_x/features/projects/data/models/cinex_models.dart';
import 'package:cine_x/features/projects/data/repositories/cinex_repository.dart';
import 'package:cine_x/features/projects/presentation/providers/project_provider.dart';
import 'package:flutter_test/flutter_test.dart';

class FakeRepository extends CineXRepository {
  FakeRepository(this.result)
      : super(ApiClient('http://localhost', MemoryTokenStorage()));

  final List<Project> result;

  @override
  Future<List<Project>> projects({String? search}) async => result;
}

void main() {
  test('ProjectProvider exposes loading then success', () async {
    final provider = ProjectProvider.empty()
      ..attach(
        FakeRepository([
          Project(
            id: 1,
            ownerId: 1,
            title: 'A',
            status: 'ACTIVE',
            progressPercent: 0,
          ),
        ]),
      );

    final future = provider.load();
    expect(provider.loading, isTrue);
    await future;

    expect(provider.loading, isFalse);
    expect(provider.projects.single.title, 'A');
    expect(provider.error, isNull);
  });
}
