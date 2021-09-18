# 搭建 K8s

本地开发测试，需要搭建一个 K8s 轻量服务。实际部署时，可以用云厂商的 K8s 服务。

本文以 `k3d` 为例，于 macOS 搭建 K8s 服务。于 Ubuntu 则推荐 `MicroK8s`。其他可替代方案有：

- [Kubernetes / Install Tools](https://kubernetes.io/docs/tasks/tools/)
  - [kind](https://kind.sigs.k8s.io/), [minikube](https://minikube.sigs.k8s.io/), [kubeadm](https://kubernetes.io/docs/reference/setup-tools/kubeadm/)
- [Docker Desktop / Deploy on Kubernetes](https://docs.docker.com/desktop/kubernetes/)
