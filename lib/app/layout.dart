import 'package:flutter/foundation.dart';
import 'package:material_ui/material_ui.dart';

/// A desktop: a mouse and keyboard are always there, and files can be
/// dropped (m3-design §3.3, §3.4).
bool get isDesktop => switch (defaultTargetPlatform) {
  TargetPlatform.macOS ||
  TargetPlatform.windows ||
  TargetPlatform.linux => true,
  _ => false,
};

/// Material's window size classes by width (m3-design §3.2). Phones are
/// [compact]; layouts change only from [medium] up, so the phone layout is
/// unchanged.
enum WindowWidth {
  /// Under 600 dp.
  compact,

  /// 600–839 dp.
  medium,

  /// 840 dp and up.
  expanded;

  static const mediumMin = 600.0;
  static const expandedMin = 840.0;

  static WindowWidth forWidth(double width) => width >= expandedMin
      ? expanded
      : width >= mediumMin
      ? medium
      : compact;

  /// The class of the window [context] is in.
  static WindowWidth of(BuildContext context) =>
      forWidth(MediaQuery.sizeOf(context).width);

  bool get isCompact => this == compact;
  bool get isExpanded => this == expanded;
}

/// Width cap for forms and text on wide windows (§3.2).
const formMaxWidth = 640.0;

/// Centers [child] at most [maxWidth] wide.
class MaxWidth extends StatelessWidget {
  const MaxWidth({
    super.key,
    this.maxWidth = formMaxWidth,
    required this.child,
  });

  final double maxWidth;
  final Widget child;

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: BoxConstraints(maxWidth: maxWidth),
      child: child,
    ),
  );
}

/// A full-screen editor page on black (crop, auto-crop review): [body]
/// fills the screen above [controls], which sit in the Scaffold's footer so
/// snackbars appear above them instead of covering them.
class EditorScaffold extends StatelessWidget {
  const EditorScaffold({super.key, required this.body, this.controls});

  final Widget body;
  final Widget? controls;

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    body: SafeArea(child: body),
    bottomNavigationBar: controls == null
        ? null
        : SafeArea(top: false, child: controls!),
  );
}
