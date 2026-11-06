/// Photos on a community post. The list used to drop `image_url` and
/// return `images`, while New Post sent only `image_url`.
List<String> postImageUrls(Map post) {
  final urls = <String>[];
  final raw = post['images'];
  if (raw is List) {
    for (final item in raw) {
      final url = '$item'.trim();
      if (url.isNotEmpty && url != 'null') urls.add(url);
    }
  } else if (raw is String && raw.trim().isNotEmpty) {
    urls.add(raw.trim());
  }
  final one = post['image_url'];
  if (one != null) {
    final url = '$one'.trim();
    if (url.isNotEmpty && url != 'null' && !urls.contains(url)) {
      urls.insert(0, url);
    }
  }
  return urls;
}

/// Put a post the player just created at the top, without duplicating it.
List<Map<String, dynamic>> feedWithCreated(
  List<Map<String, dynamic>> posts,
  Map? created,
) {
  if (created == null || created['id'] == null) return posts;
  final post = Map<String, dynamic>.from(created);
  final next = posts.where((row) => '${row['id']}' != '${post['id']}').toList();
  return [post, ...next];
}
