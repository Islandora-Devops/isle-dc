FROM alpine:latest
COPY assets.tar.gz /
COPY create_dirs.sh /
RUN tar xzvf /assets.tar.gz -C / && \
    sh /create_dirs.sh

FROM alpine:latest
COPY --from=0 /assets/ /assets