FROM 84codes/crystal:1.16.3-debian-12 AS builder

RUN apt update && \
    apt install -y --no-install-recommends liblzma-dev libsqlite3-dev

ARG release

WORKDIR /invidious
COPY ./shard.yml ./shard.yml
COPY ./shard.lock ./shard.lock
RUN shards install --production

COPY ./src/ ./src/
# TODO: .git folder is required for building – this is destructive.
# See definition of CURRENT_BRANCH, CURRENT_COMMIT and CURRENT_VERSION.
COPY ./.git/ ./.git/

# Required for fetching player dependencies
COPY ./scripts/ ./scripts/
COPY ./assets/ ./assets/
COPY ./videojs-dependencies.yml ./videojs-dependencies.yml

RUN crystal spec --warnings all \
    --link-flags "-lxml2 -llzma"    
RUN --mount=type=cache,target=/root/.cache/crystal if [[ "${release}" == 1 ]] ; then \
        crystal build ./src/invidious.cr \
        --release \
        --warnings all \
        --link-flags "-lxml2 -llzma"; \
    else \
        crystal build ./src/invidious.cr \
        --warnings all \
        --link-flags "-lxml2 -llzma"; \
    fi

FROM debian:12-slim
RUN apt update && \
    DEBIAN_FRONTEND=noninteractive \
    apt install -y --no-install-recommends \
    librsvg2-bin fonts-open-sans tini tzdata \
    libyaml-0-2 libsqlite3-0 libssl3 liblzma5 ca-certificates
WORKDIR /invidious
RUN groupadd --gid 1000 --system invidious && \
    useradd --uid 1000 --system invidious -g invidious
COPY --chown=invidious ./config/config.* ./config/
RUN mv -n config/config.example.yml config/config.yml
RUN sed -i 's/host: \(127.0.0.1\|localhost\)/host: invidious-db/' config/config.yml
COPY ./config/sql/ ./config/sql/
COPY ./locales/ ./locales/
COPY --from=builder /invidious/assets ./assets/
COPY --from=builder /invidious/invidious .
RUN chmod o+rX -R ./assets ./config ./locales
RUN apt-get clean autoclean && \
    apt-get autoremove --yes && \
    rm -rf /var/lib/apt /var/lib/dpkg /var/lib/cache /var/lib/log

EXPOSE 3000
USER invidious
ENTRYPOINT ["/usr/bin/tini", "--"]
CMD [ "/invidious/invidious" ]
