/// Photos waiting for the auto-crop review after being added (m1-design
/// §3.6), carried in the review route's query so nothing global holds it:
/// `?queue=<id>,<id>&of=<total>`.
class ReviewQueue {
  /// [total] must be more than [remaining]'s length.
  const ReviewQueue({required this.remaining, required this.total});

  /// The queue for reviewing [imageIds] in order, at the first one.
  factory ReviewQueue.start(List<String> imageIds) =>
      ReviewQueue(remaining: imageIds.skip(1).toList(), total: imageIds.length);

  /// Images still to review after the current one.
  final List<String> remaining;

  /// Images in the whole queue.
  final int total;

  /// The current image's place in the queue, from 1.
  int get position => total - remaining.length;

  bool get isLast => remaining.isEmpty;

  /// The queue at the next image ([remaining]'s first).
  ReviewQueue get advanced =>
      ReviewQueue(remaining: remaining.skip(1).toList(), total: total);

  Map<String, String> toQuery() => {
    if (remaining.isNotEmpty) 'queue': remaining.join(','),
    'of': '$total',
  };

  /// Null unless [query] holds a valid queue.
  static ReviewQueue? fromQuery(Map<String, String> query) {
    final total = int.tryParse(query['of'] ?? '');
    if (total == null) return null;
    final ids = query['queue'];
    final remaining = ids == null || ids.isEmpty
        ? const <String>[]
        : ids.split(',');
    if (total <= remaining.length) return null;
    return ReviewQueue(remaining: remaining, total: total);
  }

  @override
  bool operator ==(Object other) =>
      other is ReviewQueue &&
      other.total == total &&
      other.remaining.join(',') == remaining.join(',');

  @override
  int get hashCode => Object.hash(total, Object.hashAll(remaining));
}
