# Nominatim for Kubernetes
[![](https://images.microbadger.com/badges/image/peterevans/nominatim-k8s.svg)](https://microbadger.com/images/peterevans/nominatim-k8s)
[![CircleCI](https://circleci.com/gh/peter-evans/nominatim-k8s/tree/master.svg?style=svg)](https://circleci.com/gh/peter-evans/nominatim-k8s/tree/master)

[Nominatim](https://github.com/openstreetmap/Nominatim) for Kubernetes on Google Container Engine (GKE).

This Docker image and sample Kubernetes configuration files are one solution to persisting Nominatim data and providing immutable deployments.

## Supported tags and respective `Dockerfile` links

- [`2.6.2`, `2.6`, `latest`, `2.6.2-nominatim3.5.2`, `2.6-nominatim3.5.2`, `latest-nominatim3.5.2`  (*2.6/Dockerfile*)](https://github.com/peter-evans/nominatim-docker/tree/v2.6.2)
- [`2.6.1`, `2.6.1-nominatim3.5.1`, `2.6-nominatim3.5.1`, `latest-nominatim3.5.1`  (*2.6/Dockerfile*)](https://github.com/peter-evans/nominatim-docker/tree/v2.6.1)
- [`2.6.0`, `2.6.0-nominatim3.5.0`, `2.6-nominatim3.5.0`, `latest-nominatim3.5.0`  (*2.6/Dockerfile*)](https://github.com/peter-evans/nominatim-docker/tree/v2.6.0)
- [`2.5.4`, `2.5`, `2.5.4-nominatim3.4.2`, `2.5-nominatim3.4.2`, `latest-nominatim3.4.2`  (*2.5/Dockerfile*)](https://github.com/peter-evans/nominatim-docker/tree/v2.5.4)

## Usage
The Docker image can be run standalone without Kubernetes:

```bash
docker run -d -p 8080:8080 \
-e NOMINATIM_PBF_URL='http://download.geofabrik.de/asia/maldives-latest.osm.pbf' \
--name nominatim peterevans/nominatim-k8s:latest
```
Tail the logs to verify the database has been built and Apache is serving requests:
```
docker logs -f <CONTAINER ID>
```
Then point your web browser to [http://localhost:8080/](http://localhost:8080/)

## Kubernetes Deployment
[Nominatim](https://github.com/openstreetmap/Nominatim)'s data import from the PBF file into PostgreSQL can take over an hour for a single country.
If a pod in a deployment fails, waiting over an hour for a new pod to start could lead to loss of service.

The sample Kubernetes files provide a means of persisting a single database in storage that is used by all pods in the deployment. 
Each pod having its own database is desirable in order to have no single point of failure. 
The alternative to this solution is to maintain a HA PostgreSQL cluster.

PostgreSQL's data directory is archived in storage and restored on new pods. 
While this may be a crude method of copying the database it is much faster than pg_dump/pg_restore and reduces the pod startup time.

#### Explanation
Initial deployment flow:

1. Create a secret that contains the JSON key of a Google Cloud IAM service account that has read/write permissions to Google Storage.
2. Deploy the canary deployment.
3. Wait for the database to be created and its archive uploaded to Google Storage.
4. Delete the canary deployment.
5. Deploy the stable track deployment.

To update the live deployment with new PBF data:

1. Deploy the canary deployment alongside the stable track deployment.
2. Wait for the database to be created and its archive uploaded to Google Storage.
3. Delete the canary deployment.
4. Perform a rolling update on the stable track deployment to create pods using the new database.

#### Creating the secret

```bash
# Google Cloud project ID and service account details
PROJECT_ID=my-project
SA_NAME=my-service-account
SA_DISPLAY_NAME="My Service Account"
SA_EMAIL=$SA_NAME@$PROJECT_ID.iam.gserviceaccount.com
KEY_FILE=service-account-key.json

# Create a new GCP IAM service account
gcloud iam service-accounts create $SA_NAME --display-name "$SA_DISPLAY_NAME"

# Create and download a new key for the service account
gcloud iam service-accounts keys create $KEY_FILE --iam-account $SA_EMAIL

# Give the service account the "Storage Object Viewer" and "Storage Object Creator" IAM roles
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$SA_EMAIL --role roles/storage.objectViewer
gcloud projects add-iam-policy-binding $PROJECT_ID --member serviceAccount:$SA_EMAIL --role roles/storage.objectCreator

# Create a secret containing the service account key file
kubectl create secret generic nominatim-storage-secret --from-file=$KEY_FILE
```  

#### Deployment configuration
Before deploying, edit the `env` section of both the canary deployment and stable track deployment.

- `NOMINATIM_MODE` - `CREATE` from PBF data, or `RESTORE` from Google Storage.
- `NOMINATIM_PBF_URL` - URL to PBF data file. (Optional when `NOMINATIM_MODE=RESTORE`)
- `NOMINATIM_DATA_LABEL` - A meaningful and **unique** label for the data. e.g. maldives-20161213
- `NOMINATIM_SA_KEY_PATH` - Path to the JSON service account key. This needs to match the `mountPath` of the volume mounted secret.
- `NOMINATIM_PROJECT_ID` - Google Cloud project ID.
- `NOMINATIM_GS_BUCKET` - Google Storage bucket.
- `NOMINATIM_PG_THREADS` - Number of threads available for PostgreSQL. Defaults to 2.

## License

MIT License - see the [LICENSE](LICENSE) file for details
