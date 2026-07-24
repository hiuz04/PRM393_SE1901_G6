import 'package:cine_x/features/projects/data/models/cinex_models.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('Project parses JSON fields from backend', () {
    final project = Project.fromJson({
      'id': 1,
      'ownerId': 2,
      'title': 'CINE-X',
      'genre': 'Drama',
      'status': 'ACTIVE',
      'progressPercent': 66.5,
    });

    expect(project.id, 1);
    expect(project.title, 'CINE-X');
    expect(project.progressPercent, 66.5);
  });

  test('Scene parses nested characters', () {
    final scene = Scene.fromJson({
      'id': 1,
      'actId': 1,
      'actTitle': 'Act 1',
      'locationId': 2,
      'locationName': 'Studio',
      'settingType': 'INT',
      'timeOfDay': 'DAY',
      'sceneNumber': 4,
      'summary': 'A short scene',
      'status': 'TODO',
      'characters': [
        {'id': 9, 'name': 'Linh', 'roleType': 'MAIN'},
      ],
    });

    expect(scene.characters.single.name, 'Linh');
    expect(scene.settingType, 'INT');
  });
}
