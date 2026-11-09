# MongoDB Backup & Restoration Runbook

This runbook provides step-by-step operational procedures for automated scheduled backups and disaster recovery restoration of the MongoDB database running on Amazon EKS.

---

## 1. Backup Strategy Overview

- **Storage Engine:** MongoDB StatefulSet using AWS EBS gp3 storage (`ebs-gp3` StorageClass).
- **Automation:** Kubernetes CronJob ([`k8s/overlays/eks/mongodb-backup-cronjob.yaml`](../../k8s/overlays/eks/mongodb-backup-cronjob.yaml)) runs daily at `02:00 UTC`.
- **Archive Format:** Compressed binary gzip archive generated using `mongodump`.
- **Target Storage:** Remote Amazon S3 bucket with versioning and AES256 server-side encryption enabled.
- **Retention Policy:** S3 Lifecycle configuration expiring backups older than 30 days and transitioning archives older than 7 days to S3 Standard-IA (Infrequent Access).

---

## 2. On-Demand Manual Backup

To trigger an immediate backup before applying significant application updates or database schema modifications:

```bash
# 1. Exec into the MongoDB pod
kubectl exec -it mongodb-0 -n todo-app -- bash

# 2. Run mongodump to archive database
TIMESTAMP=$(date +%Y-%m-%d_%H-%M-%S)
mongodump \
  --username="${MONGO_INITDB_ROOT_USERNAME}" \
  --password="${MONGO_INITDB_ROOT_PASSWORD}" \
  --authenticationDatabase=admin \
  --db=tododb \
  --gzip \
  --archive="/tmp/manual-backup-${TIMESTAMP}.gz"

# 3. Copy archive to local machine
kubectl cp todo-app/mongodb-0:/tmp/manual-backup-${TIMESTAMP}.gz ./manual-backup-${TIMESTAMP}.gz

# 4. Clean up temporary archive on container
kubectl exec -it mongodb-0 -n todo-app -- rm -f "/tmp/manual-backup-${TIMESTAMP}.gz"
```

---

## 3. Disaster Recovery Restoration Procedure

In the event of database corruption, accidental document deletion, or pod storage loss:

### Step 1: Obtain the Target Backup Archive
Download the latest verified backup from Amazon S3:
```bash
aws s3 cp "s3://<BACKUP_BUCKET>/backups/<TARGET_BACKUP>.gz" ./restore-backup.gz
```

### Step 2: Copy Archive to the MongoDB Pod
```bash
kubectl cp ./restore-backup.gz todo-app/mongodb-0:/tmp/restore-backup.gz
```

### Step 3: Execute Restoration (`mongorestore`)
```bash
kubectl exec -it mongodb-0 -n todo-app -- bash -c '
  mongorestore \
    --username="${MONGO_INITDB_ROOT_USERNAME}" \
    --password="${MONGO_INITDB_ROOT_PASSWORD}" \
    --authenticationDatabase=admin \
    --db=tododb \
    --gzip \
    --drop \
    --archive="/tmp/restore-backup.gz"
'
```
*Note: The `--drop` flag replaces any corrupted or incomplete collections with the clean restored state.*

### Step 4: Verify Data Integrity
```bash
kubectl exec -it mongodb-0 -n todo-app -- mongosh -u "${MONGO_INITDB_ROOT_USERNAME}" -p "${MONGO_INITDB_ROOT_PASSWORD}" --authenticationDatabase admin --eval "use tododb; db.todos.countDocuments();"
```

### Step 5: Clean Up
```bash
kubectl exec -it mongodb-0 -n todo-app -- rm -f /tmp/restore-backup.gz
rm -f ./restore-backup.gz
```
