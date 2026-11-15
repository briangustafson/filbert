import 'package:material_ui/material_ui.dart';

/// The project name; tap to edit in place. Saves on Enter or when focus
/// leaves the field. A blank name restores the previous one.
class ProjectNameField extends StatefulWidget {
  const ProjectNameField({super.key, required this.name, required this.onSave});

  final String name;
  final ValueChanged<String> onSave;

  @override
  State<ProjectNameField> createState() => _ProjectNameFieldState();
}

class _ProjectNameFieldState extends State<ProjectNameField> {
  final _controller = TextEditingController();
  final _focus = FocusNode();
  var _editing = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _commit();
    });
  }

  @override
  void dispose() {
    if (_editing) _commit(rebuild: false);
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEditing() {
    _controller
      ..text = widget.name
      ..selection = TextSelection(
        baseOffset: 0,
        extentOffset: widget.name.length,
      );
    setState(() => _editing = true);
    _focus.requestFocus();
  }

  void _commit({bool rebuild = true}) {
    final name = _controller.text.trim();
    _editing = false;
    if (name.isNotEmpty && name != widget.name) widget.onSave(name);
    if (rebuild) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.headlineSmall;
    if (_editing) {
      return TextField(
        controller: _controller,
        focusNode: _focus,
        style: style,
        textInputAction: TextInputAction.done,
        textCapitalization: TextCapitalization.sentences,
        decoration: const InputDecoration(
          isDense: true,
          hintText: 'Project name',
        ),
        onSubmitted: (_) => _focus.unfocus(),
        // Android doesn't unfocus on an outside tap by default.
        onTapOutside: (_) => _focus.unfocus(),
      );
    }
    return Semantics(
      button: true,
      hint: 'Rename',
      child: InkWell(
        onTap: _startEditing,
        borderRadius: BorderRadius.circular(4),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(widget.name, style: style),
        ),
      ),
    );
  }
}
