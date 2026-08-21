import 'package:flutter/material.dart';

/// Small uppercase section heading used by every editor properties panel
/// ("GÉNÉRAL", "DIMENSIONS", ...). Shared so all panels render headings
/// identically instead of restyling the same text in five places.
class PanelHeader extends StatelessWidget {
  final String text;

  const PanelHeader(this.text, {super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: const TextStyle(
          fontSize: 12,
          fontWeight: FontWeight.bold,
          color: Color(0xFF5B6B76),
          letterSpacing: 0.5,
        ),
      ),
    );
  }
}
