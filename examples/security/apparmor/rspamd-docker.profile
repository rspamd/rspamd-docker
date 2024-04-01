#include <tunables/global>

profile rspamd-docker {
  #include <abstractions/base>
  #include <abstractions/nameservice>
  #include <abstractions/openssl>
  #include <abstractions/ssl_certs>

  owner /dev/shm/* rw,
  /etc/magic r,
  /etc/magic.mime r,
  /etc/rspamd/** r,
  /sys/kernel/mm/transparent_hugepage/enabled r,
  /usr/bin/rspamd mr,
  /usr/share/rspamd/** r,
  /var/lib/rspamd/ r,
  /var/lib/rspamd/** rwk,
}
