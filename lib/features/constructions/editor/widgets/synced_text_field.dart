import 'package:flutter/material.dart';

/// A `TextFormField` whose displayed text is driven by an external value
/// (`value`) that can change for reasons other than the user typing --
/// e.g. switching stages away and back, or a different section being
/// selected. Uses a `TextEditingController` kept in sync via
/// `didUpdateWidget` instead of keying the field by its own live value.
///
/// The previous implementation keyed each field as
/// `ValueKey('width-$id-${draft.width}')` -- including the live value in
/// the key. Every keystroke changed `draft.width`, which changed the key,
/// which made Flutter tear down and rebuild a brand-new `TextFormField`
/// on every character: focus, cursor position, and -- if the rebuild won
/// the race against that keystroke's `onChanged` call -- the keystroke
/// itself could be lost. That is exactly what going Back/Next or
/// reopening a stage could appear to "undo": the last character typed
/// before switching away had not reliably reached the draft yet. Syncing
/// a stable controller instead removes that race entirely -- the
/// controller is the single source of the field's text, updated
/// explicitly, never torn down by a keystroke.
class SyncedTextField extends StatefulWidget {
  final String value;
  final String label;
  final String? suffixText;
  final TextInputType? keyboardType;
  final ValueChanged<String> onChanged;

  /// Optional external focus control -- lets callers (e.g. the canvas's
  /// dimension-label interaction) bring THIS exact field into focus.
  /// Owned by the caller, like every FocusNode.
  final FocusNode? focusNode;

  const SyncedTextField({
    super.key,
    required this.value,
    required this.label,
    required this.onChanged,
    this.suffixText,
    this.keyboardType,
    this.focusNode,
  });

  @override
  State<SyncedTextField> createState() => _SyncedTextFieldState();
}

class _SyncedTextFieldState extends State<SyncedTextField> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.value,
  );

  @override
  void didUpdateWidget(covariant SyncedTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Only push an external change into the controller when the field's
    // current text doesn't already match it -- otherwise every keystroke
    // (which changes `widget.value` via the parent's rebuild in the same
    // frame) would fight the controller for cursor position. A mismatch
    // here means the value changed for some other reason (a different
    // section selected, a stage switch and back), so the field's text
    // needs to catch up.
    if (widget.value != _controller.text) {
      _controller.value = TextEditingValue(
        text: widget.value,
        selection: TextSelection.collapsed(offset: widget.value.length),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: _controller,
      focusNode: widget.focusNode,
      keyboardType: widget.keyboardType,
      decoration: InputDecoration(
        labelText: widget.label,
        suffixText: widget.suffixText,
      ),
      onChanged: widget.onChanged,
    );
  }
}
