ARG DEBIAN_RELEASE=bookworm
ARG LONG_VERSION
ARG TARGETARCH

FROM nerfdog/rspamd:pkg-${TARGETARCH}-${LONG_VERSION} AS pkg
FROM --platform=linux/${TARGETARCH} debian:${DEBIAN_RELEASE} AS install

ARG ASAN_TAG
ARG TARGETARCH
ENV ASAN_TAG=$ASAN_TAG
ENV TARGETARCH=$TARGETARCH

RUN	mkdir /deb
COPY	--from=pkg /deb/* /deb/

RUN	apt-get update \
	&& dpkg -i /deb/rspamd${ASAN_TAG}_*_${TARGETARCH}.deb /deb/rspamd${ASAN_TAG}-dbg_*_${TARGETARCH}.deb || true \
	&& apt-get install -f -y \
	&& apt-get -q clean \
	&& dpkg-query --no-pager -l rspamd${ASAN_TAG} \
	&& rm -rf /var/cache/debconf /var/lib/apt/lists \
	&& rm -rf /deb
COPY	lid.176.ftz /usr/share/rspamd/languages/fasttext_model.ftz

USER	11333:11333

VOLUME  [ "/var/lib/rspamd" ]

CMD     [ "/usr/bin/rspamd", "-f" ]

EXPOSE  11332 11333 11334
