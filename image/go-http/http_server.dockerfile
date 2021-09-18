FROM golang:1.17-alpine AS builder
WORKDIR /app
ADD ./http_server.go /app
RUN cd /app && go build http_server.go

FROM alpine:3.14
WORKDIR /app
COPY --from=builder /app/http_server /app/
EXPOSE 3000
ENTRYPOINT ./http_server
