# HestiaCP in Docker

## Dependencies

* Docker 20+
* Docker Compose 19.03+


## Volumes

* **/conf** Saves all settings that must be kept.
* **/home** All data from users.
* **/backup** Backups. Include backups from users, system credentials and daily backups from `/conf`.

### Initial data

* **/conf-start** Data for initialize `/conf`.
* **/home-start** Data for initialize `/home`.
