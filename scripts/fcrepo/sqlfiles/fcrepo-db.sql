## Create fedora database in mariadb 
CREATE DATABASE IF NOT EXISTS fcrepo_db CHARACTER SET utf8 COLLATE utf8_general_ci;

# create root user and grant rights
CREATE USER IF NOT EXISTS 'fedora'@'%' IDENTIFIED BY 'fedora_pw';
GRANT ALL PRIVILEGES ON fcrepo_db.* to 'fedora'@'%';
FLUSH PRIVILEGES;
