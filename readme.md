# HestiaCP in Docker

**Warning:** The project is still in development and may have issues. Use at your own risk.

* **[Docker Hub](https://hub.docker.com/r/jhmaverick/hestiacp)**
* **[Github](https://github.com/jhmaverick/hestiacp-docker)**
* **[Hestia Project](https://hestiacp.com/)**


## How to use this image

```bash
wget https://raw.githubusercontent.com/jhmaverick/hestiacp-docker/main/docker-compose.yml
HSTC_HOSTNAME="example.com" docker-compose up -d
```

A random password will be generated for the admin user and will be displayed in the container logs on first run.

**Note:** MariaDB runs in a separate container to optimize initialization time for the main container. 
To connect to MariaDB in applications it is necessary to replace `localhost` with `mariadb` in the connection host.


## Build your own image

The `docker-helper` used in the project is just a layer for docker-compose that makes it possible to use variables for different environments, custom scripts and hooks. It depends on docker and docker-compose being installed and must be run with `bash docker-helper` or `./docker-helper`.

All configurations for building, running and pushing the images can be found in the `docker-helper.yml` in the project root.

### Build image

Run the build script informing the name of the image that will be built.
```bash
./docker-helper image-build <image>
```

Example:
```bash
./docker-helper image-build stable
```

### Run image

Start services using stable image:
```bash
./docker-helper up
```

Start services using another image:
```bash
./docker-helper image-up <image>
```

Example:
```bash
./docker-helper image-up experimental
```

### Local Access
Admin URL: https://hestiacp.localhost:8083  
Username:  admin  
Password:  admin

### Push image

Run the push script by entering the image name defined in `docker-helper.yml`.
```bash
./docker-helper image-push <image> <all|version|latest|<any>>
```

#### Example:
Push stable image with latest and version:
```bash
./docker-helper image-push stable all
```


## Volumes

* **/conf** Persistent data.
* **/home** All data from users.
* **/backup** Backups. Include backups from users, system credentials and daily backups from `/conf`.

### Initial data

* **/conf-start** Data for initialize `/conf`.
* **/home-start** Data for initialize `/home`.


## Variables

### General
* **DOCKER_REPOSITORY** Docker repository for building and pulling images.

### Container
* **HSTC_HOSTNAME** Sets the hostname of the Hestia container.
* **MAIL_ADMIN** Change mail from admin account in the first running.
* **AUTOSTART_DISABLED** Disable services on container startup. Ex: "clamav-daemon,ssh,vsftpd".

## Build
* **HESTIACP_REPOSITORY** Hestia project git that will be used in the build.
* **MULTIPHP_VERSIONS** Defines the PHP versions that will be installed in the build.
* **MARIADB_CLIENT_VERSION** Defines the version of the MariaDB client that will be installed.


## Known Issues

### Build terminating for no apparent reason

Rerun the build with the `--no-cache` option. Ex: `./docker-helper image-build stable --no-cache`.  
If that doesn't solve the problem, check the zlib version in the "hst_autocompile.sh". When a new version of zlib is released, the old one is removed from the official website causing an error when compiling. You can update the version by adding the variable "ZLIB_VERSION" in the .env in the project root or by updating in the hst_autocompile.sh.

### The data directory cannot be deleted

Run `./docker-helper fix-data-chattr` and try again
