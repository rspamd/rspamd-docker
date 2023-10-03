ARG DEBIAN_RELEASE=bookworm
ARG LONG_VERSION
ARG TARGETARCH

FROM rspamd/rspamd:pkg-${TARGETARCH}-${LONG_VERSION} AS pkg
FROM --platform=linux/${TARGETARCH} debian:${DEBIAN_RELEASE}-slim AS preinstall

ARG ASAN_TAG
ARG TARGETARCH
ENV ASAN_TAG=$ASAN_TAG
ENV TARGETARCH=$TARGETARCH

COPY	--from=pkg /deb /deb

RUN	apt-get update \
	&& dpkg -i /deb/rspamd${ASAN_TAG}_*_${TARGETARCH}.deb /deb/rspamd${ASAN_TAG}-dbg_*_${TARGETARCH}.deb || true \
	&& apt-get install -f -y \
	&& apt-get -q clean \
	&& dpkg-query --no-pager -l rspamd${ASAN_TAG} \
	&& rm -rf /var/cache/debconf /var/lib/apt/lists \
	&& rm -rf /deb
COPY	lid.176.ftz /usr/share/rspamd/languages/fasttext_model.ftz

FROM scratch AS install
COPY --from=preinstall / /

USER	11333:11333

VOLUME  [ "/var/lib/rspamd" ]

CMD     [ "/usr/bin/rspamd", "-f" ]

# https://www.rspamd.com/doc/workers
# 11332 proxy ; 11333 normal ; 11334 controller
EXPOSE  11332 11333 11334
