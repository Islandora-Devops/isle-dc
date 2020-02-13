FROM alpine:latest
COPY data/assets.tar.gz /
COPY create_dirs.sh /
RUN tar xzvf /assets.tar.gz -C / && \
    sh /create_dirs.sh

FROM alpine:latest

RUN apk --no-cache add docker-cli
COPY --from=0 /assets/ /assets
COPY *.sh /bin/

RUN chmod 700 /bin/*.sh

ENTRYPOINT [ "/bin/entrypoint.sh" ]
