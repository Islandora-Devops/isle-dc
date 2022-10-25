FROM alpine:latest
COPY data.tar /
RUN tar xvf /data.tar -C /

FROM alpine:latest
COPY --from=0 /data/ /data
