<?php

require_once __DIR__ . '/../../config/database.php';

class User {
    private $conn;
    private $table_name = "users";

    public $id;
    public $name;
    public $email;
    public $password;
    public $phone;
    public $role;

    public function __construct() {
        $this->conn = Database::getConnection();
    }

    public function create() {
        $query = "INSERT INTO " . $this->table_name . "
                SET
                    name = :name,
                    email = :email,
                    password = :password,
                    phone = :phone,
                    role = :role";

        $stmt = $this->conn->prepare($query);

        // sanitize
        $this->name = htmlspecialchars(strip_tags($this->name));
        $this->phone = htmlspecialchars(strip_tags($this->phone));
        $this->role = htmlspecialchars(strip_tags($this->role));

        // Phone-only auth: generate a unique placeholder email so NOT NULL constraint is satisfied
        $this->email = !empty($this->email)
            ? htmlspecialchars(strip_tags($this->email))
            : $this->phone . '@playbook.local';
        $this->password = !empty($this->password)
            ? htmlspecialchars(strip_tags($this->password))
            : '';

        // bind
        $stmt->bindParam(":name", $this->name);
        $stmt->bindParam(":email", $this->email);
        $stmt->bindParam(":password", $this->password);
        $stmt->bindParam(":phone", $this->phone);
        $stmt->bindParam(":role", $this->role);

        if ($stmt->execute()) {
            return true;
        }
        return false;
    }

    public function phoneExists() {
        $query = "SELECT id, name, role FROM " . $this->table_name . " WHERE phone = ? LIMIT 0,1";
        $stmt = $this->conn->prepare($query);
        $stmt->bindParam(1, $this->phone);
        $stmt->execute();
        $num = $stmt->rowCount();

        if ($num > 0) {
            $row = $stmt->fetch(PDO::FETCH_ASSOC);
            $this->id = $row['id'];
            $this->name = $row['name'];
            $this->role = $row['role'];
            return true;
        }
        return false;
    }
}
