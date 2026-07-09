import 'package:flutter/foundation.dart';

final class AppTask {
  final String id;
  String title;
  final DateTime started;
  DateTime? finished;
  final Duration? expiration;

  AppTask({required this.id, required this.title, this.expiration})
    : started = DateTime.now();

  bool get isRunning => finished == null;
}

final class TaskProvider extends ChangeNotifier {
  List<AppTask> _tasks = [];

  List<AppTask> get tasks => _tasks;

  void _cleanup() {
    final now = DateTime.now();

    // Keep running tasks, and up to 5 recently finished tasks for the tooltip
    final newTasks = _tasks.where((t) {
      if (t.isRunning) return true;
      if (t.finished != null && t.expiration != null) {
        return t.finished!.add(t.expiration!).isAfter(now);
      }
      return true; // Keep others
    }).toList();

    // Sort by started descending
    newTasks.sort((a, b) => b.started.compareTo(a.started));

    if (newTasks.length > 10) {
      _tasks = newTasks.sublist(0, 10); // Keep max 10 tasks in history
      notifyListeners();
    } else if (newTasks.length != _tasks.length) {
      _tasks = newTasks;
      notifyListeners();
    }
  }

  void startTask(String id, String title, {Duration? expiration}) {
    final task = AppTask(id: id, title: title, expiration: expiration);
    _tasks = [..._tasks.where((t) => t.id != id), task];
    notifyListeners();
    _cleanup();
  }

  void updateTask(String id, String title) {
    for (var t in _tasks) {
      if (t.id == id && t.isRunning) {
        t.title = title;
      }
    }
    notifyListeners();
  }

  void endTask(String id) {
    for (var t in _tasks) {
      if (t.id == id && t.isRunning) {
        t.finished = DateTime.now();
      }
    }
    notifyListeners();
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
