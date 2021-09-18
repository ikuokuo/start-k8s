# 准备 K8s 应用

## Go 应用

`http_server.go`:

```go
package main

import (
	"fmt"
	"log"
	"net/http"
)

func handler(w http.ResponseWriter, r *http.Request) {
	fmt.Fprintf(w, "Hi there, I love %s!", r.URL.Path[1:])
}

func main() {
	http.HandleFunc("/", handler)
	fmt.Println("HTTP Server running ...")
	log.Fatal(http.ListenAndServe(":3000", nil))
}
```

## 构建镜像

`http_server.dockerfile`:

```dockerfile
FROM golang:1.17-alpine AS builder
WORKDIR /app
ADD ./http_server.go /app
RUN cd /app && go build http_server.go

FROM alpine:3.14
WORKDIR /app
COPY --from=builder /app/http_server /app/
EXPOSE 3000
ENTRYPOINT ./http_server
```

```bash
# 编译镜像
docker build -t http_server:1.0 -f http_server.dockerfile .
# 运行应用
docker run --rm -p 3000:3000 http_server:1.0
# 测试应用
❯ curl http://127.0.0.1:3000/go
Hi there, I love go!
```
