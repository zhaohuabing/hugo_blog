---
layout:     post

title:      "初探 Istio Ambient 模式"
subtitle:   ""
description: ""
author: "赵化冰"
date: 2022-09-10
image: "https://images.unsplash.com/photo-1592514302393-c7c44b038323?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2664&q=80"
published: true
tags:
    - Istio
    - Envoy
    - Service Mesh
    - Ambient Mesh
categories: [ Tech ]
showtoc: true
---

Ambient 是 Istio 刚刚宣布支持的一种新的数据面模式，在本篇文章中，我们将尝试安装 Istio 的 ambient 模式，并采用 bookinfo demo 来体验 ambient 提供的 L4 和 L7 能力。

备注： L4 指 OSI 标准网络模型的四层，即 TCP 层的处理。 L7 指 OSI 标准网络模型的七层，即应用层的处理，一般指的是 HTTP 协议的处理。

# 安装 Istio ambient 模式
根据 ambient 模式的 [README 文档](https://github.com/istio/istio/tree/experimental-ambient#readme)，目前 ambient 支持了 Google GKE，AWS EKS 和 kind 三种 k8s 部署环境。经过我的尝试，在 Ubuntu 上的 kind 是最方便搭建的部署环境。可以参照[Get Started with Istio Ambient Mesh](https://istio.io/latest/blog/2022/get-started-ambient/) 搭建支持 ambient 的 Istio 试验版本。如果你无法访问官方的下载地址，可以参照下面的步骤从我在国内搭建的镜像地址下载安装：

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
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
kubectl apply -f https://zhaohuabing.com/download/ambient/sleep.yaml
kubectl apply -f https://zhaohuabing.com/download/ambient/notsleep.yaml
```

上面的命令将 Demo 应用程序部署在 default namespace，由于 default namespace 没有打上相关的标签，此时 Demo 应用的流量并不经过 ztunnel，pod 之间通过 k8s 的 [service](https://www.zhaohuabing.com/post/2019-03-29-how-to-choose-ingress-for-service-mesh/#undefined) 机制进行通信，pod 之间的流量没有经过 mTLS 认证和加密。

![](/img/2022-09-10-try-istio-ambient/app-not-in-ambient.png)
未纳入 ambient 模式的应用之间的通信

# 将 Demo 应用纳入 ambient 模式

可以通过为 namespace 打上下面的标签来将该 namespace 中的所有应用加入 ambient mesh 中。

```bash
kubectl label namespace default istio.io/dataplane-mode=ambient
``` 

istio-cni 组件会监控到 namespace 加入到了 ambient mesh 中，会设置相应的流量重定向策略，如果我们查看 istio-cni 的日志，可以看到 istio-cni 为应用 pod 创建了相应的路由规则：

```bash
kubectl logs istio-cni-node-nxcnf -n istio-system|grep route
2022-09-10T09:40:07.371761Z	info	ambient	Adding route for reviews-v3-75f494fccb-gh9sr/default: [table 100 10.244.2.8/32 via 192.168.126.2 dev istioin src 10.244.2.1]
2022-09-10T09:40:07.375442Z	info	ambient	Adding route for productpage-v1-7c548b785b-kxdwz/default: [table 100 10.244.2.9/32 via 192.168.126.2 dev istioin src 10.244.2.1]
2022-09-10T09:40:07.379072Z	info	ambient	Adding route for details-v1-76778d6644-cvkc7/default: [table 100 10.244.2.4/32 via 192.168.126.2 dev istioin src 10.244.2.1]
2022-09-10T09:40:07.382887Z	info	ambient	Adding route for ratings-v1-85c74b6cb4-rzn44/default: [table 100 10.244.2.5/32 via 192.168.126.2 dev istioin src 10.244.2.1]
2022-09-10T09:40:07.386015Z	info	ambient	Adding route for reviews-v1-6494d87c7b-f4lvz/default: [table 100 10.244.2.6/32 via 192.168.126.2 dev istioin src 10.244.2.1]
2022-09-10T09:40:07.389121Z	info	ambient	Adding route for reviews-v2-79857b95b-nk8hn/default: [table 100 10.244.2.7/32 via 192.168.126.2 dev istioin src 10.244.2.1]
```

从 sleep 访问 productpage:

```bash
kubectl exec deploy/sleep -- curl -s http://productpage:9080/ 
```

我们应该可以看到 productpage 服务的输出。此时流量已经通过 ztunnel 进行了 mTLS 双向认证和加密。我们应该可以从 sleep 和 productpage 节点上的 ztunnel 的日志中看到访问记录。

outbound 方向的流量（sleep -> sleep node 上的 ztunnel)：
```bash
kubectl  -n istio-system logs ztunnel-dk42c -cistio-proxy --tail 1
[2022-09-10T10:12:33.041Z] "- - -" 0 - - - "-" 84 1839 2 - "-" "-" "-" "-" "envoy://outbound_tunnel_lis_spiffe://cluster.local/ns/default/sa/sleep/10.244.2.9:9080" spiffe://cluster.local/ns/default/sa/sleep_to_http_productpage.default.svc.cluster.local_outbound_internal envoy://internal_client_address/ 10.96.250.29:9080 10.244.1.5:45176 - - capture outbound (no waypoint proxy)
```

inbound 方向的流量日志（productpage 上的 ztunnel -> productpage）：
```bash
kubectl  -n istio-system logs ztunnel-ff26n -cistio-proxy --tail 1
[2022-09-10T10:18:23.497Z] "CONNECT - HTTP/2" 200 - via_upstream - "-" 84 1839 2 - "-" "-" "6300b128-3a4d-472e-b573-e14743b6c981" "10.244.2.9:9080" "10.244.2.9:9080" virtual_inbound 10.244.1.3:48053 10.244.2.9:15008 10.244.1.3:36748 - - inbound hcm
```

我们可以看到 outbound 流量的日志中有(no waypoint proxy)字样，这是因为 ambient 目前的实现中缺省只进行 L4 处理，没有进行 L7 处理。因此此时流量只会通过 ztunnel ，不会经过 waypoint proxy。此时应用程序的流量路径如下图所示：
![](/img/2022-09-10-try-istio-ambient/app-in-ambient-secure-overlay.png)
应用之间通过 ztunnel 安全覆盖层进行通信


# 为 ambient mode 启用 L7 功能

目前 ambient 模式需要通过定义一个 gateway 来显示启用某个服务的七层处理。创建下面的 gateway，为 productpage 服务开启七层处理。

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: Gateway
metadata:
 name: productpage
 annotations:
   istio.io/service-account: bookinfo-productpage
spec:
 gatewayClassName: istio-mesh
EOF
```

注意上面创建的 gateway 资源中 gatewayClassName 必须设置为 'istio-mesh'，Istio 才会为 productpage 创建对应的 waypoint proxy。

此时可以查看到 Istio 创建的 waypoint proxy：

```bash
kubectl get pod|grep waypoint
bookinfo-productpage-waypoint-proxy-7dc7c7ff6-6q6l7   1/1     Running   0          21s
```
从 sleep 访问 productpage:

```bash
kubectl exec deploy/sleep -- curl -s http://productpage:9080/ 
```

下面我们再来看一下请求经过的实际路径：

sleep -> sleep node 上的 ztunnel ：
```bash
kubectl  -n istio-system logs ztunnel-dk42c -cistio-proxy --tail 1
[2022-09-10T10:51:36.373Z] "- - -" 0 - - - "-" 84 1894 5 - "-" "-" "-" "-" "10.244.2.12:15006" spiffe://cluster.local/ns/default/sa/sleep_to_server_waypoint_proxy_spiffe://cluster.local/ns/default/sa/bookinfo-productpage 10.244.1.5:47829 10.96.250.29:9080 10.244.1.5:44952 - - capture outbound (to server waypoint proxy)
```

可以从上面的日志中看到 (to server waypoint proxy) 字样，说明请求经过 waypoint proxy。

sleep node 上的 ztunnel -> waypoint proxy :

```bash
kubectl logs bookinfo-productpage-waypoint-proxy-7dc7c7ff6-6q6l7 --tail 3
[2022-09-10T10:51:36.375Z] "GET / HTTP/1.1" 200 - via_upstream - "-" 0 1683 2 2 "-" "curl/7.85.0-DEV" "fe3ba798-4ace-4891-b919-c3ea924f8cb9" "productpage:9080" "envoy://inbound_CONNECT_originate/10.244.2.9:9080" inbound-pod|9080||10.244.2.9 envoy://internal_client_address/ envoy://inbound-pod|9080||10.244.2.9/ envoy://internal_client_address/ - default
[2022-09-10T10:51:36.374Z] "GET / HTTP/1.1" 200 - via_upstream - "-" 0 1683 3 3 "-" "curl/7.85.0-DEV" "fe3ba798-4ace-4891-b919-c3ea924f8cb9" "productpage:9080" "envoy://inbound-pod|9080||10.244.2.9/" inbound-vip|9080|http|productpage.default.svc.cluster.local envoy://internal_client_address/ envoy://inbound-vip|9080||productpage.default.svc.cluster.local/ envoy://internal_client_address/ - default
[2022-09-10T10:51:36.374Z] "CONNECT - HTTP/2" 200 - via_upstream - "-" 84 1894 4 - "-" "-" "eb705930-8b73-4c29-870e-ead523143278" "10.96.250.29:9080" "envoy://inbound-vip|9080||productpage.default.svc.cluster.local/" inbound-vip|9080|internal|productpage.default.svc.cluster.local envoy://internal_client_address/ 10.244.2.12:15006 10.244.1.5:47829 - -
```
productpage node 上的 ztunnel -> productpage
```bash
kubectl  -n istio-system logs ztunnel-ff26n -cistio-proxy --tail 1
[2022-09-10T10:51:36.376Z] "CONNECT - HTTP/2" 200 - via_upstream - "-" 699 1839 1 - "-" "-" "3e0eaa80-7c72-4d46-909a-233a6bd6073e" "10.244.2.9:9080" "10.244.2.9:9080" virtual_inbound 10.244.2.12:41893 10.244.2.9:15008 10.244.2.12:38336 - - inbound hcm
```

在 ambient 模式中启用 L7 功能后，应用之间的流量路径如下图所示：
![](/img/2022-09-10-try-istio-ambient/app-in-ambient-l7.png)
启用 waypoint L7 处理后的应用流量路径

# 对流量进行七层路由

现在我们来尝试在 ambient 模式中对流量进行七层路由。ambient 模式的路由规则和 sidecar 模式是相同的，也是采用 Virtual service。

首先通过创建 gateway 为 review 服务启用 L7 能力。

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: Gateway
metadata:
 name: reviews
 annotations:
   istio.io/service-account: bookinfo-reviews
spec:
 gatewayClassName: istio-mesh
EOF
```

然后创建 DR，按版本将 review 服务分为 3 个 subset：

```bash
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  trafficPolicy:
    loadBalancer:
      simple: RANDOM
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
EOF
```

创建 VS，按 90/10 的比例将请求发送到 V1 和 V2 版本：

```bash
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
    - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 90
    - destination:
        host: reviews
        subset: v2
      weight: 10
EOF
```

执行下面的命令，可以验证 reviews 服务的请求按照上面定义的路由规则进行了路由。

```bash
kubectl exec -it deploy/sleep -- sh -c 'for i in $(seq 1 10); do curl -s http://istio-ingressgateway.istio-system/productpage | grep reviews-v.-; done'

        <u>reviews-v2-79857b95b-nk8hn</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
```

# ambient 模式小结

从上面的试验，可以看到 ambient 模式已经较好地解决了 Istio sidecar 模式下应用和 sidecar 的部署依赖问题。在 ambient 模式下，服务网格的能力是通过应用 pod 之外的 ztunnel 和 waypoint proxy 提供的，不再需要对应用 pod 进行 sidecar 注入，因此应用和 mesh 组件的的部署和升级不再相互依赖，将服务网格彻底下沉到了基础设施层面，实现了“服务网格是为应用提供通信的基础设施”的承诺。
目前要为服务启用 L7 网格能力，必须显示创建一个 gateway，这对于运维来说是一个额外的负担。对于之前我比较担心的 waypoint proxy 导致的故障范围扩大和故障定位不变的问题，由于 Istio 为每个服务账号创建一个 waypoint proxy deployment，只要遵循最佳实践为每个服务创建不同的 service account，该问题也可以得到比较好的解决。另外目前 ambient 尚处于快速的开发迭代过程中，相信这些小问题将在后续的版本中很快得到解决。

# 参考文档：
* https://istio.io/latest/blog/2022/get-started-ambient/










