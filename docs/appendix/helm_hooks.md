# 实践 Helm Hooks

## 了解

- [Helm / Chart Hooks](https://helm.sh/docs/topics/charts_hooks/)
- [Helm hooks examples](https://www.golinuxcloud.com/kubernetes-helm-hooks-examples)

## 创建

```bash
helm create helm-hooks
# 清理 templates
rm -rf helm-hooks/templates/*
```

<!--
helm lint helm-hooks
-->

创建 `pre-install` 的 `ConfigMap` `Secret` 数据，添加到 `Job` 环境变量：

```yaml
---
# Source: helm-hooks/templates/pre-install-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: pre-install-secret
  annotations:
    helm.sh/hook: "pre-install, pre-upgrade"
    helm.sh/hook-delete-policy: "before-hook-creation, hook-succeeded"
    helm.sh/hook-weight: "0"
    helm.sh/resource-policy: keep
type: Opaque
data:
  KEY_SECRET_PRE_INSTALL: a2V5X3NlY3JldF9wcmVfaW5zdGFsbA==
---
# Source: helm-hooks/templates/pre-install-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: pre-install-configmap
  annotations:
    helm.sh/hook: "pre-install, pre-upgrade"
    helm.sh/hook-delete-policy: "before-hook-creation, hook-succeeded"
    helm.sh/hook-weight: "0"
data:
  KEY_CONFIG_PRE_INSTALL: key_config_pre_install
---
# Source: helm-hooks/templates/pre-install-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: pre-install-job
  labels:
  annotations:
    helm.sh/hook: "pre-install, pre-upgrade"
    # helm.sh/hook-delete-policy: "before-hook-creation, hook-succeeded"
    helm.sh/hook-weight: "1"
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: pre-install-job
        image: busybox
        imagePullPolicy: IfNotPresent
        command: ['sh', '-c', 'printenv | grep KEY']
        envFrom:
          - configMapRef:
              name: pre-install-configmap
          - secretRef:
              name: pre-install-secret
```

创建 `post-install` 的 `ConfigMap` `Secret` 文件，挂载到 `Job` 容器卷：

```yaml
---
# Source: helm-hooks/templates/post-install-secret.yaml
apiVersion: v1
kind: Secret
metadata:
  name: post-install-secret
  annotations:
    helm.sh/hook: "post-install, post-upgrade"
    helm.sh/hook-delete-policy: "before-hook-creation, hook-succeeded"
    helm.sh/hook-weight: "0"
    helm.sh/resource-policy: keep
type: Opaque
stringData:
  secret.conf: |
    KEY_SECRET_POST_INSTALL: key_secret_post_install
---
# Source: helm-hooks/templates/post-install-configmap.yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: post-install-configmap
  annotations:
    helm.sh/hook: "post-install, post-upgrade"
    helm.sh/hook-delete-policy: "before-hook-creation, hook-succeeded"
    helm.sh/hook-weight: "0"
data:
  config.conf: |
    KEY_CONFIG_POST_INSTALL: key_config_post_install
  run.sh: |
    #!/bin/sh
    set -x
    ls /mnt/configmap/
    cat /mnt/configmap/config.conf
    ls /mnt/secret
    cat /mnt/secret/secret.conf
---
# Source: helm-hooks/templates/post-install-job.yaml
apiVersion: batch/v1
kind: Job
metadata:
  name: post-install-job
  labels:
  annotations:
    helm.sh/hook: "post-install, post-upgrade"
    # helm.sh/hook-delete-policy: "before-hook-creation, hook-succeeded"
    helm.sh/hook-weight: "1"
spec:
  backoffLimit: 0
  template:
    spec:
      restartPolicy: Never
      containers:
      - name: post-install-job
        image: busybox
        imagePullPolicy: IfNotPresent
        command: [ "/bin/sh" ]
        args: [ "/mnt/configmap/run.sh" ]
        volumeMounts:
          - name: configmap-volume
            mountPath: /mnt/configmap
            readOnly: true
          - name: secret-volume
            mountPath: /mnt/secret
            readOnly: true
      volumes:
        - name: configmap-volume
          configMap:
            name: post-install-configmap
        - name: secret-volume
          secret:
            secretName: post-install-secret
```

## 安装

```bash
❯ helm install helm-hooks ./helm-hooks
NAME: helm-hooks
LAST DEPLOYED: Tue Oct 18 20:00:00 2021
NAMESPACE: default
STATUS: deployed
REVISION: 1
TEST SUITE: None
```

## 查看

查看 `pods`：

```bash
❯ kubectl get pod
pre-install-job--1-nsn5d                                  0/1     Completed   0          55s
post-install-job--1-p5npt                                 0/1     Completed   0          54s
```

查看 `logs`：

```bash
❯ kubectl logs pre-install-job--1-nsn5d
KEY_SECRET_PRE_INSTALL=key_secret_pre_install
KEY_CONFIG_PRE_INSTALL=key_config_pre_install
```

```bash
❯ kubectl logs post-install-job--1-p5npt
+ ls /mnt/configmap/
config.conf
run.sh
+ cat /mnt/configmap/config.conf
KEY_CONFIG_POST_INSTALL: key_config_post_install
+ ls /mnt/secret
secret.conf
+ cat /mnt/secret/secret.conf
KEY_SECRET_POST_INSTALL: key_secret_post_install
```

## 清理

```bash
helm uninstall helm-hooks
kubectl delete job pre-install-job
kubectl delete job post-install-job
```
