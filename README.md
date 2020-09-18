# Nominatim for Kubernetes

[Nominatim](https://github.com/openstreetmap/Nominatim) for Kubernetes on Google Container Engine (GKE).

This chart provides a starting point for running a nominatim service within kubernetes.
## Supported tags and respective `Dockerfile` links

- [`2.6.1`, `2.6`, `latest`, `2.6.1-nominatim3.5.1`, `2.6-nominatim3.5.1`, `latest-nominatim3.5.1`  (*2.6/Dockerfile*)](https://github.com/peter-evans/nominatim-docker/tree/v2.6.1)
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
```bash
docker logs -f <CONTAINER ID>
```
Then point your web browser to [http://localhost:8080/](http://localhost:8080/)

## Kubernetes Deployment
[Nominatim](https://github.com/openstreetmap/Nominatim)'s data import from the PBF file into PostgreSQL can take hours or days depending on what you are deploying. It is therefore ***highly*** recommended to run with an external postgresql database.

### Warnings

 - While the container can run and install using a local database this is not recommended and intended for development purposes only. In this configuration PostgreSQL's data directory is archived in storage and with appropriate configuration for gcp can be uploaded/downloaded as required.
  - The module requirements for nominatim do not allow for running on cloud hosted postgres servers
  - It is also recommended that you backup the postgres database once loaded via pg_dump/pg_restore in case of failure to make recovery quicker

### Explanation

#### Installing Chart
- `helm repo add jobvite-nominatim https://jobvite-inc.github.io/nominatim-k8s`
- `helm install jobvite-nominatim/nominatim -n nominatim`
-
#### External Database

 1. Bring up your postgresql database and copy the appropriate version of the nominatim.so file to the database server.
 2.  [Chart Install](#Installing Chart)

#### Internal Database
Initial deployment flow:

1. Create a secret that contains the JSON key of a Google Cloud IAM service account that has read/write permissions to Google Storage.
2. Deploy the canary deployment.
3. Wait for the database to be created and its archive uploaded to Google Storage.
4. Delete the canary deployment.
5. Deploy the stable track deployment.

To update the live deployment with new PBF data:
1. Change replica count
2. Wait for the database to be created and its archive uploaded to Google Storage.
4. Perform a rolling update on the stable track deployment to create pods using the new database.

### Creating the secret

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

## Parameters

The following table lists the configurable parameters of the PostgreSQL HA chart and the default values. They can be configured in `values.yaml` or set via `--set` flag during installation.

| Parameter                                      | Description                                                                                                                                                          | Default                                                      |
| ---------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------------- | ------------------------------------------------------------ |
| **Global**                                     |                                                                                                                                                               |                                                              |
| `resourceType`                         | Type of deployment to do. Options: deployment, statefulset                                                                                                                                         | `deployment`
| `image.repository`                         | Source for the Images to be pulled from                                                                                                                                          | `peterevans/nominatim-k8s`
| `image.tag`                         | Tag to pull                                                                                                                                          | `latest`
| `replicas`                         | Number of instances to create                                                                                                                                          | `1`
| `nominatim.mode`                         | Init container startup mode. Options: CREATE, RESTORE, SKIP                                                                                                                                         | `CREATE`
| `nominatim.extraEnvVars`                         | Environment variables to pass to the containers                                                                                                                                         | `nil`
| `nominatim.config.local`                         | Overrides for default properties in nominatim is loaded with                                                                                                                                         | `[]`
| `postgres.version`                         | postgresql version available from the container                                                                                                                                         | `9.5`
| `postgres.postgis`                         | postgresql-postgis version available from the container                                                                                                                                         | `2.2`
| `ingress.serviceType`                         | Ingress type to leverage                                                                                                                                          | `ClusterIP`
| `ingress.enabled`                         | Enable the use of the ingress controller to access the web UI                                                                                                                                          | `false`
| `ingress.annotations`                         | Annotations for the Nominatim Ingress                                                                                                                                          | `{}`
| `ingress.hosts`                         | Hostname to your Nominatim installation                                                                                                                                          | `[]`
| `ingress.tls`                         | Utilize TLS backend in ingress                                                                                                                                          | `[]`
| `persistence.enabled`                         | Enable a pvc for storage                                                                                                                                          | `false`
| `persistence.accessModes`                         | The modes supported by the persistent volume                                                                                                                                        | `ReadWriteOnce`
| `persistence.size`                         | Size of the Persistent volume to create                                                                                                                                          | `8Gi`
| `volumes.nominatim-secret-volume.secretname`                         |                                                                                                                                          | `nominatim-storage-secret`
| `volumes.nominatim-secret-volume.type`                         |                                                                                                                                          | `secret`
| `volumes.local-data.path`                         |                                                                                                                                          | `data`
| `volumes.local-data.hostpath_type`                         |                                                                                                                                          | `DirectoryOrCreate`
| `volumes.local-data.type`                         |                                                                                                                                          | `hostPath`
| `volumes.nominatim-local-php.type`                         |                                                                                                                                           | `configMap`



## Thanks
Special thanks to [Peter Evans](https://github.com/peter-evans/nominatim-k8s) for creating nominatim-k8s.
## License

MIT License - see the [LICENSE](LICENSE) file for details
