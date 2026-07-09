import 'package:flutter/material.dart';

final class ConsoleWidget extends StatefulWidget {
  final Stream<String> stream;

  const ConsoleWidget({super.key, required this.stream});

  @override
  State<ConsoleWidget> createState() => _ConsoleWidgetState();
}

class _ConsoleWidgetState extends State<ConsoleWidget> {
  final List<String> _lines = [];
  final ScrollController _scrollController = ScrollController();

  @override
  void initState() {
    super.initState();
    widget.stream.listen((line) {
      if (mounted) {
        if (line == '[CLEAR]') {
          setState(() {
            _lines.clear();
          });
          return;
        }
        setState(() {
          _lines.add(line);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (_scrollController.hasClients) {
            _scrollController.jumpTo(
              _scrollController.position.maxScrollExtent,
            );
          }
        });
      }
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: const Color(0xFF1e1e1e),
      padding: const EdgeInsets.all(8.0),
      child: ListView.builder(
        controller: _scrollController,
        itemCount: _lines.length,
        itemBuilder: (context, index) {
          final line = _lines[index];
          final isError = line.startsWith('[ERROR]');
          final isSystem = line.startsWith('[SYSTEM]');
          return SelectableText(
            line,
            style: TextStyle(
              fontFamily: 'monospace',
              fontSize: 12,
              color: isError
                  ? Colors.redAccent
                  : isSystem
                  ? Colors.lightBlueAccent
                  : Colors.white70,
            ),
          );
        },
      ),
    );
  }
}
