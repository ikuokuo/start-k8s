# MicroK8s

MicroK8s 是 Ubuntu 官方生态提供的 K8s 轻量版，适合用于开发工作站、IoT、Edge、CI/CD。

以下搭建过程，是于 Ubuntu 18/20 的笔记，供参考。其他平台，请依照官方文档进行。

```bash
# 检查 hostname
#  要求不含大写字母和下划线，不然依照后文修改
hostname

# 安装 microk8s
sudo apt install snapd -y
snap info microk8s
sudo snap install microk8s --classic --channel=1.21/stable

# 添加用户组
sudo usermod -a -G microk8s $USER
sudo chown -f -R $USER ~/.kube
newgrp microk8s
id $USER

## 一些确保拉到镜像的方法
# 配置代理（如果有）
#  MicroK8s / Installing behind a proxy
#   https://microk8s.io/docs/install-proxy
#  Issue: Pull images from others than k8s.gcr.io
#   https://github.com/ubuntu/microk8s/issues/472
sudo vi /var/snap/microk8s/current/args/containerd-env
  HTTPS_PROXY=http://127.0.0.1:7890
  NO_PROXY=10.1.0.0/16,10.152.183.0/24
# 添加镜像（docker.io）
#  镜像加速器
#   https://yeasy.gitbook.io/docker_practice/install/mirror
#  还可改 args/ 里不同模板的 sandbox_image
sudo vi /var/snap/microk8s/current/args/containerd-template.toml
  [plugins."io.containerd.grpc.v1.cri"]
    [plugins."io.containerd.grpc.v1.cri".registry]
      [plugins."io.containerd.grpc.v1.cri".registry.mirrors]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."docker.io"]
          endpoint = ["https://x.mirror.aliyuncs.com", "https://registry-1.docker.io", ]
        [plugins."io.containerd.grpc.v1.cri".registry.mirrors."localhost:32000"]
          endpoint = ["http://localhost:32000"]
# 手动导入，见后文启用插件那

# 重启服务
microk8s stop
microk8s start
```

检查状态：

```bash
$ microk8s status
microk8s is running
high-availability: no
  datastore master nodes: 127.0.0.1:19001
  datastore standby nodes: none
addons:
  enabled:
    ha-cluster           # Configure high availability on the current node
  disabled:
    ambassador           # Ambassador API Gateway and Ingress
    cilium               # SDN, fast with full network policy
    dashboard            # The Kubernetes dashboard
    dns                  # CoreDNS
    fluentd              # Elasticsearch-Fluentd-Kibana logging and monitoring
    gpu                  # Automatic enablement of Nvidia CUDA
    helm                 # Helm 2 - the package manager for Kubernetes
    helm3                # Helm 3 - Kubernetes package manager
    host-access          # Allow Pods connecting to Host services smoothly
    ingress              # Ingress controller for external access
    istio                # Core Istio service mesh services
    jaeger               # Kubernetes Jaeger operator with its simple config
    keda                 # Kubernetes-based Event Driven Autoscaling
    knative              # The Knative framework on Kubernetes.
    kubeflow             # Kubeflow for easy ML deployments
    linkerd              # Linkerd is a service mesh for Kubernetes and other frameworks
    metallb              # Loadbalancer for your Kubernetes cluster
    metrics-server       # K8s Metrics Server for API access to service metrics
    multus               # Multus CNI enables attaching multiple network interfaces to pods
    openebs              # OpenEBS is the open-source storage solution for Kubernetes
    openfaas             # openfaas serverless framework
    portainer            # Portainer UI for your Kubernetes cluster
    prometheus           # Prometheus operator for monitoring and logging
    rbac                 # Role-Based Access Control for authorisation
    registry             # Private image registry exposed on localhost:32000
    storage              # Storage class; allocates storage from host directory
    traefik              # traefik Ingress controller for external access
```

如果 `status` 不正确时，可以如下排查错误：

```bash
microk8s inspect
grep -r error /var/snap/microk8s/2346/inspection-report
```

<!--
WARNING:  IPtables FORWARD policy is DROP. Consider enabling traffic forwarding with: sudo iptables -P FORWARD ACCEPT
The change can be made persistent with: sudo apt-get install iptables-persistent
WARNING:  Docker is installed.
Add the following lines to /etc/docker/daemon.json:
{
    "insecure-registries" : ["localhost:32000"]
}
and then restart docker with: sudo systemctl restart docker
-->

