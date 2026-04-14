CREATE TABLE IF NOT EXISTS api_quota (
    id         INT AUTO_INCREMENT PRIMARY KEY,
    service    VARCHAR(50)  NOT NULL,
    month      CHAR(7)      NOT NULL COMMENT 'YYYY-MM',
    call_count INT          NOT NULL DEFAULT 0,
    alerted    TINYINT(1)   NOT NULL DEFAULT 0,
    UNIQUE KEY uq_service_month (service, month)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
