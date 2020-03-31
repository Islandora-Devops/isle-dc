## Create gemini database in mariadb 
CREATE DATABASE IF NOT EXISTS gemini CHARACTER SET utf8 COLLATE utf8_general_ci;

CREATE TABLE IF NOT EXISTS gemini.Gemini (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    drupal VARCHAR(2048) NOT NULL UNIQUE,
    fedora VARCHAR(2048) NOT NULL UNIQUE
) ENGINE=InnoDB;

# create gemini_user and grant rights
CREATE USER IF NOT EXISTS 'gemini'@'%' IDENTIFIED BY 'gemini_pw';
GRANT ALL PRIVILEGES ON gemini.* to 'gemini'@'%';
FLUSH PRIVILEGES;