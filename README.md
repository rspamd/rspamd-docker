# Rspamd Docker image 📨 🐋

## Basic usage

~~~
docker run -v rspamd_dbdir:/var/lib/rspamd -v rspamd_confdir:/etc/rspamd -ti rspamd/rspamd
~~~

## Configuration

In this build upstream config files are installed in `/usr/share/rspamd/config` allowing `/etc/rspamd` to contain only local configuration.

Volumes or bind mounts should be used for the `/var/lib/rspamd` directory and optionally for `/etc/rspamd`. If bind mounts are used, the `/var/lib/rspamd` directory should be writable by `11333:11333` on the host machine.

## Tags

| tag | description |
|-----|-------------|
| latest | latest stable release |
| 3.7 | latest stable release in 3.7 series |
| 3.7.4 | latest build of version 3.7.4 |

## Container orchestration

[Examples](https://github.com/rspamd/rspamd-docker/tree/main/examples) for Docker Compose & Kubernetes are available in-repo.

## Acknowledgements

The Fasttext [language identification model](https://fasttext.cc/docs/en/language-identification.html) used in this image is distributed under the [Creative Commons Attribution-Share-Alike License 3.0](https://creativecommons.org/licenses/by-sa/3.0/).

Rspamd is released under [version 2.0 of the Apache license](https://www.apache.org/licenses/LICENSE-2.0), see [debian/copyright](https://github.com/rspamd/rspamd/blob/master/debian/copyright) for a full list of applicable licenses.
