# SQL Tools

[![Docker Image](https://github.com/TamuGeoInnovation/sql-tools/actions/workflows/publish.yaml/badge.svg)](https://github.com/TamuGeoInnovation/sql-tools/actions/workflows/publish.yaml)

This repository contains useful utility scripts for working with MSSQL databases. Additionally, it can be found and bundled as a container to make use of the tools in a containerized environment.

## Single URL Restore

- `single-url-restore.sh` is a script that can be used to restore a database from a single azure blob url or or multiple, in the case of striped backups. It is useful for restoring a database from a URL without having to download the backup file first.

### Parameters

- `s` - SAS token to access the blob storage. This is used to create a database credential to access the blob storage.
- `c` - The URL to the azure blob container where the backup is stored. This is used to create a database credential to access the blob storage. The URL should be in the format `https://<account>.blob.core.windows.net/<container>`. Be mindful of not including the trailing `/` in the URL.
- `b` - The URL to restore the database from. This can be a single URL or multiple URLs in a comma-delimited list in the case of striped backups.
- `d` - The database to restore the backup to.
- `h` - The hostname of the SQL server. This host must be accessible from the machine running the script. Defaults to `localhost`.
- `p` - The target database password of the `sa` user.
- `r` - Additional restore options to pass to the `RESTORE DATABASE` command.

## Many URL Restore

- `many-url-restore.sh` is a script that uses `single-url-restore.sh` to restore multiple databases into an SQL server.

### Parameters

- `j` - A stringified JSON object containing a collection of databases to restore. Each entry in the collection can have the following properties:
  - `containerUrl` - The URL to the azure blob container where the backup is stored. This is used to create a database credential to access the blob storage. The URL should be in the format `https://<account>.blob.core.windows.net/<container>`. Be mindful of not including the trailing `/` in the URL.
  - `urls` - A comma-separated list of URLs to restore the database from. This can be a single URL or multiple URLs in the case of striped backups.
  - `host` - The hostname of the SQL server. This host must be accessible from the machine running the script. Defaults to `localhost`.
  - `db` - The database to restore the backup to.
  - `restoreOptions` - A string containing additional restore options to pass to the `RESTORE DATABASE` command.
  - `sasKey` - The SAS key to use to access the blob storage. Optional: If not provided, script will attempt to use the global SAS token (`s`);
  - `pwd` - The target database password of the `sa` user. If not provided, script will attempt to use the global password (`p`).
- `p` - Global password for the `sa` user. This is useful when the password is the same for all databases entries.
- `s` - Global SAS token. This is useful when the SAS token is the same for all database entries.

An example `j` parameter can be found [here](./examples/many-url-restore.json).

**Note**: When omitting the global password and SAS token, it makes it possible to use the script to restore databases from different databases and storage containers that require different credentials.

## Docker Image

`docker pull ghcr.io/tamugeoinnovation/sql-tools:latest`

## Container Usage

The container can be used to run the scripts in a containerized environment. The scripts can be run by passing the necessary parameters to the container.

### Single URL Restore

```bash
docker run -it --rm ghcr.io/tamugeoinnovation/sql-tools:latest single-url-restore.sh -s <SAS_TOKEN> -c <CONTAINER_URL> -b <BACKUP_URL> -d <DATABASE_NAME> -p <PASSWORD>
```

### Many URL Restore

```bash
docker run -it --rm -v $(pwd)/examples:/examples ghcr.io/tamugeoinnovation/sql-tools:latest many-url-restore.sh -j "$(cat /examples/many-url-restore.json)" -p <PASSWORD>
```

## Building Docker Image

The base image is based on the `mcr.microsoft.com/mssql-tools` to have the necessary tools to interact with the SQL server.

To build the docker image, run the following command:

```bash
docker build -t sql-tools .
```
