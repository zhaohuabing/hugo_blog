---
layout:     post

title:      "在 Ambient Mesh 中使用 Envoy Gateway 扩展 Redis 集群"
description: "本文介绍如何在 Istio Ambient Mesh 中，通过 Envoy Gateway 实现对 Redis 集群 的透明接入与智能路由，为无 Sidecar 模式下的有状态服务提供高效、可扩展的解决方案。"
author: "Kailun Wang(Houzz)、Yangyang Zhao(Houzz)、Huabing Zhao(Tetrate)"
date: 2025-11-06
image: "/img/2025-10-30-scaling-redis-in-ambient-mesh-with-envoy-gateway/background.jpg"

tags:
    - Envoy Gateway
    - Redis
    - Ambient Mesh
    - Istio
categories:
    - Tech
    - Open Source
showtoc: true
---
<center>爱心树，福州三坊七巷，摄于 2025 年夏</center>

在我们此前的博文——[《使用 Envoy Gateway 作为 Ambient Mesh 的统一入口网关和 Waypoint 代理》](https://www.cncf.io/blog/2025/08/26/use-envoy-gateway-as-the-unified-ingress-gateway-and-waypoint-proxy-for-ambient-mesh/)中，我们介绍了 Envoy Gateway 如何补足 Istio Ambient Mesh 在第七层（L7）能力上的空白，例如全局限流、熔断、OIDC 认证以及 xDS 动态配置。

基于这一基础，本篇文章将探讨一个更复杂、涉及状态管理的实际场景：如何在 Ambient Mesh 中管理 Redis 集群流量。

随着服务网格被广泛采用，支持 Redis 这类有状态协议的需求变得越来越重要。本文由 **[Houzz](https://www.houzz.com/)** 与 **[Tetrate](https://tetrate.io/)** 联合撰写，介绍我们如何协作，通过 Envoy Gateway 作为集中式 Waypoint 代理，使 Istio Ambient Mesh 能够透明地处理 Redis 集群通信。

这一探索始于 Houzz 在从基于 sidecar 的 Istio 模式迁移到轻量、无 sidecar 的 Ambient 模式过程中遇到的挑战。虽然 Ambient 模式在运维简化和资源开销方面具有显著优势，但它原生并不支持 Redis 集群特有的拓扑发现与基于 slot 的路由机制。

为此，我们设计了一种新架构：使用 Envoy Gateway 作为 Waypoint Proxy，将 Redis 集群的拓扑感知和请求路由逻辑从应用中剥离出来。这样，网格内的客户端无需改动代码，即可无缝访问外部 Redis 分片，也无需注入 sidecar。

接下来，我们将介绍问题背景、解决方案设计、部署步骤以及该方案在 Houzz 实际生产环境中的效果。

---

## 背景：Houzz 的 Redis 集群架构

Redis 是 Houzz 基础设施中不可或缺的核心组件，为包括 PHP、Node.js 在内的多语言应用提供支持。Houzz 运行着一个大型 Redis 集群，以集群模式部署在云端虚拟机上。该集群包含数百个节点，存储数百 TB 数据，其中大部分为持久化数据，需要在服务更新期间保持可用。

该 Redis 集群采用 分片（sharding） 机制，每个主节点负责部分键空间（keyspace），由一段哈希 slot 范围定义。当客户端向不属于该 slot 的节点发送请求时，该节点会返回一个 MOVED 响应，指向正确的分片。客户端需要通过 CLUSTER SLOTS 命令获取集群拓扑信息，维护 slot 与节点的对应关系，从而正确地路由请求。

![Figure 1: Redis Cluster Sharding](/img/2025-10-30-scaling-redis-in-ambient-mesh-with-envoy-gateway/redis-cluster-sharding.png)

**图 1.** Redis 集群基于 key-slot 进行分片。客户端通过计算 `CRC16(key) % 16384` 来确定 slot，并将请求路由至对应的分片。

过去，Houzz 的应用程序在客户端库中自行实现这些路由逻辑。这导致应用与 Redis 集群拓扑之间高度耦合，也增加了不同语言 Redis 客户端开发和维护的复杂度。

---

## 使用 Istio Sidecar 与 EnvoyFilter 实现 Redis 集群支持

在迁移 Ambient Mesh 之前，Houzz 采用基于 sidecar 的方案，通过 Istio 的 EnvoyFilter API 支持 Redis 集群流量。

这种方式将 Redis 集群感知与 key-slot 路由逻辑从客户端中移出，由 Istio sidecar（istio-proxy）内的 Envoy 代理负责。具体包括：
- 在 Envoy 中定义一个 后端集群（backend cluster），包含所有 Redis 节点，用于基于 slot 的路由；
- 通过 本地监听器（local listener） 暴露一个回环地址（例如 127.0.10.1:6379），让应用看起来像在连接单节点 Redis；
- Envoy 的 Redis proxy filter 负责执行 CLUSTER SLOTS 查询、计算 key slot，并将命令转发至对应的 Redis 后端。

![Figure 2: Sidecar Redis Proxy](/img/2025-10-30-scaling-redis-in-ambient-mesh-with-envoy-gateway/sidecar-redis-proxy.png)

**图 2.** 左图：应用（如 PHP 客户端）直接连接多个 Redis 分片并自行实现路由逻辑。右图：Istio sidecar 中的 Envoy 代理负责计算 hash slot 并完成转发。

这种方式让开发者无需在应用代码中处理 Redis 集群逻辑，同时带来性能优化，例如连接复用——这对像 PHP-FPM 这种短生命周期连接模型尤其有帮助。


## 挑战：在无 Sidecar 的 Ambient 模式中支持 Redis

Istio 的 Ambient 模式移除了 Pod 内的 sidecar 代理，大幅降低了资源消耗并简化了运维。然而，当 Houzz 试图在 Ambient 模式中运行 Redis 时遇到关键问题：** Ambient Mesh 不支持通过 EnvoyFilter 配置 Redis 集群**。

在 sidecar 模式中，EnvoyFilter 可用来实现复杂的 Redis 行为，包括拓扑发现和基于 slot 的转发。而 Ambient Mesh 采用了不同的架构：
* ztunnel 进程负责透明地捕获应用流量；
* 可选的 Waypoint 代理 处理 L7 逻辑；
* 并不支持自定义 L7 过滤器（如 envoy.filters.network.redis_proxy）。

因此，在 Ambient 模式下，Houzz 的应用无法像在 Sidecar 模式中那样透明地连接 Redis 集群。Redis 客户端在收到 MOVED 响应时，由于不了解集群拓扑，无法自行完成请求重定向，最终导致访问失败。

这成为 Houzz 推动 Ambient Mesh 更大范围落地的主要阻碍——即便 Ambient 在资源开销和运维体验上表现出明显优势。

## 解决方案：使用 Envoy Gateway 作为 Redis 的 Waypoint 代理

为了解决上述问题，Houzz 与 Tetrate 的联合团队设计了一种方案：在 Ambient Mesh 中使用 Envoy Gateway 作为可编程的 Waypoint Proxy。
Envoy Gateway 支持 Redis Filter，并可通过 EnvoyPatchPolicy 灵活扩展，从而在无 sidecar 的环境下实现第七层（L7）流量控制。

整个架构的工作原理如下：
* ztunnel 捕获来自应用 Pod 的 Redis 出站流量；
* 流量被转发至网格中的 Envoy Gateway Waypoint；
* Waypoint 通过 Envoy 的 Redis proxy filter 执行 CLUSTER SLOTS 查询，计算 key 的哈希 slot，并将命令路由到正确的 Redis 后端；
* 客户端无需感知集群拓扑，只需连接虚拟地址（如 redis:7000），即可像访问单节点 Redis 一样使用。

![Figure 3: Ambient Mesh Redis Waypoint](/img/2025-10-30-scaling-redis-in-ambient-mesh-with-envoy-gateway/ambient-mesh-redis-waypoint.png)

**图 3.** 在 Ambient Mesh 架构中，客户端连接至 Envoy Gateway Waypoint，由其负责管理 Redis 集群拓扑并将请求转发到正确的分片。

这种方式使得不同语言和框架的客户端都能获得一致的访问体验，无需在应用代码中嵌入任何与 Redis 集群相关的逻辑。同时，依托 Ambient 的无 sidecar 模式，该方案既保持了良好的性能表现，又具备出色的可扩展性。

## 部署演示：在 Ambient Mesh 中使用 Envoy Gateway 管理 Redis

本节将通过一个实际示例，演示如何在 Ambient Mesh 环境中使用 Envoy Gateway 管理 Redis 集群流量。你将学习如何部署外部 Redis 集群、启用 Ambient 模式、安装 Envoy Gateway 作为 Waypoint 代理，并验证 Redis 流量是否能够正确地在网格中转发和路由。

本文假设你从一个全新的 Kubernetes 集群开始。示例使用本地 Kind 集群进行演示，但同样适用于任何标准的 Kubernetes 环境。

### 步骤 1：安装 Istio Ambient Mesh

首先安装 Istio 并启用 Ambient 模式：

```shell
istioctl install --set profile=ambient
```

Ambient mode installs the ztunnel component, which captures and redirects traffic without sidecar injection. This enables lower resource usage per workload.

### 步骤 2：安装 Envoy Gateway

接下来，安装 Envoy Gateway，它将作为 Waypoint Proxy 来处理 Redis 集群的流量路由。

```shell
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v1.5.4 \
  --set config.envoyGateway.provider.kubernetes.deploy.type=GatewayNamespace \
  --set config.envoyGateway.extensionApis.enableEnvoyPatchPolicy=true \
  -n envoy-gateway-system \
  --create-namespace
```

该安装命令启用了 EnvoyPatchPolicy 扩展功能，这是配置 Redis proxy 过滤器的前提条件。

### 步骤 3：部署 Redis 集群

在 external-redis 命名空间中部署一个 6 节点的 Redis 集群。该集群以集群模式运行，并在端口 7000 上对外提供服务。

```
apiVersion: v1
kind: Namespace
metadata:
  name: external-redis
---
apiVersion: v1
kind: ConfigMap
metadata:
  name: redis-cluster
  namespace: external-redis
data:
  update-node.sh: |
    #!/bin/sh
    REDIS_NODES="/data/nodes.conf"
    sed -i -e "/myself/ s/[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}\.[0-9]\{1,3\}/${POD_IP}/" ${REDIS_NODES}
    exec "$@"
  redis.conf: |+
    cluster-enabled yes
    cluster-require-full-coverage no
    cluster-node-timeout 15000
    cluster-config-file /data/nodes.conf
    cluster-migration-barrier 1
    appendonly yes
    protected-mode no
    port 7000
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: redis-cluster
  namespace: external-redis
spec:
  serviceName: redis-cluster
  replicas: 6
  selector:
    matchLabels:
      app: redis-cluster
  template:
    metadata:
      annotations:
        sidecar.istio.io/inject: "false"
      labels:
        app: redis-cluster
    spec:
      containers:
        - name: redis
          image: redis
          ports:
            - containerPort: 7000
              name: tcp-redis
            - containerPort: 17000
              name: tcp-gossip
          command: ["/conf/update-node.sh", "redis-server", "/conf/redis.conf", "--cluster-announce-ip $(POD_IP)"]
          env:
            - name: POD_IP
              valueFrom:
                fieldRef:
                  fieldPath: status.podIP
          volumeMounts:
            - name: conf
              mountPath: /conf
              readOnly: false
      volumes:
        - name: conf
          configMap:
            name: redis-cluster
            defaultMode: 0755
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: external-redis
spec:
  type: ClusterIP
  ports:
    - port: 7000
      targetPort: 7000
      name: tcp-redis
  selector:
    app: redis-cluster
```

等待 StatefulSet 启动并准备就绪：

```shell
kubectl -n external-redis rollout status --watch statefulset/redis-cluster --timeout=600s
kubectl -n external-redis wait pod --selector=app=redis-cluster --for=condition=ContainersReady=True --timeout=600s -o jsonpath='{.status.podIP}'
```

然后初始化 Redis 集群：

```shell
kubectl exec -it redis-cluster-0 -c redis -n external-redis -- redis-cli --cluster create --cluster-yes --cluster-replicas 1 $(kubectl get pod -n external-redis -l=app=redis-cluster -o json | jq -r '.items[] | .status.podIP + ":7000"')
```

当输出中显示所有 16,384 个哈希槽（hash slot）都已分配并同步完成时，说明 Redis 集群已部署成功。

```shell
>>> Performing hash slots allocation on 6 nodes...
Master[0] -> Slots 0 - 5460
Master[1] -> Slots 5461 - 10922
Master[2] -> Slots 10923 - 16383
Adding replica 10.244.0.16:7000 to 10.244.0.12:7000
Adding replica 10.244.0.17:7000 to 10.244.0.13:7000
Adding replica 10.244.0.15:7000 to 10.244.0.14:7000
... omitted for brevity
[OK] All nodes agree about slots configuration.
>>> Check for open slots...
>>> Check slots coverage...
[OK] All 16384 slots covered.
```

### 步骤 4：部署 Redis 客户端 Pod

部署一个 Redis 客户端 Pod，用于验证在 Ambient Mesh 中的 Redis 访问。

```
apiVersion: apps/v1
kind: Deployment
metadata:
  labels:
    app: redis-client
  name: redis-client
  namespace: default
spec:
  selector:
    matchLabels:
      app: redis-client
  template:
    metadata:
      annotations:
        sidecar.istio.io/logLevel: debug
      labels:
        app: redis-client
    spec:
      containers:
        - image: redis
          imagePullPolicy: Always
          name: redis-client
```

该 Pod 将作为测试客户端，用于验证 Envoy Gateway 的路由行为。

### 步骤 5：将 Envoy Gateway 配置为 Redis Waypoint 代理

在此步骤中，我们将创建所需的 Gateway、GatewayClass、TCPRoute 以及 EnvoyPatchPolicy 资源。
EnvoyPatchPolicy 用于为 Envoy Gateway 添加 Redis proxy 过滤器，使其能够识别 Redis 协议并执行基于 slot 的路由。

注意： 如有需要，请将 redis.external-redis 替换为你自己的 Redis 服务地址。

```
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: waypoint
  namespace: envoy-gateway-system
spec:
  logging:
    level:
      default: debug
  provider:
    kubernetes:
      envoyDeployment:
        container:
          image: envoyproxy/envoy:v1.34.4
      envoyService:
        patch:
          type: StrategicMerge
          value:
            spec:
              ports:
              - name: fake-hbone-port
                port: 15008
                protocol: TCP
                targetPort: 15008
        type: ClusterIP
    type: Kubernetes
  telemetry:
    accessLog: {}
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/dataplane-mode: ambient
  name: redis-waypoint
  namespace: default
spec:
  gatewayClassName: eg-waypoint
  listeners:
  - allowedRoutes:
      namespaces:
        from: All
    name: redis
    port: 7000
    protocol: TCP
---
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg-waypoint
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: gateway.envoyproxy.io
    kind: EnvoyProxy
    name: waypoint
    namespace: envoy-gateway-system
---
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: TCPRoute
metadata:
  name: redis
  namespace: default
spec:
  parentRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: redis-waypoint
  rules:
  - backendRefs:
    - group: ""
      kind: Service
      name: redis
      port: 7000
      weight: 1
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyPatchPolicy
metadata:
  name: redis-envoy-patch-policy
  namespace: default
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: redis-waypoint
  type: JSONPatch
  jsonPatches:
  - name: default/redis-waypoint/redis
    type: type.googleapis.com/envoy.config.listener.v3.Listener
    operation:
      op: replace
      path: /filter_chains/0/filters/0
      value:
        name: envoy.filters.network.redis_proxy
        typed_config:
          '@type': type.googleapis.com/envoy.extensions.filters.network.redis_proxy.v3.RedisProxy
          prefix_routes:
            catch_all_route:
              cluster: redis_cluster
          settings:
            enable_redirection: true
            op_timeout: 5s
            dns_cache_config:
              name: dns_cache_for_redis
              dns_lookup_family: V4_ONLY
              max_hosts: 100
          stat_prefix: redis_stats
  - name: redis_cluster
    type: type.googleapis.com/envoy.config.cluster.v3.Cluster
    operation:
      op: add
      path: ""
      value:
        name: redis_cluster
        connect_timeout: 10s
        cluster_type:
          name: envoy.clusters.redis
        load_assignment:
          cluster_name: redis-cluster
          endpoints:
          - lb_endpoints:
            - endpoint:
                address:
                  socket_address:
                    address: redis.external-redis # please replace with your redis service address
                    port_value: 7000
```

应用这些配置后，Envoy Gateway 将作为 Waypoint Proxy 拦截并处理来自应用的 Redis 流量。

### 步骤 6：创建供 Waypoint 拦截的 Redis 服务

在 default 命名空间下创建一个无选择器（selector-less）的 Service，用于供 ztunnel 拦截流量并转发至 Waypoint。

```
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: default
  labels:
    istio.io/use-waypoint: redis-waypoint
spec:
  ports:
    - port: 7000
      targetPort: 7000
      name: redis-port
      protocol: TCP
```

该 Service 不直接指向具体的 Pod，因为流量会被 ztunnel 拦截，转发给 Envoy Gateway 进行路由。

### 步骤 7：验证客户端访问

部署完成后，可通过 Redis 客户端 Pod 验证是否能正常访问 Redis。

进入客户端 Pod：

```shell
kubectl exec -it `kubectl get pod -l app=redis-client -o jsonpath="{.items[0].metadata.name}"` -c redis-client  -- redis-cli -h redis -p 7000
```

执行基本命令测试：

```shell
redis:7000> set foo bar
OK
redis:7000> get foo
"bar"
```

如果返回结果正确，说明 Redis 流量已成功通过 Envoy Gateway Waypoint 路由。

你还可以查看 Envoy Gateway 的日志，确认 Redis proxy 过滤器是否在工作：

```shell
kubectl logs deployments/redis-waypoint |grep redis_proxy
```

日志中应包含类似以下的调试输出：

```
[2025-08-13 09:29:25.636][43][debug][redis] [source/extensions/filters/network/redis_proxy/command_splitter_impl.cc:886] splitting '["set", "foo", "bar"]'
[2025-08-13 09:29:28.100][43][debug][redis] [source/extensions/filters/network/redis_proxy/command_splitter_impl.cc:886] splitting '["get", "foo"]'
```

这表明 Envoy 已正确解析并路由 Redis 命令。

## 小结

本实践验证表明，借助 Envoy Gateway 作为 Waypoint Proxy，可以在 Istio Ambient Mesh 中高效、稳定地运行 Redis 集群。
通过将集群拓扑发现与基于 slot 的请求路由逻辑从应用层迁移至 Envoy 层，该方案有效消除了对 Redis 集群感知型客户端库的依赖，从而简化了多语言应用的开发与维护工作。

同时，由于 Ambient 模式移除了 Pod 内的 sidecar，整个系统在资源消耗、运维复杂度以及扩展性方面都显著优于传统的 sidecar 架构。
集中化的 Envoy Gateway 代理还能复用连接、统一管理 Redis 流量，并在短连接场景（如 PHP-FPM）中显著提升性能。

总体而言，该方案为在 Ambient Mesh 中运行 有状态、非 HTTP 协议（如 Redis）提供了一种可扩展、易维护、低开销的架构选择。这不仅拓宽了 Ambient Mesh 的应用边界，也为未来在服务网格中管理更多复杂协议打下了基础。

## 参考资料

- [Use Envoy Gateway as the Unified Ingress Gateway and Waypoint Proxy for Ambient Mesh](https://www.cncf.io/blog/2025/08/26/use-envoy-gateway-as-the-unified-ingress-gateway-and-waypoint-proxy-for-ambient-mesh/)
- [GitHub Repo: redis-cluster-eg-waypoint](https://github.com/zhaohuabing/redis-cluser-eg-waypoint)
- [Istio Ambient Mesh](https://istio.io/latest/docs/ambient/)
- [Manage Redis with Aeraki Mesh](https://www.zhaohuabing.com/post/2023-05-08-manage-redis-with-aeraki-mes-eng)
