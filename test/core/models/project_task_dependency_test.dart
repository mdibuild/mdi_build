import 'package:flutter_test/flutter_test.dart';
import 'package:mdi_build/core/models/project_task_dependency.dart';

ProjectTaskDependency _buildDependency(String dependencyType) {
  final now = DateTime(2026, 1, 1);
  return ProjectTaskDependency(
    id: 'd1',
    companyId: 'c1',
    projectId: 'p1',
    predecessorTaskId: 't1',
    successorTaskId: 't2',
    dependencyType: dependencyType,
    createdAt: now,
    updatedAt: now,
  );
}

void main() {
  group('ProjectTaskDependency type getters', () {
    test('isFinishToStart is true only for finish_to_start', () {
      final dependency = _buildDependency('finish_to_start');
      expect(dependency.isFinishToStart, isTrue);
      expect(dependency.isStartToFinish, isFalse);
      expect(dependency.isStartToStart, isFalse);
      expect(dependency.isFinishToFinish, isFalse);
    });

    test('isStartToFinish is true only for start_to_finish', () {
      final dependency = _buildDependency('start_to_finish');
      expect(dependency.isStartToFinish, isTrue);
      expect(dependency.isFinishToStart, isFalse);
    });

    test('isStartToStart is true only for start_to_start', () {
      final dependency = _buildDependency('start_to_start');
      expect(dependency.isStartToStart, isTrue);
      expect(dependency.isFinishToFinish, isFalse);
    });

    test('isFinishToFinish is true only for finish_to_finish', () {
      final dependency = _buildDependency('finish_to_finish');
      expect(dependency.isFinishToFinish, isTrue);
      expect(dependency.isStartToStart, isFalse);
    });
  });

  group('ProjectTaskDependency.fromMap defaults', () {
    test('defaults dependencyType to finish_to_start when missing', () {
      final map = {
        'id': 'd1',
        'company_id': 'c1',
        'project_id': 'p1',
        'predecessor_task_id': 't1',
        'successor_task_id': 't2',
        'created_at': '2026-01-01T00:00:00.000Z',
        'updated_at': '2026-01-01T00:00:00.000Z',
      };

      final dependency = ProjectTaskDependency.fromMap(map);

      expect(dependency.isFinishToStart, isTrue);
    });
  });

  group('ProjectTaskDependency.copyWith', () {
    test('overrides only the provided fields', () {
      final original = _buildDependency('finish_to_start');
      final updated = original.copyWith(dependencyType: 'start_to_start');

      expect(updated.dependencyType, 'start_to_start');
      expect(updated.id, original.id);
      expect(updated.predecessorTaskId, original.predecessorTaskId);
      expect(updated.successorTaskId, original.successorTaskId);
    });
  });
}
