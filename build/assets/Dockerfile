FROM alpine:latest
COPY data/assets.tar.gz /
COPY create_dirs.sh /
RUN tar xzvf /assets.tar.gz -C / && \
    sh /create_dirs.sh

FROM alpine:latest

RUN apk --no-cache add docker-cli
COPY --from=0 /assets/ /assets
COPY entrypoint.sh /bin/
COPY bootstrap.sh /bin/

RUN chmod 700 /bin/entrypoint.sh && \
    chmod 700 /bin/bootstrap.sh

ENTRYPOINT [ "/bin/entrypoint.sh" ]
