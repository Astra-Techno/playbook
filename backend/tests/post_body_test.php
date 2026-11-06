<?php

require_once __DIR__ . '/../src/PostBody.php';

function expect_post($label, $condition) {
    if (!$condition) {
        fwrite(STDERR, "FAIL $label\n");
        exit(1);
    }
    echo "PASS $label\n";
}

$fromSingle = PostBody::images(['image_url' => ' https://cdn.example/a.jpg ']);
expect_post('a single photo is kept', $fromSingle === ['https://cdn.example/a.jpg']);

$fromList = PostBody::images(['images' => ['https://cdn.example/b.jpg', ''], 'image_url' => 'https://cdn.example/c.jpg']);
expect_post('a gallery and a single photo are combined', count($fromList) === 2);

expect_post('a text post has no photos', PostBody::images(['content' => 'Hello']) === []);
expect_post('a photo without text is still a post', PostBody::content(['content' => '  '], ['https://cdn.example/a.jpg']) === ' ');
expect_post('text is kept', PostBody::content(['content' => ' Hello '], []) === 'Hello');
expect_post('an empty post is rejected', PostBody::content(['content' => ''], []) === '');
expect_post('a short photo url is stored on the old column', PostBody::legacyImageUrl(['https://cdn.example/a.jpg']) === 'https://cdn.example/a.jpg');
expect_post('a long photo url is left to the images column', PostBody::legacyImageUrl([str_repeat('a', 256)]) === null);

echo "post body ok\n";
