# k3d

[k3s](https://github.com/k3s-io/k3s) 是 Rancher 推出的 K8s 轻量版。而 k3d 即 k3s in docker，以 docker 容器管理 k3s 集群。

以下搭建过程，是于 macOS 的笔记，供参考。其他平台，请依照官方文档进行。

```bash
# 安装 kubectl: 命令行工具
brew install kubectl
# 安装 kubecm: 配置管理工具
brew install kubecm

# 安装 k3d
brew install k3d
❯ k3d version
k3d version v4.4.8
k3s version latest (default)
```

<!--
❯ cat <<EOF > k3d-registries.yaml
mirrors:
  docker.io:
    endpoint:
      - https://x.mirror.aliyuncs.com
EOF
-->

创建集群（1主2从）：

```bash
❯ k3d cluster create mycluster --api-port 6550 --servers 1 --agents 2 --port 8080:80@loadbalancer --wait
INFO[0000] Prep: Network
INFO[0000] Created network 'k3d-mycluster' (23dc5761582b1a4b74d9aa64d8dca2256b5bc510c4580b3228123c26e93f456e)
INFO[0000] Created volume 'k3d-mycluster-images'
INFO[0001] Creating node 'k3d-mycluster-server-0'
INFO[0001] Creating node 'k3d-mycluster-agent-0'
INFO[0001] Creating node 'k3d-mycluster-agent-1'
INFO[0001] Creating LoadBalancer 'k3d-mycluster-serverlb'
INFO[0001] Starting cluster 'mycluster'
INFO[0001] Starting servers...
INFO[0001] Starting Node 'k3d-mycluster-server-0'
INFO[0009] Starting agents...
INFO[0009] Starting Node 'k3d-mycluster-agent-0'
INFO[0022] Starting Node 'k3d-mycluster-agent-1'
INFO[0030] Starting helpers...
INFO[0030] Starting Node 'k3d-mycluster-serverlb'
INFO[0031] (Optional) Trying to get IP of the docker host and inject it into the cluster as 'host.k3d.internal' for easy access
INFO[0036] Successfully added host record to /etc/hosts in 4/4 nodes and to the CoreDNS ConfigMap
INFO[0036] Cluster 'mycluster' created successfully!
INFO[0036] --kubeconfig-update-default=false --> sets --kubeconfig-switch-context=false
INFO[0036] You can now use it like this:
kubectl config use-context k3d-mycluster
kubectl cluster-info
```

查看集群信息：

```bash
❯ kubectl cluster-info
Kubernetes control plane is running at https://0.0.0.0:6550
CoreDNS is running at https://0.0.0.0:6550/api/v1/namespaces/kube-system/services/kube-dns:dns/proxy
Metrics-server is running at https://0.0.0.0:6550/api/v1/namespaces/kube-system/services/https:metrics-server:/proxy
```

查看资源信息：

```bash
# 查看 Nodes
❯ kubectl get nodes
NAME                     STATUS   ROLES                  AGE     VERSION
k3d-mycluster-agent-0    Ready    <none>                 2m12s   v1.20.10+k3s1
k3d-mycluster-server-0   Ready    control-plane,master   2m23s   v1.20.10+k3s1
k3d-mycluster-agent-1    Ready    <none>                 2m4s    v1.20.10+k3s1
# 查看 Pods
❯ kubectl get pods --all-namespaces
NAMESPACE     NAME                                      READY   STATUS      RESTARTS   AGE
kube-system   coredns-6488c6fcc6-5n7d9                  1/1     Running     0          2m12s
kube-system   metrics-server-86cbb8457f-dr7lh           1/1     Running     0          2m12s
kube-system   local-path-provisioner-5ff76fc89d-zbxf4   1/1     Running     0          2m12s
kube-system   helm-install-traefik-bfm4c                0/1     Completed   0          2m12s
kube-system   svclb-traefik-zx98g                       2/2     Running     0          68s
kube-system   svclb-traefik-7bx2r                       2/2     Running     0          68s
kube-system   svclb-traefik-cmdrm                       2/2     Running     0          68s
kube-system   traefik-6f9cbd9bd4-2mxhk                  1/1     Running     0          69s
```

测试 Nginx：

```bash
# 创建 Nginx Deployment
kubectl create deployment nginx --image=nginx
# 创建 ClusterIP Service，暴露 Nginx 端口
kubectl create service clusterip nginx --tcp=80:80
# 创建 Ingress Object
#  k3s 以 traefik 为默认 ingress controller
cat <<EOF | kubectl apply -f -
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: nginx
  annotations:
    ingress.kubernetes.io/ssl-redirect: "false"
spec:
  rules:
  - http:
      paths:
      - path: /
        pathType: Prefix
        backend:
          service:
            name: nginx
            port:
              number: 80
EOF
# 访问 Nginx Service
#  kubectl get pods 确认 nginx STATUS=Running
open http://127.0.0.1:8080
```

测试 Dashboard：

```bash
# 创建 Dashboard
GITHUB_URL=https://github.com/kubernetes/dashboard/releases
VERSION_KUBE_DASHBOARD=$(curl -w '%{url_effective}' -I -L -s -S ${GITHUB_URL}/latest -o /dev/null | sed -e 's|.*/||')
kubectl create -f https://raw.githubusercontent.com/kubernetes/dashboard/${VERSION_KUBE_DASHBOARD}/aio/deploy/recommended.yaml
# 配置 RBAC
#  admin user
cat <<EOF > dashboard.admin-user.yml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: admin-user
  namespace: kubernetes-dashboard
EOF
#  admin user role
cat <<EOF > dashboard.admin-user-role.yml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRoleBinding
metadata:
  name: admin-user
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: ClusterRole
  name: cluster-admin
subjects:
- kind: ServiceAccount
  name: admin-user
  namespace: kubernetes-dashboard
EOF
# 配置部署
kubectl create -f dashboard.admin-user.yml -f dashboard.admin-user-role.yml
# 获取 Bearer Token
kubectl -n kubernetes-dashboard describe secret admin-user-token | grep ^token
# 访问代理
kubectl proxy
# 访问 Dashboard
#  输入 Token 登录
open http://127.0.0.1:8001/api/v1/namespaces/kubernetes-dashboard/services/https:kubernetes-dashboard:/proxy/
```

![](https://cdn.jsdelivr.net/gh/ikuokuo/my-pic/pic/20210908163304.png)

删除集群：

```bash
k3d cluster delete mycluster
```

切换集群：

```bash
kubecm s
```

参考：

- [k3s / Dashboard](https://rancher.com/docs/k3s/latest/en/installation/kube-dashboard/)
- [k3d / Exposing Services](https://k3d.io/usage/guides/exposing_services/)
