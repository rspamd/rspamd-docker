ARG DEBIAN_RELEASE=bookworm
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
	dpkg -i /deb/rspamd${ASAN_TAG}_*_*.deb /deb/rspamd${ASAN_TAG}-dbg_*_*.deb \
	&& rm -rf /var/log/dpkg.log \
	&& cp /lid/lid.176.ftz /usr/share/rspamd/languages/fasttext_model.ftz \
	&& passwd --expire _rspamd && passwd --expire _rspamd \
	&& bash -c "find / -mount -newer /proc/1 -not -path '/dev/**' -not -path '/proc/**' -not -path '/sys/**' | xargs touch -h -d '2000-01-01 00:00:00'"

USER	11333:11333

CMD     [ "/usr/bin/rspamd", "-f" ]

# https://www.rspamd.com/doc/workers
# 11332 proxy ; 11333 normal ; 11334 controller
EXPOSE  11332 11333 11334
