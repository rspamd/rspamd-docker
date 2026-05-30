ARG DEBIAN_RELEASE=trixie
ARG PKG_IMG=ghcr.io/rspamd/rspamd-docker
ARG PKG_TAG=pkg-latest

FROM ${PKG_IMG}:${PKG_TAG} AS pkg

FROM scratch AS lid
COPY lid.176.ftz /

FROM debian:${DEBIAN_RELEASE}-slim AS install

ARG ASAN_TAG
ENV ASAN_TAG=$ASAN_TAG

RUN	--mount=type=cache,from=pkg,source=/deb,target=/deb \
	apt-get update \
	&& apt-get install -y `bash -c "dpkg -I /deb/rspamd${ASAN_TAG}_*_*.deb | grep '^ Depends:' | perl -p -e 's#Depends: |,|\||\([^)]*\)##g'"` \
	&& apt-get -q clean \
	&& rm -rf /var/cache/ldconfig/aux-cache /var/lib/apt/lists/* /var/log/apt/*.log /var/log/dpkg.log \
	&& bash -c "find / -mount -newer /proc/1 -not -path '/dev/**' -not -path '/proc/**' -not -path '/sys/**' | xargs touch -h -d '2000-01-01 00:00:00'"

RUN	--mount=type=cache,from=pkg,source=/deb,target=/deb --mount=type=cache,from=lid,source=/,target=/lid \
	groupadd --system --badname --gid 11333 _rspamd \
	&& useradd --system --badname --uid 11333 --gid 11333 --home-dir /var/lib/rspamd --no-create-home --shell /usr/sbin/nologin --comment "rspamd spam filtering system" _rspamd \
	&& dpkg -i /deb/rspamd${ASAN_TAG}_*_*.deb /deb/rspamd${ASAN_TAG}-dbg_*_*.deb \
	&& rm -rf /var/log/dpkg.log \
	&& cp /lid/lid.176.ftz /usr/share/rspamd/languages/fasttext_model.ftz \
	&& passwd --expire _rspamd \
	&& bash -c "find / -mount -newer /proc/1 -not -path '/dev/**' -not -path '/proc/**' -not -path '/sys/**' | xargs touch -h -d '2000-01-01 00:00:00'"

USER	11333:11333

# rspamd exposes RSPAMD_-prefixed env vars to its jinja templates with the
# prefix stripped: LOCAL_ADDR overrides the per-worker bind address (default
# localhost) and LOG_TYPE overrides logging.type (default "file").
ENV	RSPAMD_LOCAL_ADDR=* \
	RSPAMD_LOG_TYPE=console

VOLUME  [ "/var/lib/rspamd" ]

# Probe the controller's unauthenticated /ping endpoint (always returns "pong",
# never password-gated). Uses bash /dev/tcp so no extra HTTP client is needed.
HEALTHCHECK --interval=30s --timeout=5s --start-period=30s --retries=3 \
	CMD bash -c 'exec 3<>/dev/tcp/127.0.0.1/${RSPAMD_PORT_CONTROLLER:-11334}; printf "GET /ping HTTP/1.0\r\n\r\n" >&3; grep -q pong <&3'

CMD     [ "/usr/bin/rspamd", "-f" ]

# https://www.rspamd.com/doc/workers
# 11332 proxy ; 11333 normal ; 11334 controller
EXPOSE  11332 11333 11334
