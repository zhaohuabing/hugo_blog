---
layout:     post

title:      "初探 Istio Ambient 模式"
subtitle:   ""
description: ""
author: "赵化冰"
date: 2022-09-10
image: "https://images.unsplash.com/photo-1491451412778-3e2c8b766720?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2340&q=80"
published: true
tags:
    - Istio
    - Envoy
    - Service Mesh
    - Ambient Mesh
categories: [ Tech ]
showtoc: true
---

Ambient 是 Istio 刚刚宣布支持的一种新的数据面模式，在本篇文章中，我们将尝试安装 Istio 的 ambient 模式，并采用 bookinfo demo 来体验 ambient 提供的 l4 和 l7 能力。

# 安装 Istio ambient 模式
根据 [ambient 模式的 README 文档](https://github.com/istio/istio/tree/experimental-ambient#readme)，目前 ambient 支持了 Google GKE，AWS EKS 和 kind 三种 k8s 部署环境。经过我的尝试，在 Ubuntu 上的 kind 是最方便搭建的部署环境。可以参照(Get Started with Istio Ambient Mesh)[https://istio.io/latest/blog/2022/get-started-ambient/]搭建支持 ambient 的 Istio 试验版本。如果你无法访问官方的下载地址，可以参照下面的步骤从我在国内搭建的镜像地址下载安装：

1. 首先在一个 Ubuntu 虚机上安装 docker 和 [kind](https://kind.sigs.k8s.io/docs/user/quick-start/)。

2. 创建一个 kind k8s 集群:
```bash
kind create cluster --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ambient
nodes:
- role: control-plane
- role: worker
- role: worker
EOF
```
3. 然后下载并解压支持 ambient 模式的 Istio 试验版本。

```bash
wget https://zhaohuabing.com/download/ambient/istio-0.0.0-ambient.191fe680b52c1754ee72a06b3e0d3f9d116f2e82-linux-amd64.tar.gz

tar -xvf istio-0.0.0-ambient.191fe680b52c1754ee72a06b3e0d3f9d116f2e82-linux-amd64.tar.gz
```

4. 安装 Istio，需要指定 profile 为 ambient，注意需要指定 hub，否则相关的容器镜像可能由于网络原因拉取失败。

```bash
cd istio-0.0.0-ambient.191fe680b52c1754ee72a06b3e0d3f9d116f2e82
./bin/istioctl install --set profile=ambient --set hub=zhaohuabing
```

ambient profile 在集群中安装了 Istiod, ingress gateway, ztunnel 和 istio-cni 几个组件。其中 ztunnel 和 istio-cni 以 daemonset 方式部署在每个 node 上。istio-cni 用于检测哪些应用 pod 处于 ambient 模式，并会创建 iptables 规则将这些 pod 出向流量和入向流量重定向到 node 的 ztunnel。istio-cni 会持续监控 node 上 pod 的变化，并更新相应的重定向逻辑。

```bash
$ kubectl -n istio-system get pod
NAME                                    READY   STATUS    RESTARTS   AGE
istio-cni-node-27f9k                    1/1     Running   0          85m
istio-cni-node-nxcnf                    1/1     Running   0          85m
istio-cni-node-x2kjz                    1/1     Running   0          85m
istio-ingressgateway-5c87575d87-5chhx   1/1     Running   0          85m
istiod-bdddf595b-tn9px                  1/1     Running   0          87m
ztunnel-5nnnl                           1/1     Running   0          87m
ztunnel-dk42c                           1/1     Running   0          87m
ztunnel-ff26n                           1/1     Running   0          87m
```

# 部署 Demo 应用程序

执行下面的命令，部署 Demo 应用程序。

```bash
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl apply -f https://zhaohuabing.com/download/ambient/sleep.yaml
kubectl apply -f https://zhaohuabing.com/download/ambient/notsleep.yaml
```

上面的命令将 Demo 应用程序部署在 default namespace，由于 default namespace 没有打上相关的标签，此时 Demo 应用的流量并不经过 ztunnel，pod 之间通过 k8s 的 [service](https://www.zhaohuabing.com/post/2019-03-29-how-to-choose-ingress-for-service-mesh/#undefined) 机制进行通信，pod 之间的流量没有经过 mTLS 认证和加密。

![](/img/2022-09-10-try-istio-ambient/app-not-in-ambient.png)
未纳入 ambient 模式的应用之间的未加密通信



