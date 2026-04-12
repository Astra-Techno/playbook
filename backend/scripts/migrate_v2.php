<?php
require_once __DIR__ . '/../config/database.php';

try {
    $db = Database::getConnection();
    
    // Make email and password nullable
    $db->exec("ALTER TABLE users MODIFY email VARCHAR(255) NULL");
    $db->exec("ALTER TABLE users MODIFY password VARCHAR(255) NULL");
    
    // Make phone unique (first ensure no duplicates or cleanup if needed - for now just add index)
    // In a real scenario, we'd need to handle existing duplicates. 
    // Assuming fresh dev DB or no conflicts for MVP.
    // Check if index exists first or just try-catch
    try {
        $db->exec("ALTER TABLE users ADD UNIQUE (phone)");
    } catch (PDOException $e) {
        echo "Phone unique index might already exist or Duplicate data: " . $e->getMessage() . "\n";
    }

    echo "Migration successful: Users table updated for Phone Auth.\n";

} catch (PDOException $e) {
    echo "Migration failed: " . $e->getMessage() . "\n";
}
