<?php
require_once __DIR__ . '/../../config/database.php';

class PostController {
    private $db;
    public function __construct() {
        $this->db = Database::getConnection();
        // Auto-create tables if missing
        $this->db->exec("CREATE TABLE IF NOT EXISTS posts (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id INT NOT NULL,
            content TEXT NOT NULL,
            image_url VARCHAR(255),
            images TEXT,
            court_id INT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )");
        // Migrate: add images + tags columns to existing installs
        try { $this->db->exec("ALTER TABLE posts ADD COLUMN images TEXT"); } catch (\PDOException $e) {}
        try { $this->db->exec("ALTER TABLE posts ADD COLUMN tags TEXT"); } catch (\PDOException $e) {}
        try { $this->db->exec("ALTER TABLE posts ADD COLUMN visibility VARCHAR(20) NOT NULL DEFAULT 'public'"); } catch (\PDOException $e) {}
        try { $this->db->exec("ALTER TABLE posts ADD COLUMN booking_id INT DEFAULT NULL"); } catch (\PDOException $e) {}
        $this->db->exec("CREATE TABLE IF NOT EXISTS post_likes (
            id INT AUTO_INCREMENT PRIMARY KEY,
            post_id INT NOT NULL,
            user_id INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY unique_like (post_id, user_id),
            FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )");
        $this->db->exec("CREATE TABLE IF NOT EXISTS post_comments (
            id INT AUTO_INCREMENT PRIMARY KEY,
            post_id INT NOT NULL,
            user_id INT NOT NULL,
            content TEXT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (post_id) REFERENCES posts(id) ON DELETE CASCADE,
            FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE
        )");
    }

