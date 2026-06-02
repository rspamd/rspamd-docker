# Rspamd Docker image 📨 🐋

[![release](https://github.com/rspamd/rspamd-docker/actions/workflows/release.yml/badge.svg)](https://github.com/rspamd/rspamd-docker/actions/workflows/release.yml)
[![nightly](https://github.com/rspamd/rspamd-docker/actions/workflows/nightly.yml/badge.svg)](https://github.com/rspamd/rspamd-docker/actions/workflows/nightly.yml)
[![security](https://github.com/rspamd/rspamd-docker/actions/workflows/security.yml/badge.svg)](https://github.com/rspamd/rspamd-docker/actions/workflows/security.yml)
[![refresh_latest](https://github.com/rspamd/rspamd-docker/actions/workflows/refresh_latest.yml/badge.svg)](https://github.com/rspamd/rspamd-docker/actions/workflows/refresh_latest.yml)

Official Docker image for [Rspamd](https://rspamd.com), a fast, free and
open-source spam filtering system. The image is built on `debian:trixie-slim`,
published for `linux/amd64` and `linux/arm64`, and runs as the unprivileged user
`11333:11333`.

The `latest` (and `MAJOR` / `MAJOR.MINOR`) tags are rebuilt daily so they pick up
the newest Debian security updates between Rspamd releases.

---

## Quick start

```sh
docker run -d --name rspamd \
  -v rspamd_data:/var/lib/rspamd \
  -p 127.0.0.1:11332:11332 \
  -p 127.0.0.1:11333:11333 \
  -p 127.0.0.1:11334:11334 \
  rspamd/rspamd
```

That starts Rspamd with its default configuration and persists learned data
(Bayes, fuzzy, etc.) in the `rspamd_data` volume. The web interface and admin
API are then available on <http://127.0.0.1:11334>.

> [!WARNING]
> The image binds every worker to **all** interfaces (`RSPAMD_LOCAL_ADDR=*`) so
> the container is reachable, and the controller ships with the well-known
> default password `q1`. Publish the controller port (`11334`) on a loopback
> address as shown above and **change the controller password** before exposing
> it — see [Securing the controller](#securing-the-controller).

---

## How configuration works

Rspamd merges configuration from three layers:

| Path | Purpose | Edit it? |
|------|---------|----------|
| `/usr/share/rspamd/config` | Upstream defaults shipped with the image | No — overwritten on update |
| `/etc/rspamd/local.d/*.conf` | Your settings, **merged** into the matching default section | Yes |
| `/etc/rspamd/override.d/*.conf` | Your settings, which **replace** the matching default section | Yes |

So you never edit the shipped defaults — you drop small `.conf` snippets into
`local.d` (to add/tweak keys) or `override.d` (to wipe and replace a section).
See the upstream docs on the
[local.d / override.d directories](https://rspamd.com/doc/faq.html#what-are-the-locald-and-overrided-directories).

There are three ways to get your configuration into the container, from simplest
to most production-ready:

1. **[Environment variables](#1-environment-variables)** — for the handful of
   knobs the image exposes (bind address, logging, ports).
2. **[Drop-in config files](#2-drop-in-config-files)** — bind-mount your
   `local.d`/`override.d` snippets for everything else.
3. **[A derived image](#3-a-derived-image)** — bake your config into your own
   image for reproducible deployments.

### 1. Environment variables

The shipped config is [Jinja-templated](https://rspamd.com/doc/configuration/ucl.html#rspamd-templates).
Any environment variable prefixed with `RSPAMD_` is exposed to the templates
with the prefix stripped (e.g. `RSPAMD_LOCAL_ADDR` → `{= env.LOCAL_ADDR =}`).
The upstream config consumes these out of the box:

| variable | default in image | upstream default | description |
|----------|------------------|------------------|-------------|
| `RSPAMD_LOCAL_ADDR` | `*` | `localhost` | Address all workers bind to. The image sets `*` so the container is reachable; set `127.0.0.1` to restrict. |
| `RSPAMD_LOG_TYPE` | `console` | `file` | Logging backend (`console`, `file`, `syslog`). The image uses `console` so logs go to the container's stdout. |
| `RSPAMD_LOG_FILE` | — | `$LOGDIR/rspamd.log` | Log file path (only when `LOG_TYPE=file`). |
| `RSPAMD_PORT_NORMAL` | `11333` | `11333` | Normal (scan) worker port. |
| `RSPAMD_PORT_CONTROLLER` | `11334` | `11334` | Controller / web UI port. |
| `RSPAMD_PORT_PROXY` | `11332` | `11332` | Proxy (milter) worker port. |
| `RSPAMD_PORT_FUZZY` | `11335` | `11335` | Fuzzy storage worker port (worker disabled by default). |

Example — restrict Rspamd to loopback inside the container and bump a port:

```sh
docker run -d --name rspamd \
  -e RSPAMD_LOCAL_ADDR=127.0.0.1 \
  -e RSPAMD_PORT_CONTROLLER=8080 \
  -v rspamd_data:/var/lib/rspamd \
  rspamd/rspamd
```

You can also reference **your own** `RSPAMD_`-prefixed variables from your own
snippets — see [A derived image](#3-a-derived-image) for the pattern the compose
example uses (`RSPAMD_DNS_SERVERS`, `RSPAMD_REDIS_SERVERS`, …).

### 2. Drop-in config files

Put `.conf` snippets in a directory on the host and bind-mount it over
`/etc/rspamd/local.d`. Each example below is a complete, working snippet.

**Point Rspamd at a Redis server** (used by Bayes, ratelimit, greylisting, …) —
`local.d/redis.conf`:

```hcl
servers = "redis:6379";
```

**Configure DNS resolvers** — `local.d/options.inc`:

```hcl
dns {
  nameserver = ["8.8.8.8", "1.1.1.1"];
}
```

**Tune the Bayes classifier** — `local.d/classifier-bayes.conf`:

```hcl
autolearn = true;
new_schema = true;
expire = 8640000;
```

Then mount the directory:

```sh
docker run -d --name rspamd \
  -v "$PWD/local.d:/etc/rspamd/local.d:ro" \
  -v rspamd_data:/var/lib/rspamd \
  -p 127.0.0.1:11334:11334 \
  rspamd/rspamd
```

### 3. A derived image

For production, bake your configuration into an image so deployments are
reproducible. Create a `Dockerfile`:

```dockerfile
ARG RSPAMD_VERSION=latest
FROM rspamd/rspamd:${RSPAMD_VERSION}
COPY config/rspamd /etc/rspamd
```

Lay your config out under `config/rspamd/` (e.g.
`config/rspamd/local.d/redis.conf`). Because the config is Jinja-templated, your
own snippets can stay environment-driven too. For instance
`config/rspamd/local.d/redis.conf`:

```jinja
{% if env.REDIS_SERVERS %}
servers = "{= env.REDIS_SERVERS =}";
{% endif %}
```

…fed at runtime with `-e RSPAMD_REDIS_SERVERS=redis:6379`. The
[Docker Compose example](examples/compose) wires up exactly this pattern
(Rspamd + Redis + Unbound) and is the best place to copy from.

---

## Securing the controller

The controller worker (port `11334`) serves the web UI and the admin/learn API.
The upstream defaults that the image ships with are:

- `password = "q1"` — the **well-known default** password, and
- `secure_ip = "127.0.0.1"` / `"::1"` — only loopback is treated as trusted
  (requests from `secure_ip` skip the password check).

Since the image binds to all interfaces, you should do **both** of the following
before exposing `11334`:

1. **Publish the port on loopback only** (`-p 127.0.0.1:11334:11334`), as the
   quick-start command does, so it is not reachable from outside the host.
2. **Set your own password.** Generate a hash:

   ```sh
   docker run --rm -it rspamd/rspamd rspamadm pw
   ```

   and put it in `local.d/worker-controller.inc`:

   ```hcl
   password = "$1$abcdef...";        # for read-only access
   enable_password = "$1$123456...";  # for learning and config changes
   ```

The unauthenticated `/ping` endpoint (used by the image's healthcheck) always
returns `pong` and is never password-gated.

---

## Persistent data & volumes

| Path | Contents | Notes |
|------|----------|-------|
| `/var/lib/rspamd` | Learned data: Bayes (sqlite mode), fuzzy db, caches | Declared as a `VOLUME`; persist it |
| `/etc/rspamd` | Local configuration | Optional to mount; only needed if you manage config outside the image |

If you use a **bind mount** for `/var/lib/rspamd`, the host directory must be
writable by uid/gid `11333:11333` (the user the container runs as):

```sh
mkdir -p ./rspamd-data && chown 11333:11333 ./rspamd-data
docker run -d --name rspamd -v "$PWD/rspamd-data:/var/lib/rspamd" rspamd/rspamd
```

Named volumes (as in the quick start) handle this automatically.

---

## Ports

| Port | Worker | Purpose |
|------|--------|---------|
| `11332` | proxy | Milter endpoint for MTA integration (Postfix/Exim/Sendmail) |
| `11333` | normal | HTTP scan protocol (`/checkv2`) |
| `11334` | controller | Web UI and admin/learn API |
| `11335` | fuzzy | Fuzzy storage (worker disabled by default) |

---

## Image tags

Version numbers below are illustrative; see the
[Rspamd tags](https://github.com/rspamd/rspamd/tags) for the current release, or
just use `latest`.

| tag | description |
|-----|-------------|
| `latest` | Latest stable release. Rebuilt daily to include current Debian security updates. |
| `4.0` | Latest stable in the 4.0 series. Also refreshed daily. |
| `4` | Latest stable in the 4.x series. Also refreshed daily. |
| `4.0.1` | A specific, immutable release build. |
| `nightly` | Unstable rolling release, built nightly from `master`. |
| `asan-latest`, `asan-4.0`, `asan-nightly`, … | [AddressSanitizer](https://rspamd.com/doc/developers/writing_rules.html) variants, for debugging. |
| `pkg-latest`, `pkg-nightly` | Package-only images carrying the built `.deb`s; used internally by the build pipeline. |

All images are multi-arch (`linux/amd64` + `linux/arm64`) and published to both
[Docker Hub](https://hub.docker.com/r/rspamd/rspamd) and
[GHCR](https://github.com/rspamd/rspamd-docker/pkgs/container/rspamd-docker).

---

## Health check

The image ships a `HEALTHCHECK` that probes the controller's unauthenticated
`/ping` endpoint, so `docker ps` and orchestrators see container health out of
the box. No HTTP client is needed inside the container — it uses bash `/dev/tcp`.

---

## Examples

Ready-to-run [examples](https://github.com/rspamd/rspamd-docker/tree/main/examples)
live in-repo:

- [`examples/compose`](examples/compose) — Docker Compose stack (Rspamd + Redis +
  Unbound resolver) driven entirely by environment variables.
- [`examples/k8s/tanka`](examples/k8s/tanka) — Kubernetes deployment via
  [Tanka](https://tanka.dev)/Jsonnet.
- [`examples/security/apparmor`](examples/security/apparmor) — an AppArmor
  profile for further sandboxing.

---

## Acknowledgements

The Fasttext [language identification model](https://fasttext.cc/docs/en/language-identification.html)
bundled in this image is distributed under the
[Creative Commons Attribution-Share-Alike License 3.0](https://creativecommons.org/licenses/by-sa/3.0/).

Rspamd is released under
[version 2.0 of the Apache license](https://www.apache.org/licenses/LICENSE-2.0);
see [debian/copyright](https://github.com/rspamd/rspamd/blob/master/debian/copyright)
for the full list of applicable licenses.
