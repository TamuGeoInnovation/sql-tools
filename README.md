# SQL Tools

This repository contains useful utility scripts for working with MSSQL databases. Additionally, it can be found and bundled as a container to make use of the tools in a containerized environment.

## Scripts

- `single-url-restore.sh` is a script that can be used to restore a database from a one or more striped URL's. It is useful for restoring a database from a URL without having to download the backup file first.
- `many-url-restore.sh` is a script that uses `single-url-restore.sh` to restore multiple databases into the same SQL server instance.

## Building Docker Image

The base image is based on the `mcr.microsoft.com/mssql-tools` to have the necessary tools to interact with the SQL server.

To build the docker image, run the following command:

```bash
docker build -t sql-tools .
```

## Running Docker Container

To run the docker container, run the following command:

```bash
docker run -it --rm sql-tools
```
