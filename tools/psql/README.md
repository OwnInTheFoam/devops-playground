# PostgreSQL

Ensure OS username is not needed
```bash
sudo nano /etc/postgresql/16/main/pg_hba.conf
# Change the following from peer to md5:
local   all             postgres                                md5
local   all             all                                     md5
# Restart the system
sudo systemctl restart postgresql
```

Login to postgres
```bash
sudo -u postgres psql
# May have to: `sudo su - postgres` before login
ALTER USER postgres WITH PASSWORD '<new_password>';
# Create user
CREATE USER developer WITH PASSWORD '<new_password>';
CREATE DATABASE <new_database> OWNER developer;
```