如果要修改 `hostname`：

```bash
# 改名称
sudo hostnamectl set-hostname ubuntu-vm
# 改 host
sudo vi /etc/hosts

# 云主机的话，还要改下配置
sudo vi /etc/cloud/cloud.cfg
  preserve_hostname: true
  # 如果只修改 preserve_hostname 不生效，那就直接注释掉 set/update_hostname
  cloud_init_modules:
  #  - set_hostname
  #  - update_hostname

# 重启，验证生效
sudo reboot
```

接着，启用些基础插件：

```bash
microk8s enable dns dashboard

# 查看 Pods ，确认 running
microk8s kubectl get pods --all-namespaces
# 不然，详情里看下错误原因
microk8s kubectl describe pod --all-namespaces
```

直到全部正常 `running`：

```bash
$ kubectl get pods --all-namespaces
NAMESPACE     NAME                                         READY   STATUS    RESTARTS   AGE
kube-system   kubernetes-dashboard-85fd7f45cb-snqrv        1/1     Running   1          15h
kube-system   dashboard-metrics-scraper-78d7698477-tmb7k   1/1     Running   1          15h
kube-system   metrics-server-8bbfb4bdb-wlf8g               1/1     Running   1          15h
kube-system   calico-node-p97kh                            1/1     Running   1          6m18s
kube-system   coredns-7f9c69c78c-255fg                     1/1     Running   1          15h
kube-system   calico-kube-controllers-f7868dd95-st9p7      1/1     Running   1          16h
```

如果拉取镜像失败，可以 `microk8s ctr image pull <mirror>`。或者，`docker pull` 后导入 `containerd`：

```bash
docker pull registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.1
docker tag registry.cn-hangzhou.aliyuncs.com/google_containers/pause:3.1 k8s.gcr.io/pause:3.1
docker save k8s.gcr.io/pause:3.1 > pause:3.1.tar
microk8s ctr image import pause:3.1.tar

docker pull calico/cni:v3.13.2
docker save calico/cni:v3.13.2 > cni:v3.13.2.tar
microk8s ctr image import cni:v3.13.2.tar

docker pull calico/node:v3.13.2
docker save calico/node:v3.13.2 > node:v3.13.2.tar
microk8s ctr image import node:v3.13.2.tar
```

如果 `calico-node` `CrashLoopBackOff`，可能网络配置问题：

```bash
# 查具体日志
microk8s kubectl logs -f -n kube-system calico-node-l5wl2 -c calico-node
# 如果有 Unable to auto-detect an IPv4 address，那么 ip a 找出哪个网口有 IP 。修改：
sudo vi /var/snap/microk8s/current/args/cni-network/cni.yaml
  - name: IP_AUTODETECTION_METHOD
  value: "interface=wlo.*"
# 重启服务
microk8s stop; microk8s start

## 参考
# Issue: Microk8s 1.19 not working on Ubuntu 20.04.1
#  https://github.com/ubuntu/microk8s/issues/1554
# Issue: CrashLoopBackOff for calico-node pods
#  https://github.com/projectcalico/calico/issues/3094
# Changing the pods CIDR in a MicroK8s cluster
#  https://microk8s.io/docs/change-cidr
# MicroK8s IPv6 DualStack HOW-TO
#  https://discuss.kubernetes.io/t/microk8s-ipv6-dualstack-how-to/14507
```

然后，可以打开 `Dashboard` 看看：

```bash
# 获取 Token （未启用 RBAC 时）
token=$(microk8s kubectl -n kube-system get secret | grep default-token | cut -d " " -f1)
microk8s kubectl -n kube-system describe secret $token
# 转发端口
microk8s kubectl port-forward -n kube-system service/kubernetes-dashboard 10443:443
# 打开网页，输入 Token 登录
xdg-open https://127.0.0.1:10443

# 更多说明 https://microk8s.io/docs/addon-dashboard
# Issue: Your connection is not private
#  https://github.com/kubernetes/dashboard/issues/3804
```

![](https://cdn.jsdelivr.net/gh/ikuokuo/my-pic/pic/20210908163327.png)

更多操作，请阅读官方文档。本文之后仍以 `k3d` 为例。
