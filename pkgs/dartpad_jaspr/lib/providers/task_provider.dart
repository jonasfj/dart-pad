
import 'package:jaspr/jaspr.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';

final appTasksProvider = NotifierProvider<AppTasksNotifier, List<AppTask>>(() {
  return AppTasksNotifier();
});

final class AppTasksNotifier extends Notifier<List<AppTask>> {
  @override
  List<AppTask> build() => [];

  void _cleanup() {
    final now = DateTime.now();
    AppTask? newest;
    for (var t in state) {
      if (newest == null || t.started.isAfter(newest.started)) {
        newest = t;
      }
    }
    
    final newTasks = state.where((t) {
      if (t == newest) return true;
      if (t.finished != null && t.expiration != null) {
        return t.finished!.add(t.expiration!).isAfter(now);
      }
      return true;
    }).toList();

    if (newTasks.length != state.length) {
      state = newTasks;
    }
  }

  void startTask(String id, String title, {Duration? expiration}) {
    final task = AppTask(id: id, title: title, expiration: expiration);
    state = [...state.where((t) => t.id != id), task];
    _cleanup();
  }

  void updateTask(String id, String title) {
    final tasks = [...state];
    for (var t in tasks) {
      if (t.id == id && t.isRunning) {
        t.title = title;
      }
    }
    state = tasks;
  }

  void endTask(String id) {
    final tasks = [...state];
    for (var t in tasks) {
      if (t.id == id && t.isRunning) {
        t.finished = DateTime.now();
      }
    }
    state = tasks;
    _cleanup();
  }

  Future<T> runTask<T>(
    String id,
    String title,
    Future<T> Function() action, {
    Duration? expiration,
  }) async {
    startTask(id, title, expiration: expiration);
    try {
      return await action();
    } finally {
      endTask(id);
    }
  }
}

extension RunTaskExtension on BuildContext {
  Future<T> runTask<T>(
    String id,
    String title,
    Future<T> Function() action, {
    Duration? expiration,
  }) {
    return read(appTasksProvider.notifier).runTask(id, title, action, expiration: expiration);
  }
}

final class AppTask {
  final String id;
  String title;
  final DateTime started;
  DateTime? finished;
  final Duration? expiration;

  AppTask({
    required this.id,
    required this.title,
    this.expiration,
  }) : started = DateTime.now();

  bool get isRunning => finished == null;
}
