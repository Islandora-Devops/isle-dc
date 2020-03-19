## Create fedora database in mariadb

# ? timing on this

$ mysql -u root -p
> create database fcrepo;
> create user 'user1'@'localhost' IDENTIFIED BY 'xyz';
> GRANT ALL PRIVILEGES ON fcrepo.* to 'user1'@'localhost';
> \q

mysql -u root -p$DB_ROOT_PASSWORD

create database $FCREPO_DB;
create user '$FCREPO_DB_USER'@'localhost' IDENTIFIED BY '$FCREPO_DB_USER_PW';
GRANT ALL PRIVILEGES ON fcrepo.* to 'fedora'@'localhost';
\q


JAVA_OPTS="${JAVA_OPTS} -Dfcrepo.modeshape.configuration=classpath:/config/jdbc-mysql/repository.json"
JAVA_OPTS="${JAVA_OPTS} -Dfcrepo.mysql.username=<username>"
JAVA_OPTS="${JAVA_OPTS} -Dfcrepo.mysql.password=<password>"
JAVA_OPTS="${JAVA_OPTS} -Dfcrepo.mysql.host=<default=localhost>"
JAVA_OPTS="${JAVA_OPTS} -Dfcrepo.mysql.port=<default=3306>"

## create SYN 