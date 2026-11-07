import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:ui_kit/ui_kit.dart';

import '../ui/console/console_view.dart';
import '../ui/console/console_view_model.dart';
import '../ui/console/npc_notes_panel.dart';
import '../ui/dossier/dossier_view.dart';
import '../ui/dossier/dossier_view_model.dart';
import '../ui/home/home_screen.dart';
import '../ui/table/table_panel.dart';
import 'composition.dart';

/// Builds the router. `/` shows all panels on one device; the other routes
/// open a single panel, for a second window or display. [appearance] is the
/// player's theme setting. Each of [actions] replaces the composition; the
/// caller then builds a fresh router.
GoRouter buildRouter(
  Composition c, {
  required ThemeController appearance,
  required PlayActions actions,
}) {
  final console = ConsoleViewModel(c.episode);
  final notes = c.npcNotes();
  Widget? notesPanel() => notes == null ? null : NpcNotesPanel(model: notes);
  Widget single(String title, Widget body) => Scaffold(
    appBar: AppBar(title: Text(title)),
    body: Padding(padding: const EdgeInsets.all(8), child: body),
  );
  return GoRouter(
    routes: [
      GoRoute(
        path: '/',
        builder: (context, state) => HomeScreen(
          service: c.episode,
          console: console,
          npcNotes: notesPanel(),
          appearance: appearance,
          actions: actions,
          mode: c.mode,
          hosting: c.hosting,
          status: c.status,
          report: c.reportAction,
        ),
      ),
      GoRoute(
        path: '/gm',
        builder: (context, state) => single(
          'GM console',
          ConsoleView(model: console, npcNotes: notesPanel()),
        ),
      ),
      GoRoute(
        path: '/player/:agentId',
        builder: (context, state) => single(
          'Player',
          DossierView(
            model: DossierViewModel(
              c.episode,
              state.pathParameters['agentId']!,
            ),
          ),
        ),
      ),
      GoRoute(
        path: '/table',
        builder: (context, state) =>
            single('Table', TablePanel(service: c.episode)),
      ),
    ],
  );
}
