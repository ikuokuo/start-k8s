# 创建 Chart

```bash
helm create go-http
```

查看内容：

```bash
❯ tree go-http -aF --dirsfirst
go-http
├── charts/     # 包依赖的 charts，称 subcharts
├── templates/  # 包的 K8s 文件模板，用的 Go 模板
│   ├── tests/
│   │   └── test-connection.yaml
│   ├── NOTES.txt       # 包的帮助文本
│   ├── _helpers.tpl    # 模板可重用的片段，模板里 include 引用
│   ├── deployment.yaml
│   ├── hpa.yaml
│   ├── ingress.yaml
│   ├── service.yaml
│   └── serviceaccount.yaml
├── .helmignore # 打包忽略说明
├── Chart.yaml  # 包的描述文件
└── values.yaml # 变量默认值，可安装时覆盖，模板里 .Values 引用
```

修改内容：

- 修改 `Chart.yaml` 里的描述
  - 更多见 [The Chart.yaml File](https://helm.sh/docs/topics/charts/#the-chartyaml-file)
- 修改 `values.yaml` 里的变量
  - 修改 `image` 为发布的 Go 服务
  - 修改 `ingress` 为 `true`，及一些配置
  - 删除 `serviceAccount` `autoscaling`，`templates/` 里也搜索删除相关内容
- 修改 `templates/` 里的模板
  - 删除 `tests/`，剩余 `deployment.yaml` `service.yaml` `ingress.yaml` 有用

结果可见 [start-k8s/helm/go-http](https://github.com/ikuokuo/start-k8s/tree/main/helm/go-http)。

检查错误：

```bash
❯ helm lint --strict go-http
==> Linting go-http
[INFO] Chart.yaml: icon is recommended

1 chart(s) linted, 0 chart(s) failed
```

渲染模板：

```bash
# --set 覆盖默认配置，或者用 -f 选择自定的 values.yaml
helm template go-http-helm ./go-http \
--set replicaCount=2 \
--set "ingress.hosts[0].paths[0].path=/helm" \
--set "ingress.hosts[0].paths[0].pathType=Prefix"
```

安装 Chart：

```bash
helm install go-http-helm ./go-http \
--set replicaCount=2 \
--set "ingress.hosts[0].paths[0].path=/helm" \
--set "ingress.hosts[0].paths[0].pathType=Prefix"

# 或，打包后安装
helm package go-http
helm install go-http-helm go-http-1.0.0.tgz \
--set replicaCount=2 \
--set "ingress.hosts[0].paths[0].path=/helm" \
--set "ingress.hosts[0].paths[0].pathType=Prefix"

# 查看安装列表
helm list
```

测试服务：

```bash
❯ kubectl get deploy go-http-helm
NAME           READY   UP-TO-DATE   AVAILABLE   AGE
go-http-helm   2/2     2            2           2m42s

❯ curl http://127.0.0.1:8080/helm
Hi there, I love helm!
```

卸载 Chart：

```bash
helm uninstall go-http-helm
```

- [Helm / Chart Template Guide](https://helm.sh/docs/chart_template_guide/)
