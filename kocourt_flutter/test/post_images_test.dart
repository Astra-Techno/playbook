import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt/screens/feed/post_images.dart';

void main() {
  test('a photo sent as image_url still shows on the feed', () {
    expect(
      postImageUrls({'image_url': ' https://cdn.example/a.jpg '}),
      ['https://cdn.example/a.jpg'],
    );
  });

  test('the feed gallery is shown', () {
    expect(
      postImageUrls({
        'images': ['https://cdn.example/b.jpg'],
        'image_url': 'https://cdn.example/b.jpg',
      }),
      ['https://cdn.example/b.jpg'],
    );
  });

  test('the post just created stays at the top of the feed', () {
    final posts = feedWithCreated(
      [
        {'id': '2', 'content': 'older'},
        {'id': 9, 'content': 'same'},
      ],
      {'id': '9', 'content': 'just posted'},
    );
    expect(posts.map((post) => '${post['id']}').toList(), ['9', '2']);
    expect(posts.first['content'], 'just posted');
  });
}
