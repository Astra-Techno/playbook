<?php

require_once __DIR__ . '/env.php';

class Database {
    private static $instance = null;
    private $pdo;

    // Bump this number whenever migrate() adds new tables/columns/indexes
    private const SCHEMA_VERSION = 15;

    private function __construct() {
        $host    = getenv('DB_HOST') ?: 'localhost';
        $port    = getenv('DB_PORT') ?: '3306';
        $db      = getenv('DB_NAME') ?: 'playbook';
        $user    = getenv('DB_USER') ?: 'root';
        $pass    = (getenv('DB_PASS') !== false) ? getenv('DB_PASS') : '';
        $charset = 'utf8mb4';

        // dbname in DSN — on shared hosting the DB must already exist (create via cPanel)
        $dsn = "mysql:host=$host;port=$port;dbname=$db;charset=$charset";
        $options = [
            PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,
            PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,
            PDO::ATTR_EMULATE_PREPARES   => false,
        ];

        try {
            $this->pdo = new PDO($dsn, $user, $pass, $options);
            $this->migrate();
        } catch (\PDOException $e) {
            die(json_encode(['status' => 'error', 'message' => 'Database Connection Failed: ' . $e->getMessage()]));
        }
    }

    private function migrate() {
        // Version guard — create version table and skip if already current
        $this->pdo->exec("CREATE TABLE IF NOT EXISTS schema_version (version INT NOT NULL DEFAULT 0) ENGINE=InnoDB");
        $current = (int)$this->pdo->query("SELECT COALESCE(MAX(version),0) FROM schema_version")->fetchColumn();
        if ($current >= self::SCHEMA_VERSION) return;

        // Create tables if they don't exist
        $this->pdo->exec("
            CREATE TABLE IF NOT EXISTS users (
                id INT AUTO_INCREMENT PRIMARY KEY,
                name VARCHAR(255) NOT NULL,
                email VARCHAR(255) UNIQUE,
                password VARCHAR(255),
                phone VARCHAR(20) UNIQUE,
                role ENUM('admin', 'owner', 'player') DEFAULT 'player',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            )
        ");

        $this->pdo->exec("
            CREATE TABLE IF NOT EXISTS courts (
                id INT AUTO_INCREMENT PRIMARY KEY,
                owner_id INT NOT NULL,
                name VARCHAR(255) NOT NULL,
                type VARCHAR(50) NOT NULL DEFAULT 'other',
                description TEXT,
                location VARCHAR(255),
                hourly_rate DECIMAL(10, 2) NOT NULL,
                image_url TEXT,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
            )
        ");

        $this->pdo->exec("
            CREATE TABLE IF NOT EXISTS plans (
                id INT AUTO_INCREMENT PRIMARY KEY,
                court_id INT NOT NULL,
                name VARCHAR(255) NOT NULL,
                description TEXT,
                duration_days INT NOT NULL,
                price DECIMAL(10, 2) NOT NULL,
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (court_id) REFERENCES courts(id) ON DELETE CASCADE
            )
        ");

        $this->pdo->exec("
            CREATE TABLE IF NOT EXISTS bookings (
                id INT AUTO_INCREMENT PRIMARY KEY,
                user_id INT NOT NULL,
                court_id INT NOT NULL,
                start_time DATETIME NOT NULL,
                end_time DATETIME NOT NULL,
                type ENUM('hourly', 'subscription') NOT NULL,
                total_price DECIMAL(10, 2) NOT NULL,
                status ENUM('pending', 'confirmed', 'cancelled') DEFAULT 'confirmed',
                payment_status ENUM('pending', 'paid', 'failed') DEFAULT 'pending',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
                FOREIGN KEY (court_id) REFERENCES courts(id) ON DELETE CASCADE
            )
        ");

        // Add avatar_url column to users
        try { $this->pdo->exec("ALTER TABLE users ADD COLUMN avatar_url VARCHAR(255) DEFAULT NULL"); } catch (\PDOException $e) {}

        // Migrate existing users table: make email and password nullable if they aren't
        try {
            $this->pdo->exec("ALTER TABLE users MODIFY email VARCHAR(255) NULL");
            $this->pdo->exec("ALTER TABLE users MODIFY password VARCHAR(255) NULL");
            // Add unique constraint on phone if missing
            $this->pdo->exec("ALTER TABLE users ADD UNIQUE INDEX IF NOT EXISTS idx_phone (phone)");
        } catch (\PDOException $e) {
            // Ignore — column may already be nullable or index may already exist
        }

        // Migrate existing courts table: change type from ENUM to VARCHAR so all sport types work
        try {
            $this->pdo->exec("ALTER TABLE courts MODIFY type VARCHAR(50) NOT NULL DEFAULT 'other'");
        } catch (\PDOException $e) {
            // Ignore — already migrated
        }

        // GPS + operating hours + peak config columns for courts
        foreach ([
            "ALTER TABLE courts ADD COLUMN lat                DECIMAL(10,7) NULL",
            "ALTER TABLE courts ADD COLUMN lng                DECIMAL(10,7) NULL",
            "ALTER TABLE courts ADD COLUMN open_time          TIME DEFAULT '06:00:00'",
            "ALTER TABLE courts ADD COLUMN close_time         TIME DEFAULT '22:00:00'",
            "ALTER TABLE courts ADD COLUMN morning_peak_start TIME DEFAULT '05:00:00'",
            "ALTER TABLE courts ADD COLUMN morning_peak_end   TIME DEFAULT '09:00:00'",
            "ALTER TABLE courts ADD COLUMN evening_peak_start TIME DEFAULT '17:00:00'",
            "ALTER TABLE courts ADD COLUMN evening_peak_end   TIME DEFAULT '21:00:00'",
            "ALTER TABLE courts ADD COLUMN peak_members_only  TINYINT(1) DEFAULT 0",
            "ALTER TABLE courts ADD COLUMN claim_status       VARCHAR(20) DEFAULT NULL",
            "ALTER TABLE courts ADD COLUMN amenities          TEXT DEFAULT NULL",
        ] as $s) { try { $this->pdo->exec($s); } catch(\PDOException $e){} }

        // slot_type on plans (morning / evening / full_day / unlimited)
        try { $this->pdo->exec("ALTER TABLE plans ADD COLUMN slot_type VARCHAR(20) DEFAULT 'unlimited'"); } catch(\PDOException $e){}

        // user_subscriptions table
        $this->pdo->exec("CREATE TABLE IF NOT EXISTS user_subscriptions (
            id INT AUTO_INCREMENT PRIMARY KEY,
            user_id    INT NOT NULL,
            plan_id    INT NOT NULL,
            court_id   INT NOT NULL,
            slot_type  VARCHAR(20) DEFAULT 'unlimited',
            start_date DATE NOT NULL,
            end_date   DATE NOT NULL,
            status     ENUM('active','expired','cancelled') DEFAULT 'active',
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (user_id)  REFERENCES users(id)  ON DELETE CASCADE,
            FOREIGN KEY (plan_id)  REFERENCES plans(id)  ON DELETE CASCADE,
            FOREIGN KEY (court_id) REFERENCES courts(id) ON DELETE CASCADE
        )");
        foreach ([
            "ALTER TABLE user_subscriptions ADD COLUMN court_id  INT NOT NULL DEFAULT 0",
            "ALTER TABLE user_subscriptions ADD COLUMN slot_type VARCHAR(20) DEFAULT 'unlimited'",
        ] as $s) { try { $this->pdo->exec($s); } catch(\PDOException $e){} }

        // reviews table
        $this->pdo->exec("CREATE TABLE IF NOT EXISTS reviews (
            id         INT AUTO_INCREMENT PRIMARY KEY,
            court_id   INT NOT NULL,
            user_id    INT NOT NULL,
            booking_id INT NOT NULL,
            rating     TINYINT NOT NULL,
            comment    TEXT,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY idx_booking_review (booking_id),
            FOREIGN KEY (court_id)   REFERENCES courts(id)   ON DELETE CASCADE,
            FOREIGN KEY (user_id)    REFERENCES users(id)    ON DELETE CASCADE,
            FOREIGN KEY (booking_id) REFERENCES bookings(id) ON DELETE CASCADE
        )");

        // payments table — Cashfree orders linked to bookings/subscriptions
        $this->pdo->exec("CREATE TABLE IF NOT EXISTS payments (
            id              INT AUTO_INCREMENT PRIMARY KEY,
            user_id         INT NOT NULL,
            cf_order_id     VARCHAR(100) NOT NULL,
            cf_payment_id   VARCHAR(100) DEFAULT NULL,
            amount          DECIMAL(10,2) NOT NULL,
            currency        VARCHAR(10) DEFAULT 'INR',
            type            ENUM('booking','subscription') NOT NULL,
            payload         TEXT,
            status          ENUM('created','paid','failed','refund_pending') DEFAULT 'created',
            reference_id    INT DEFAULT NULL,
            created_at      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY idx_cf_order (cf_order_id)
        )");

        // Migrate old Razorpay columns to Cashfree columns (for existing installs)
        foreach ([
            "ALTER TABLE payments CHANGE razorpay_order_id   cf_order_id   VARCHAR(100) NOT NULL",
            "ALTER TABLE payments CHANGE razorpay_payment_id cf_payment_id VARCHAR(100) DEFAULT NULL",
            "ALTER TABLE payments DROP INDEX idx_rz_order",
            "ALTER TABLE payments ADD UNIQUE KEY idx_cf_order (cf_order_id)",
        ] as $s) { try { $this->pdo->exec($s); } catch(\PDOException $e){} }

        // payouts table — admin records manual payouts to owners
        $this->pdo->exec("CREATE TABLE IF NOT EXISTS payouts (
            id         INT AUTO_INCREMENT PRIMARY KEY,
            owner_id   INT NOT NULL,
            amount     DECIMAL(10,2) NOT NULL,
            note       VARCHAR(255) DEFAULT NULL,
            paid_at    TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (owner_id) REFERENCES users(id) ON DELETE CASCADE
        )");

        // favorites table
        $this->pdo->exec("CREATE TABLE IF NOT EXISTS favorites (
            id         INT AUTO_INCREMENT PRIMARY KEY,
            user_id    INT NOT NULL,
            court_id   INT NOT NULL,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            UNIQUE KEY idx_user_court (user_id, court_id),
            FOREIGN KEY (user_id)  REFERENCES users(id)  ON DELETE CASCADE,
            FOREIGN KEY (court_id) REFERENCES courts(id) ON DELETE CASCADE
        )");

        // New feature columns — courts
        foreach ([
            "ALTER TABLE courts ADD COLUMN amenities    JSON          NULL",
            "ALTER TABLE courts ADD COLUMN is_verified  TINYINT(1)    DEFAULT 0",
        ] as $s) { try { $this->pdo->exec($s); } catch(\PDOException $e){} }

        // New feature columns — users
        foreach ([
            "ALTER TABLE users ADD COLUMN bio               TEXT          NULL",
            "ALTER TABLE users ADD COLUMN skill_level       ENUM('beginner','intermediate','advanced') NULL",
            "ALTER TABLE users ADD COLUMN sport_preferences JSON          NULL",
        ] as $s) { try { $this->pdo->exec($s); } catch(\PDOException $e){} }

        // New feature columns — reviews
        foreach ([
            "ALTER TABLE reviews ADD COLUMN owner_reply    TEXT      NULL",
            "ALTER TABLE reviews ADD COLUMN owner_reply_at TIMESTAMP NULL",
        ] as $s) { try { $this->pdo->exec($s); } catch(\PDOException $e){} }

        // court_photos table
        $this->pdo->exec("CREATE TABLE IF NOT EXISTS court_photos (
            id         INT AUTO_INCREMENT PRIMARY KEY,
            court_id   INT NOT NULL,
            url        VARCHAR(500) NOT NULL,
            sort_order INT DEFAULT 0,
            created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (court_id) REFERENCES courts(id) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

        // ── Indexes on high-traffic columns ──────────────────────────────────────
        foreach ([
            "ALTER TABLE bookings          ADD INDEX idx_bookings_user   (user_id)",
            "ALTER TABLE bookings          ADD INDEX idx_bookings_court  (court_id)",
            "ALTER TABLE bookings          ADD INDEX idx_bookings_time   (start_time)",
            "ALTER TABLE user_subscriptions ADD INDEX idx_usub_user      (user_id)",
            "ALTER TABLE user_subscriptions ADD INDEX idx_usub_court     (court_id)",
            "ALTER TABLE courts            ADD INDEX idx_courts_owner    (owner_id)",
            "ALTER TABLE courts            ADD INDEX idx_courts_latng    (lat, lng)",
            "ALTER TABLE reviews           ADD INDEX idx_reviews_court   (court_id)",
            "ALTER TABLE reviews           ADD INDEX idx_reviews_user    (user_id)",
            "ALTER TABLE favorites         ADD INDEX idx_fav_user        (user_id)",
        ] as $s) { try { $this->pdo->exec($s); } catch(\PDOException $e){} }

        // messages table
        $this->pdo->exec("CREATE TABLE IF NOT EXISTS messages (
            id          INT AUTO_INCREMENT PRIMARY KEY,
            booking_id  INT NOT NULL,
            sender_id   INT NOT NULL,
            receiver_id INT NOT NULL,
            body        TEXT NOT NULL,
            is_read     TINYINT(1) DEFAULT 0,
            created_at  TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            FOREIGN KEY (booking_id)  REFERENCES bookings(id) ON DELETE CASCADE,
            FOREIGN KEY (sender_id)   REFERENCES users(id)    ON DELETE CASCADE,
            FOREIGN KEY (receiver_id) REFERENCES users(id)    ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci");

        // auth_token column for server-side token validation
        try { $this->pdo->exec("ALTER TABLE users ADD COLUMN auth_token VARCHAR(64) DEFAULT NULL"); } catch(\PDOException $e){}
        try { $this->pdo->exec("ALTER TABLE users ADD INDEX idx_auth_token (auth_token)"); } catch(\PDOException $e){}

        // Google Places / CDN image URLs exceed VARCHAR(255) (e.g. court claim from place photo_reference)
        try { $this->pdo->exec("ALTER TABLE courts MODIFY image_url TEXT NULL"); } catch(\PDOException $e){}

        // Sub-court peak override + richer blocks (v15)
        foreach ([
            "ALTER TABLE sub_courts ADD COLUMN peak_members_override TINYINT(1) NULL DEFAULT NULL COMMENT 'NULL=inherit court,0=open at peak,1=members at peak'",
            "ALTER TABLE blocked_slots ADD COLUMN block_kind VARCHAR(32) NOT NULL DEFAULT 'other'",
            "ALTER TABLE blocked_slots ADD COLUMN repeat_annually TINYINT(1) NOT NULL DEFAULT 0",
        ] as $s) { try { $this->pdo->exec($s); } catch(\PDOException $e) {} }

        // Stamp schema version
        $this->pdo->exec("DELETE FROM schema_version");
        $this->pdo->exec("INSERT INTO schema_version (version) VALUES (" . self::SCHEMA_VERSION . ")");
    }

    public static function getConnection() {
        if (self::$instance == null) {
            self::$instance = new Database();
        }
        return self::$instance->pdo;
    }
}
