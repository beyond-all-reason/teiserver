## How to reset the database
It happens, you import the same data twice or in some way make a mistake. There are two things you can do next:

#### 1 - Restore from backup
Ideally you're using the provided backup script to create backups of your database on a regular basis. If you're not then you need to start.

Step 1: upload the database backup
```
scp -i ~/.ssh/id_rsa backup.tar.gz deploy@yourdomain.com:./restore.db
```

Step 2: Remote into the server
```
# Stop Teiserver running
sudo systemctl stop teiserver.service

# Swap to postgres
sudo su postgres
psql postgres postgres <<EOF
DROP DATABASE teiserver_prod;
CREATE DATABASE teiserver_prod;
GRANT ALL PRIVILEGES ON DATABASE teiserver_prod to teiserver_prod;
EOF

# Back to normal user
exit

# Restore the db
psql --user=teiserver_prod --dbname=teiserver_prod -f ./restore.db

# Start the service up again
sudo systemctl start teiserver.service
```

#### 2 - Restart from scratch
```
# Stop the service
sudo systemctl stop teiserver.service

# Next wipe and remake the database
sudo su postgres
psql postgres postgres <<EOF
DROP DATABASE teiserver_prod;
CREATE DATABASE teiserver_prod;
GRANT ALL PRIVILEGES ON DATABASE teiserver_prod to teiserver_prod;
EOF

# Return to normal user
exit

# Start the app back up
sudo systemctl start teiserver.service

# Run the migrations
teiserverapp eval "Teiserver.Release.migrate"

# Restart the app so it can build the initial data needed for various things
sudo systemctl restart teiserver.service
```

