# 部署 K8s 应用

## 了解概念

- [Kubernetes / Workloads](https://kubernetes.io/docs/concepts/workloads/)

之后，参照官方教程，我们将使用 Deployment 运行 Go 应用（无状态）。

## 导入镜像

首先，我们手动导入镜像进集群：

```bash
docker save http_server:1.0 > http_server:1.0.tar
k3d image import http_server:1.0.tar -c mycluster
```

如果有自己的私有仓库，参见 [k3d / Registries](https://k3d.io/usage/guides/registries/) 进行配置。

## 创建 Deployment

```bash
# 配置 Deployment （2个副本）
cat <<EOF > go-http-deployment.yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: go-http
  labels:
    app: go-http
spec:
  replicas: 2
  selector:
    matchLabels:
      app: go-http
  template:
    metadata:
      labels:
        app: go-http
    spec:
      containers:
      - name: go-http
        image: http_server:1.0
        ports:
        - containerPort: 3000
EOF
# 应用 Deployment
#  --record: 记录命令
kubectl apply -f go-http-deployment.yaml --record
```

查看 Deployment：

```bash
# 查看 Deployment
❯ kubectl get deploy
NAME      READY   UP-TO-DATE   AVAILABLE   AGE
nginx     1/1     1            1           2d
go-http   2/2     2            2           22s

# 查看 Deployment 信息
kubectl describe deploy go-http
# 查看 Deployment 创建的 ReplicaSet （2个）
kubectl get rs
# 查看 Deployment 创建的 Pods （2个）
kubectl get po -l app=go-http -o wide --show-labels
# 查看某一 Pod 信息
kubectl describe po go-http-5848d49c7c-wzmxh
```

- [k8s / Deployments](https://kubernetes.io/docs/concepts/workloads/controllers/deployment/)

## 创建 Service

```bash
# 创建 Service，名为 go-http
#  将请求代理到 app=go-http, tcp=3000 的 Pod 上
kubectl expose deployment go-http --name=go-http
# 或
cat <<EOF | kubectl create -f -
apiVersion: v1
kind: Service
metadata:
  name: go-http
  labels:
    app: go-http
spec:
  selector:
    app: go-http
  ports:
    - protocol: TCP
      port: 3000
      targetPort: 3000
EOF

# 查看 Service
kubectl get svc
# 查看 Service 信息
kubectl describe svc go-http
# 查看 Endpoints 对比看看
#  kubectl get ep go-http
#  kubectl get po -l app=go-http -o wide

# 删除 Service （如果）
kubectl delete svc go-http
```

<!--
# 或，但 Service 信息里 Port 稍不一样
kubectl create service clusterip go-http --tcp=3000:3000
-->

访问 Service (DNS)：

```bash
❯ kubectl run curl --image=radial/busyboxplus:curl -i --tty

If you don't see a command prompt, try pressing enter.

[ root@curl:/ ]$ nslookup go-http
Server:    10.43.0.10
Address 1: 10.43.0.10 kube-dns.kube-system.svc.cluster.local

Name:      go-http
Address 1: 10.43.102.17 go-http.default.svc.cluster.local

[ root@curl:/ ]$ curl http://go-http:3000/go
Hi there, I love go!
```

暴露 Service (Ingress)：

```bash
# 创建 Ingress Object
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: go-http
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - http:
      paths:
      - path: /go
        pathType: Prefix
        backend:
          service:
            name: go-http
            port:
              number: 3000
EOF
# 查看 Ingress
kubectl get ingress
# 查看 Ingress 信息
kubectl describe ingress go-http

# 删除 Ingress （如果）
kubectl delete ingress go-http
```

访问 Service (Ingress)：

```bash
❯ open http://127.0.0.1:8080/go
# 或，
❯ curl http://127.0.0.1:8080/go
Hi there, I love go!
# Nginx 是在 http://127.0.0.1:8080
```

- [k8s / Connecting Applications with Services](https://kubernetes.io/docs/concepts/services-networking/connect-applications-service/)
- [k8s / Exposing an External IP Address](https://kubernetes.io/docs/tutorials/stateless-application/expose-external-ip-address/)

<!--
kubectl expose deployment go-http --type=NodePort --name=go-http --target-port=3000
-->

## 更新

仅当 Deployment Pod 模板发生改变时，例如模板的标签或容器镜像被更新，才会触发 Deployment 上线。其他更新（如对 Deployment 执行扩缩容的操作）不会触发上线动作。

所以，我们准备 `http_server:2.0` 镜像导入集群，然后更新：

```bash
❯ kubectl set image deployment/go-http go-http=http_server:2.0 --record
deployment.apps/go-http image updated
```

之后，可以查看上线状态：

```bash
# 查看上线状态
❯ kubectl rollout status deployment/go-http
deployment "go-http" successfully rolled out

# 查看 ReplicaSet 状态：新的扩容，旧的缩容，完成更新
❯ kubectl get rs
NAME                 DESIRED   CURRENT   READY   AGE
go-http-586694b4f6   2         2         2       10s
go-http-5848d49c7c   0         0         0       6d
```

测试服务：

```bash
❯ curl http://127.0.0.1:8080/go
Hi there v2, I love go!
```

## 回滚

查看 Deployment 修订历史：

```bash
❯ kubectl rollout history deployment.v1.apps/go-http
deployment.apps/go-http
REVISION  CHANGE-CAUSE
1         kubectl apply --filename=go-http-deployment.yaml --record=true
2         kubectl set image deployment/go-http go-http=http_server:2.0 --record=true

# 查看修订信息
kubectl rollout history deployment.v1.apps/go-http --revision=2
```

回滚到之前的修订版本：

```bash
# 回滚到上一版
kubectl rollout undo deployment.v1.apps/go-http
# 回滚到指定版本
kubectl rollout undo deployment.v1.apps/go-http --to-revision=1
```

## 缩放

```bash
# 缩放 Deployment 的 ReplicaSet 数
kubectl scale deployment.v1.apps/go-http --replicas=10

# 如果集群启用了 Pod 的水平自动缩放，可以根据现有 Pods 的 CPU 利用率选择上下限
# Horizontal Pod Autoscaler Walkthrough
#  https://kubernetes.io/docs/tasks/run-application/horizontal-pod-autoscale-walkthrough/
kubectl autoscale deployment.v1.apps/nginx-deployment --min=10 --max=15 --cpu-percent=80
```

## 暂停、恢复

```bash
# 暂停 Deployment
kubectl rollout pause deployment.v1.apps/go-http
# 恢复 Deployment
kubectl rollout resume deployment.v1.apps/go-http
```

期间可以更新 Deployment ，但不会触发上线。

## 删除

```bash
kubectl delete deployment go-http
```

## 金丝雀部署

灰度部署，用多标签区分多个部署，新旧版可同时运行。部署新版时，用少量流量验证，没问题再全量更新。

- [k8s / Canary Deployments](https://kubernetes.io/docs/concepts/cluster-administration/manage-deployment/#canary-deployments)
