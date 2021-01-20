FROM golang:1.15-alpine

ENV CGO_ENABLED=0

WORKDIR /go/src/app
COPY . .

RUN go get -d -v ./...
RUN go install -v ./...

CMD ["go", "test", "-v", "./..."]
