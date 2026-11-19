import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import 'layout.dart';

/// Keyboard shortcuts (m3-design §3.3).
///
/// Each screen wraps itself in [KeyBindings]; they also work on Android
/// with a hardware keyboard. ⌘ on Apple platforms is Ctrl elsewhere.

bool get _apple =>
    defaultTargetPlatform == TargetPlatform.macOS ||
    defaultTargetPlatform == TargetPlatform.iOS;

/// ⌘[key] on Apple platforms, Ctrl+[key] elsewhere.
SingleActivator command(LogicalKeyboardKey key, {bool shift = false}) =>
    SingleActivator(key, meta: _apple, control: !_apple, shift: shift);

/// [label] with its keys on a desktop ("Back (Esc)"), else [label].
String withShortcut(String label, String keys) =>
    isDesktop ? '$label ($keys)' : label;

/// A tooltip naming [keys] for a button whose [label] is already shown;
/// none on phones.
String? shortcutTooltip(String label, String keys) =>
    isDesktop ? '$label ($keys)' : null;

/// "⌘O" on Apple platforms, "Ctrl+O" elsewhere.
String commandKey(String key) => _apple ? '⌘$key' : 'Ctrl+$key';

/// One shortcut. [whileTyping]: still works while a text field has focus
/// (⌘ shortcuts that don't edit text); letters, arrows, Delete and Esc
/// don't. [onReleased] makes it a hold (Space shows the original).
class KeyBinding {
  const KeyBinding(
    this.activator,
    this.onPressed, {
    this.whileTyping = false,
    this.onReleased,
  });

  final SingleActivator activator;
  final VoidCallback onPressed;
  final bool whileTyping;
  final VoidCallback? onReleased;
}

/// Handles [bindings] for key events from anywhere inside [child].
///
/// [scope] (a screen): a focus scope that takes focus when it appears, so
/// keys reach it without a click, and focus returns to it when a text
/// field lets go. Without it (a photo tile), only keys from a focused
/// descendant are seen.
///
/// Return and Space are left to a focused button or tile, which they
/// activate. Esc in a text field drops the field's focus.
class KeyBindings extends StatefulWidget {
  const KeyBindings({
    super.key,
    required this.bindings,
    this.scope = true,
    required this.child,
  });

  final List<KeyBinding> bindings;
  final bool scope;
  final Widget child;

  @override
  State<KeyBindings> createState() => _KeyBindingsState();
}

class _KeyBindingsState extends State<KeyBindings> {
  late final FocusNode _node = widget.scope
      ? FocusScopeNode(debugLabel: 'KeyBindings')
      : FocusNode(
          debugLabel: 'KeyBindings',
          canRequestFocus: false,
          skipTraversal: true,
        );

  /// Holds pressed and not yet released.
  final _held = <KeyBinding>{};

  @override
  void dispose() {
    _node.dispose();
    super.dispose();
  }

  static bool get _typing =>
      primaryFocus?.context?.findAncestorWidgetOfExactType<EditableText>() !=
      null;

  KeyEventResult _onKeyEvent(FocusNode node, KeyEvent event) {
    if (event is KeyUpEvent) {
      for (final hold in _held.toList()) {
        if (hold.activator.trigger == event.logicalKey) {
          _held.remove(hold);
          hold.onReleased!();
          return KeyEventResult.handled;
        }
      }
      return KeyEventResult.ignored;
    }
    final typing = _typing;
    final focusedElsewhere = primaryFocus != _node;
    for (final binding in widget.bindings) {
      final trigger = binding.activator.trigger;
      if (typing && !binding.whileTyping) continue;
      if (focusedElsewhere &&
          !typing &&
          (trigger == LogicalKeyboardKey.enter ||
              trigger == LogicalKeyboardKey.space)) {
        continue;
      }
      if (!binding.activator.accepts(event, HardwareKeyboard.instance)) {
        continue;
      }
      if (binding.onReleased != null) {
        if (event is KeyRepeatEvent || _held.contains(binding)) {
          return KeyEventResult.handled;
        }
        _held.add(binding);
      }
      binding.onPressed();
      return KeyEventResult.handled;
    }
    if (typing &&
        widget.scope &&
        event is KeyDownEvent &&
        event.logicalKey == LogicalKeyboardKey.escape) {
      primaryFocus?.unfocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  @override
  Widget build(BuildContext context) {
    final node = _node;
    return node is FocusScopeNode
        ? FocusScope(
            node: node,
            autofocus: true,
            onKeyEvent: _onKeyEvent,
            child: widget.child,
          )
        : Focus(
            focusNode: node,
            canRequestFocus: false,
            skipTraversal: true,
            onKeyEvent: _onKeyEvent,
            child: widget.child,
          );
  }
}
