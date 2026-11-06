<?php

/** Fields the community composer sends for a new post. */
class PostBody
{
    public static function images($data): array
    {
        if (!is_array($data)) {
            return [];
        }
        $imgs = $data['images'] ?? [];
        if (!is_array($imgs)) {
            $imgs = $imgs ? [$imgs] : [];
        }
        $single = trim((string)($data['image_url'] ?? ''));
        if ($single !== '') {
            $imgs[] = $single;
        }
        $clean = [];
        foreach ($imgs as $url) {
            $url = trim((string)$url);
            if ($url !== '') {
                $clean[] = $url;
            }
        }
        return array_values($clean);
    }

    /** A photo-only post still needs a non-empty content column. */
    public static function content(array $data, array $images): string
    {
        $content = trim((string)($data['content'] ?? ''));
        if ($content === '' && $images !== []) {
            return ' ';
        }
        return $content;
    }

    /** posts.image_url is VARCHAR(255) on older databases. Longer URLs stay in images. */
    public static function legacyImageUrl(array $images): ?string
    {
        if ($images === []) {
            return null;
        }
        $url = $images[0];
        if (strlen($url) > 255) {
            return null;
        }
        return $url;
    }
}
