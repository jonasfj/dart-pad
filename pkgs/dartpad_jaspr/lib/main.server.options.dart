// dart format off
// ignore_for_file: type=lint

// GENERATED FILE, DO NOT MODIFY
// Generated with jaspr_builder

import 'package:jaspr/server.dart';
import 'package:dartpad_jaspr/components/app_header.dart' as _app_header;
import 'package:dartpad_jaspr/components/console.dart' as _console;
import 'package:dartpad_jaspr/components/editor.dart' as _editor;
import 'package:dartpad_jaspr/components/editor_toolbar.dart'
    as _editor_toolbar;
import 'package:dartpad_jaspr/components/file_tree.dart' as _file_tree;
import 'package:dartpad_jaspr/components/icon_button.dart' as _icon_button;
import 'package:dartpad_jaspr/components/modal.dart' as _modal;
import 'package:dartpad_jaspr/components/panel.dart' as _panel;
import 'package:dartpad_jaspr/components/sandbox.dart' as _sandbox;
import 'package:dartpad_jaspr/components/split_pane.dart' as _split_pane;
import 'package:dartpad_jaspr/components/task_status.dart' as _task_status;
import 'package:dartpad_jaspr/constants/theme.dart' as _theme;
import 'package:dartpad_jaspr/app.dart' as _app;

/// Default [ServerOptions] for use with your Jaspr project.
///
/// Use this to initialize Jaspr **before** calling [runApp].
///
/// Example:
/// ```dart
/// import 'main.server.options.dart';
///
/// void main() {
///   Jaspr.initializeApp(
///     options: defaultServerOptions,
///   );
///
///   runApp(...);
/// }
/// ```
ServerOptions get defaultServerOptions => ServerOptions(
  clientId: 'main.client.dart.js',
  clients: {_app.App: ClientTarget<_app.App>('app')},
  styles: () => [
    ..._theme.styles,
    ..._app.AppState.styles,
    ..._app_header.AppHeader.styles,
    ..._console.ConsoleComponent.styles,
    ..._editor.Editor.styles,
    ..._editor_toolbar.EditorToolbar.styles,
    ..._file_tree.FileTree.styles,
    ..._icon_button.IconButton.styles,
    ..._modal.ModalDialog.styles,
    ..._panel.Panel.styles,
    ..._sandbox.SandboxComponent.styles,
    ..._split_pane.SplitPane.styles,
    ..._task_status.TaskStatus.styles,
  ],
);
