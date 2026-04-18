-- Google Places and other CDN URLs often exceed 255 characters.
ALTER TABLE courts MODIFY image_url TEXT NULL;