    // GET /posts?user_id=X  (user_id for is_liked check, optional)
    public function index() {
        $viewer_id = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;
        // Visibility filter:
        //   public   → all viewers
        //   only_me  → author only
        //   tagged   → author + users whose id appears in the tags JSON
        $stmt = $this->db->prepare("
            SELECT p.id, p.content, p.image_url, p.images, p.court_id, p.created_at,
                   p.visibility, p.booking_id,
                   u.id AS user_id, u.name AS user_name, u.avatar_url,
                   (SELECT COUNT(*) FROM post_likes WHERE post_id = p.id) AS likes_count,
                   (SELECT COUNT(*) > 0 FROM post_likes WHERE post_id = p.id AND user_id = :viewer) AS is_liked
            FROM posts p
            JOIN users u ON u.id = p.user_id
            WHERE (
                COALESCE(p.visibility,'public') = 'public'
                OR p.user_id = :viewer2
                OR (COALESCE(p.visibility,'public') = 'tagged'
                    AND p.tags IS NOT NULL
                    AND p.tags LIKE :tag_pattern)
            )
            ORDER BY p.created_at DESC
            LIMIT 50
        ");
        $tagPattern = '%\"id\":' . $viewer_id . '%';
        $stmt->execute([':viewer' => $viewer_id, ':viewer2' => $viewer_id, ':tag_pattern' => $tagPattern]);
        $posts = $stmt->fetchAll(PDO::FETCH_ASSOC);
        foreach ($posts as &$p) {
            $p['likes_count'] = (int)$p['likes_count'];
            $p['is_liked']    = (bool)$p['is_liked'];
            // Normalise images: prefer `images` JSON array, fall back to legacy image_url
            if (!empty($p['images'])) {
                $p['images'] = json_decode($p['images'], true) ?: [];
            } elseif (!empty($p['image_url'])) {
                $p['images'] = [$p['image_url']];
            } else {
                $p['images'] = [];
            }
            unset($p['image_url']);
        }
        echo json_encode(['records' => $posts]);
    }

    // GET /posts/:id?user_id=X
    public function show($id) {
        $viewer_id = isset($_GET['user_id']) ? (int)$_GET['user_id'] : 0;
        $stmt = $this->db->prepare("
            SELECT p.id, p.content, p.image_url, p.images, p.court_id, p.created_at,
                   u.id AS user_id, u.name AS user_name, u.avatar_url,
                   (SELECT COUNT(*) FROM post_likes WHERE post_id = p.id) AS likes_count,
                   (SELECT COUNT(*) > 0 FROM post_likes WHERE post_id = p.id AND user_id = :viewer) AS is_liked
            FROM posts p JOIN users u ON u.id = p.user_id
            WHERE p.id = :id
        ");
        $stmt->execute([':id' => $id, ':viewer' => $viewer_id]);
        $p = $stmt->fetch(PDO::FETCH_ASSOC);
        if (!$p) { http_response_code(404); echo json_encode(['message' => 'Post not found']); return; }
        $p['likes_count'] = (int)$p['likes_count'];
        $p['is_liked']    = (bool)$p['is_liked'];
        if (!empty($p['images']))    $p['images'] = json_decode($p['images'], true) ?: [];
        elseif (!empty($p['image_url'])) $p['images'] = [$p['image_url']];
        else $p['images'] = [];
        unset($p['image_url']);

        // Fetch comments
        $cStmt = $this->db->prepare("
            SELECT c.id, c.content, c.created_at, u.id AS user_id, u.name AS user_name, u.avatar_url
            FROM post_comments c
            JOIN users u ON u.id = c.user_id
            WHERE c.post_id = ?
            ORDER BY c.created_at ASC
        ");
        $cStmt->execute([$id]);
        $p['comments'] = $cStmt->fetchAll(PDO::FETCH_ASSOC);

        echo json_encode($p);
    }

    // POST /posts  { user_id, content, images?, court_id?, booking_id?, visibility?, tags? }
    public function create() {
        $data       = json_decode(file_get_contents('php://input'), true);
        $user_id    = (int)($data['user_id'] ?? 0);
        $content    = trim($data['content'] ?? '');
        $court_id   = isset($data['court_id'])   ? (int)$data['court_id']   : null;
        $booking_id = isset($data['booking_id']) ? (int)$data['booking_id'] : null;
        $visibility = in_array($data['visibility'] ?? '', ['public','only_me','tagged'])
                      ? $data['visibility'] : 'public';
        $tagsJson   = !empty($data['tags']) ? json_encode($data['tags']) : null;

        // Accept array of image URLs
        $imgs = $data['images'] ?? [];
        if (!is_array($imgs)) $imgs = $imgs ? [$imgs] : [];
        $imgs = array_values(array_filter(array_map('trim', $imgs)));
        $imagesJson = !empty($imgs) ? json_encode($imgs) : null;

        if (!$user_id || !$content) {
            http_response_code(400);
            echo json_encode(['message' => 'user_id and content are required']);
            return;
        }
        $stmt = $this->db->prepare(
            "INSERT INTO posts (user_id, content, images, court_id, booking_id, visibility, tags)
             VALUES (?, ?, ?, ?, ?, ?, ?)"
        );
        $stmt->execute([$user_id, $content, $imagesJson, $court_id, $booking_id, $visibility, $tagsJson]);
        $id = $this->db->lastInsertId();

        $stmt2 = $this->db->prepare(
            "SELECT p.*, u.name AS user_name, u.avatar_url FROM posts p JOIN users u ON u.id = p.user_id WHERE p.id = ?"
        );
        $stmt2->execute([$id]);
        $post = $stmt2->fetch(PDO::FETCH_ASSOC);
        $post['likes_count'] = 0;
        $post['is_liked']    = false;
        $post['images']      = $imgs;
        unset($post['image_url']);
        http_response_code(201);
        echo json_encode($post);
    }

    // DELETE /posts/:id  { user_id }
    public function delete($id) {
        $data    = json_decode(file_get_contents('php://input'), true);
        $user_id = (int)($data['user_id'] ?? 0);
        $stmt = $this->db->prepare("DELETE FROM posts WHERE id = ? AND user_id = ?");
        $stmt->execute([$id, $user_id]);
        if ($stmt->rowCount() === 0) {
            http_response_code(403); echo json_encode(['message' => 'Not found or not yours']); return;
        }
        echo json_encode(['message' => 'Deleted']);
    }

    // POST /posts/:id/like  { user_id }
    public function like($id) {
        $data    = json_decode(file_get_contents('php://input'), true);
        $user_id = (int)($data['user_id'] ?? 0);
        if (!$user_id) { http_response_code(400); echo json_encode(['message' => 'user_id required']); return; }

        // Toggle: try insert, if duplicate — delete
        try {
            $ins = $this->db->prepare("INSERT INTO post_likes (post_id, user_id) VALUES (?, ?)");
            $ins->execute([$id, $user_id]);
            $liked = true;
        } catch (PDOException $e) {
            $del = $this->db->prepare("DELETE FROM post_likes WHERE post_id = ? AND user_id = ?");
            $del->execute([$id, $user_id]);
            $liked = false;
        }
        $cnt = $this->db->prepare("SELECT COUNT(*) FROM post_likes WHERE post_id = ?");
        $cnt->execute([$id]);
        echo json_encode(['liked' => $liked, 'likes_count' => (int)$cnt->fetchColumn()]);
    }

    // POST /posts/:id/comment  { user_id, content }
    public function addComment($id) {
        $data    = json_decode(file_get_contents('php://input'), true);
        $user_id = (int)($data['user_id'] ?? 0);
        $content = trim($data['content'] ?? '');

        if (!$user_id || !$content) {
            http_response_code(400); echo json_encode(['message' => 'user_id and content required']); return;
        }

        $stmt = $this->db->prepare("INSERT INTO post_comments (post_id, user_id, content) VALUES (?, ?, ?)");
        $stmt->execute([$id, $user_id, $content]);
        $cid = $this->db->lastInsertId();

        $fetch = $this->db->prepare("
            SELECT c.id, c.content, c.created_at, u.id AS user_id, u.name AS user_name, u.avatar_url
            FROM post_comments c
            JOIN users u ON u.id = c.user_id
            WHERE c.id = ?
        ");
        $fetch->execute([$cid]);
        echo json_encode($fetch->fetch(PDO::FETCH_ASSOC));
    }
}
