import 'dart:async';

import 'package:material_ui/material_ui.dart';

/// Start notes: a collapsed preview that expands into a multi-line field.
/// Saves 600 ms after typing stops, and immediately when focus leaves the
/// field or the screen closes.
class StartNotesField extends StatefulWidget {
  const StartNotesField({super.key, required this.notes, required this.onSave});

  static const saveDelay = Duration(milliseconds: 600);

  final String notes;
  final ValueChanged<String> onSave;

  @override
  State<StartNotesField> createState() => _StartNotesFieldState();
}

class _StartNotesFieldState extends State<StartNotesField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  Timer? _debounce;
  var _expanded = false;

  /// Last value handed to [StartNotesField.onSave], to skip no-op saves.
  late String _saved = widget.notes;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _expanded) {
        _flush();
        setState(() => _expanded = false);
      }
    });
  }

  @override
  void didUpdateWidget(StartNotesField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!_expanded) _saved = widget.notes;
  }

  @override
  void dispose() {
    _flush();
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _expand() {
    _controller.text = widget.notes;
    _saved = widget.notes;
    setState(() => _expanded = true);
    _focus.requestFocus();
  }

  void _onChanged(String _) {
    _debounce?.cancel();
    _debounce = Timer(StartNotesField.saveDelay, _flush);
  }

  void _flush() {
    _debounce?.cancel();
    _debounce = null;
    if (!_expanded) return;
    final notes = _controller.text;
    if (notes == _saved) return;
    _saved = notes;
    widget.onSave(notes);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = Text('Start notes', style: theme.textTheme.labelLarge);
    if (_expanded) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          label,
          const SizedBox(height: 8),
          TextField(
            controller: _controller,
            focusNode: _focus,
            onChanged: _onChanged,
            // Android doesn't unfocus on an outside tap by default.
            onTapOutside: (_) => _focus.unfocus(),
            minLines: 4,
            maxLines: null,
            keyboardType: TextInputType.multiline,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              hintText: 'Palette, ground, goals for this painting…',
            ),
          ),
        ],
      );
    }
    final empty = widget.notes.isEmpty;
    return InkWell(
      onTap: _expand,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            label,
            const SizedBox(height: 4),
            Text(
              empty ? 'Add start notes' : widget.notes,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: empty ? theme.colorScheme.onSurfaceVariant : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
