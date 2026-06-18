import 'dart:async';
import 'package:jaspr/jaspr.dart';
import 'package:jaspr/dom.dart';
import 'package:jaspr_riverpod/jaspr_riverpod.dart';
import '../constants/theme.dart';
import '../providers/task_provider.dart';
import 'icon.dart';

class TaskStatus extends StatefulComponent {
  const TaskStatus({super.key});

  @override
  State<TaskStatus> createState() => _TaskStatusState();

  @css
  static List<StyleRule> get styles => [
    css('.toolbar-right').styles(
      display: Display.flex,
      alignItems: AlignItems.center,
      position: Position.relative(),
      cursor: Cursor.defaultCursor,
      raw: {'flex': '1 1 0', 'justify-content': 'flex-end'},
    ),
    css('.status-message').styles(
      fontSize: 12.px,
      color: Theme.textSecondary,
      raw: {'white-space': 'nowrap'},
    ),
    css('.status-icon').styles(
      display: Display.inlineBlock,
      fontSize: 16.px,
      color: Theme.textSecondary,
      margin: Margin.only(left: 8.px),
      cursor: Cursor.help,
      raw: {'transition': 'color 0.3s'},
    ),
    css('.status-icon.busy').styles(
      raw: {'animation': 'spin 1.8s linear infinite'},
    ),
    css.keyframes('spin', {
      '0%': Styles(raw: {'transform': 'rotate(0deg)'}),
      '100%': Styles(raw: {'transform': 'rotate(360deg)'}),
    }),
    css('.task-tooltip').styles(
      display: Display.none,
      position: Position.absolute(top: 100.percent, right: 0.px),
      backgroundColor: Theme.surfaceActive,
      padding: Padding.all(8.px),
      zIndex: ZIndex(100),
      raw: {'border-radius': '4px', 'box-shadow': '0 4px 12px rgba(0,0,0,0.5)'},
      minWidth: 200.px,
    ),
    css('.toolbar-right:hover .task-tooltip').styles(
      display: Display.block,
    ),
    css('.task-row').styles(
      display: Display.flex,
      justifyContent: JustifyContent.spaceBetween,
      fontSize: 11.px,
      color: Theme.textSecondary,
      padding: Padding.symmetric(vertical: 2.px),
    ),
    css('.task-title').styles(
      overflow: Overflow.hidden,
      raw: {'text-overflow': 'ellipsis', 'margin-right': '16px', 'white-space': 'nowrap'},
    ),
    css('.task-time').styles(
      fontFamily: const FontFamily.list([FontFamily('Google Sans Mono'), FontFamilies.monospace]),
      raw: {'white-space': 'nowrap'},
    ),
  ];
}

class _TaskStatusState extends State<TaskStatus> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
  }

  @override
  void didUpdateComponent(TaskStatus oldComponent) {
    super.didUpdateComponent(oldComponent);
  }

  void _checkTimer(List<AppTask> tasks) {
    final hasRunning = tasks.any((t) => t.isRunning);
    if (hasRunning && _timer == null) {
      _timer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        setState(() {});
      });
    } else if (!hasRunning && _timer != null) {
      _timer?.cancel();
      _timer = null;
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  String _formatDuration(Duration d) {
    if (d.inSeconds < 60) {
      return '${(d.inMilliseconds / 1000).toStringAsFixed(1)}s';
    } else {
      final m = d.inMinutes;
      final s = (d.inMilliseconds % 60000) / 1000;
      return '${m}m ${s.toStringAsFixed(1)}s';
    }
  }

  @override
  Component build(BuildContext context) {
    final tasks = context.watch(appTasksProvider);
    _checkTimer(tasks);

    final sortedTasks = tasks.toList()..sort((t1, t2) => t2.started.compareTo(t1.started));
    final activeTask = sortedTasks.where((t) => t.isRunning).firstOrNull;
    final isBusy = activeTask != null;
    
    String statusText = 'Ready';
    if (activeTask != null) {
      statusText = activeTask.title;
    }

    return div(classes: 'toolbar-right', [
      span(classes: 'status-message', [Component.text(statusText)]),
      if (isBusy)
        Icon('progress_activity', classes: 'status-icon busy')
      else
        Icon('check_circle', classes: 'status-icon'),
      
      if (tasks.isNotEmpty)
        div(classes: 'task-tooltip', [
          for (final task in sortedTasks.take(15))
            div(classes: 'task-row', [
              span(classes: 'task-title', [Component.text(task.title)]),
              span(classes: 'task-time', [
                Component.text(_formatDuration(
                  task.isRunning 
                    ? DateTime.now().difference(task.started) 
                    : task.finished!.difference(task.started)
                ))
              ]),
            ])
        ]),
    ]);
  }
}
