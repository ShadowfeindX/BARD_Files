import 'package:flutter/material.dart';

import 'theme/bard_tokens.dart';

/// A state chip: glyph, word, the token pair for its kind and a 1 px `ink`
/// outline (2 px in high contrast). It always shows glyph and word, so the
/// meaning never depends on colour (07-apps.md, Chips).
class ResultChip extends StatelessWidget {
  /// Creates a chip of [kind] reading [label].
  const ResultChip({super.key, required this.kind, required this.label});

  /// Which chip.
  final ChipKind kind;

  /// The word shown beside the glyph.
  final String label;

  @override
  Widget build(BuildContext context) {
    final tokens = BardTokens.of(context);
    final (fill, on) = tokens.chip(kind);
    return Semantics(
      label: label,
      child: ExcludeSemantics(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: fill,
            border: Border.all(color: tokens.ink, width: tokens.chipOutline),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _glyph(on),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(color: on, fontWeight: FontWeight.w600),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _glyph(Color on) => switch (kind) {
    ChipKind.success => Icon(Icons.check_box_outlined, size: 18, color: on),
    ChipKind.partial => CustomPaint(
      size: const Size(18, 18),
      painter: _HalfDiamond(on),
    ),
    ChipKind.failure => Icon(Icons.cancel_outlined, size: 18, color: on),
    ChipKind.warning => Icon(Icons.warning_amber, size: 18, color: on),
    ChipKind.locked => Icon(Icons.lock_outline, size: 18, color: on),
    ChipKind.confirm => Icon(Icons.check, size: 18, color: on),
  };
}

/// A diamond with its left half filled.
class _HalfDiamond extends CustomPainter {
  _HalfDiamond(this.color);

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final path = Path()
      ..moveTo(c.dx, 0)
      ..lineTo(size.width, c.dy)
      ..lineTo(c.dx, size.height)
      ..lineTo(0, c.dy)
      ..close();
    final stroke = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    final half = Path()
      ..moveTo(c.dx, 0)
      ..lineTo(0, c.dy)
      ..lineTo(c.dx, size.height)
      ..close();
    canvas
      ..drawPath(half, Paint()..color = color)
      ..drawPath(path, stroke);
  }

  @override
  bool shouldRepaint(_HalfDiamond old) => old.color != color;
}
