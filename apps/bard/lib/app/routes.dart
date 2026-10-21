import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../ui/console/console_view.dart';
import '../ui/console/console_view_model.dart';
import '../ui/dossier/dossier_view.dart';
import '../ui/dossier/dossier_view_model.dart';
import '../ui/home/home_screen.dart';
import '../ui/table/table_panel.dart';
import 'composition.dart';

/// Builds the router. `/` shows all panels on one device; the other routes
/// open a single panel, for a second window or display. [onNewOperation]
/// replaces the operation; the caller then builds a fresh router.
GoRouter buildRouter(Composition c, {required VoidCallback onNewOperation}) {
  final console = ConsoleViewModel(c.operation);
  Widget single(String title, Widget body) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Padding(padding: const EdgeInsets.all(8), child: body),
  );
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HomeScreen(
          service: c.operation,
          console: console,
          onNewOperation: onNewOperation,
        ),
      ),
      GoRoute(
        path: '/gm',
        builder: (context, state) =>
            single('GM console', ConsoleView(model: console)),
      ),
      GoRoute(
        path: '/player/:agentId',
        builder: (context, state) => single(
          'Player',
          DossierView(
            model: DossierViewModel(
              c.operation,
              state.pathParameters['agentId']!,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/table',
        builder: (context, state) =>
            single('Table', TablePanel(service: c.operation)),
      ),
    ],
  );
}
