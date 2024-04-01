## Example AppArmor profile for Rspamd Docker container

This is an example AppArmor profile for restricting the Rspamd Docker container. It might not be feature-complete: you should be prepared to deal with possible fallout by reviewing logs & making necessary changes. The profile is aimed merely at running Rspamd and doesn't support use-cases such as logging in to the container.

### Usage

```
sudo cp rspamd-docker.profile /etc/apparmor.d/
sudo systemctl reload apparmor
docker run -v rspamd_dbdir:/var/lib/rspamd --security-opt apparmor=rspamd-docker -ti rspamd/rspamd
```
