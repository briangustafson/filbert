import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

/// A link from a placeholder screen to another route.
typedef PlaceholderLink = ({String label, String location});

/// Temporary screen used by every M1 route until its real UI is built
/// (M1 T4 onwards). Shows the route's parameters and links onward.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({
    super.key,
    required this.title,
    this.details = const [],
    this.links = const [],
  });

  final String title;
  final List<String> details;
  final List<PlaceholderLink> links;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          for (final detail in details)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(detail),
            ),
          for (final link in links)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: FilledButton.tonal(
                onPressed: () => context.go(link.location),
                child: Text(link.label),
              ),
            ),
        ],
      ),
    );
  }
}
