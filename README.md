# Scaleway Volume Backup to Object Storage
This project provides an automated way to:

- **Create a daily snapshot of a Scaleway block volume
- **Export it to Scaleway Object Storage (S3-compatible)
- **Run via Scaleway Serverless Jobs
- **Secure credentials using Secret Manager

---

## Requirements
Before running the script, ensure you have:
- **Scaleway account
Create API credentials and save your SCW_ACCESS_KEY and SCW_SECRET_KEY.
https://console.scaleway.com/project/credentials
- **Project + Organization
- **Block volume to back up
- **Object Storage bucket for storing snapshots
- **Secret Manager enabled enabled

---

## Getting Started
Create and store your secrets to secret manager using Scaleway console or CLI.
```
scw secret create name=access-key 
scw secret create name=secret-key 
scw secret create name=project-id 
scw secret create name=organization-id
```
Then build the image and push it to registry :
```
docker build -t backup-scw-vol .
docker login rg.fr-par.scw.cloud/my-namespace \ -u nologin \ -p "$SCW_SECRET_KEY" 
docker tag backup-scw-vol \ rg.fr-par.scw.cloud/my-namespace/backup-scw-vol:latest 
docker push \ rg.fr-par.scw.cloud/my-namespace/backup-scw-vol:latest
```
Deploy the Serverless job to automate the snapshots creation.
1. Create job in Scaleway Console
2. Use image:
    rg.fr-par.scw.cloud/my-namespace/backup-scw-vol:latest
3. Attach Secret Manager secrets to the job:
    access-key
    secret-key
    project-id
    organization-id
4. Add env vars:
    SCW_DEFAULT_REGION=fr-par
    SCW_DEFAULT_ZONE=fr-par-1
    VOLUME_ID=your_volume_id
    BUCKET_NAME=my-backup
5. Schedule:
    0 6 * * * (Run every day at 06:00)

---

## How to restore ?
To restore a snapshot from Object Storage, follow the official Scaleway documentation:
https://www.scaleway.com/en/docs/instances/api-cli/snapshot-import-export-feature/
Note: Restoration can be performed in a different availability zone from the original volume.