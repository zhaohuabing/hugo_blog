---
layout:     post

title:      "Istio流量管理机制深度解析"
subtitle:   ""
excerpt: ""
author:     "赵化冰"
date:       2018-09-25
description: ""
image: ""
published: true 
tags:
    - Istio 
    - Pilot
    - Envoy
    - Service Mesh 

categories: [ Tech ]
---

# 前言

Istio作为一个service mesh开源项目,其中最重要的功能就是对网格中微服务之间的流量进行管理,包括服务发现,请求路由和服务间的可靠通信。Istio实现了service mesh的控制面，并整合Envoy开源项目作为数据面的sidecar，一起对流量进行控制。

Istio体系中流量管理配置下发以及流量规则如何在数据面生效的机制相对比较复杂，通过官方文档容易管中窥豹，难以了解其实现原理。本文尝试结合系统架构、配置文件和代码对Istio流量管理的架构和实现机制进行分析，以达到从整体上理解Pilot和Envoy的流量管理机制的目的。

# Istio高层架构

Istio控制面中负责流量管理的组件为Pilot，Pilot的高层架构如下图所示：

![](/img/2018-09-25-istio-traffic-management-impl-intro/pilot-architecture.png)  
<center>Pilot Architecture（来自[Isio官网文档](https://istio.io/docs/concepts/traffic-management/)<sup>[[1]](#ref01)</sup>)</center>

根据上图,Pilot主要实现了下述功能：

## 统一的服务模型

Pilot定义了网格中服务的标准模型，这个标准模型独立于各种底层平台。由于有了该标准模型，各个不同的平台可以通过适配器和Pilot对接，将自己特有的服务数据格式转换为标准格式，填充到Pilot的标准模型中。

例如Pilot中的Kubernetes适配器通过Kubernetes API服务器得到kubernetes中service和pod的相关信息，然后翻译为标准模型提供给Pilot使用。通过适配器模式，Pilot还可以从Mesos, Cloud Foundry, Consul等平台中获取服务信息，还可以开发适配器将其他提供服务发现的组件集成到Pilot中。

## 标准数据面 API

Pilo使用了一套起源于Envoy项目的[标准数据面API](https://github.com/envoyproxy/data-plane-api/blob/master/API_OVERVIEW.md)<sup>[[2]](#ref02)</sup>来将服务信息和流量规则下发到数据面的sidecar中。

通过采用该标准API，Istio将控制面和数据面进行了解耦，为多种数据面sidecar实现提供了可能性。事实上基于该标准API已经实现了多种Sidecar代理和Istio的集成，除Istio目前集成的Envoy外，还可以和Linkerd, Nginmesh等第三方通信代理进行集成，也可以基于该API自己编写Sidecar实现。

控制面和数据面解耦是Istio后来居上，风头超过Service mesh鼻祖Linkerd的一招妙棋。Istio站在了控制面的高度上，而Linkerd则成为了可选的一种sidecar实现，可谓降维打击的一个典型案例！

数据面标准API也有利于生态圈的建立，开源，商业的各种sidecar以后可能百花齐放，用户也可以根据自己的业务场景选择不同的sidecar和控制面集成，如高吞吐量的，低延迟的，高安全性的等等。有实力的大厂商可以根据该API定制自己的sidecar，例如蚂蚁金服开源的Golang版本的Sidecar MOSN(Modular Observable Smart Netstub)（SOFAMesh中Golang版本的Sidecar)；小厂商则可以考虑采用成熟的开源项目或者提供服务的商业sidecar实现。

备注：Istio和Envoy项目联合制定了Envoy V2 API,并采用该API作为Istio控制面和数据面流量管理的标准接口。

## 业务DSL语言

Pilot还定义了一套DSL（Domain Specific Language）语言，DSL语言提供了面向业务的高层抽象，可以被运维人员理解和使用。运维人员使用该DSL定义流量规则并下发到Pilot，这些规则被Pilot翻译成数据面的配置，再通过标准API分发到Envoy实例，可以在运行期对微服务的流量进行控制和调整。

Pilot的规则DSL是采用K8S API Server中的[Custom Resource (CRD)](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources/)<sup>[[3]](#ref03)</sup>实现的，因此和其他资源类型如Service  Pod Deployment的创建和使用方法类似，都可以用Kubectl进行创建。

通过运用不同的流量规则，可以对网格中微服务进行精细化的流量控制，如按版本分流，断路器，故障注入，灰度发布等。

# Istio流量管理相关组件

我们可以通过下图了解Istio流量管理涉及到的相关组件。虽然该图来自Istio Github old pilot repo, 但图中描述的组件及流程和目前Pilot的最新代码的架构基本是一致的。

![](/img/2018-09-25-istio-traffic-management-impl-intro/traffic-managment-components.png)  
<center>Pilot Design Overview (来自[Istio old_pilot_repo](https://github.com/istio/old_pilot_repo/blob/master/doc/design.md)<sup>[[4]](#ref04)</sup>)</center>

图例说明：图中红色的线表示控制流，黑色的线表示数据流。蓝色部分为和Pilot相关的组件。

从上图可以看到，Istio中和流量管理相关的有以下组件：

## 控制面组件

### Discovery Services

对应的docker为gcr.io/istio-release/pilot,进程为pilot-discovery，该组件的功能包括：

* 从Service  provider（如kubernetes或者consul）中获取服务信息
* 从K8S API Server中获取流量规则(K8S CRD Resource)
* 将服务信息和流量规则转化为数据面可以理解的格式，通过标准的数据面API下发到网格中的各个sidecar中。

### K8S API Server

提供Pilot相关的CRD Resource的增、删、改、查。和Pilot相关的CRD有以下几种:

* Virtualservice：用于定义路由规则，如根据来源或 Header 制定规则，或在不同服务版本之间分拆流量。
* DestinationRule：定义目的服务的配置策略以及可路由子集。策略包括断路器、负载均衡以及 TLS 等。
* ServiceEntry：用 [ServiceEntry](https://istio.io/docs/reference/config/istio.networking.v1alpha3/#ServiceEntry) 可以向Istio中加入附加的服务条目，以使网格内可以向istio 服务网格之外的服务发出请求。
* Gateway：为网格配置网关，以允许一个服务可以被网格外部访问。
* EnvoyFilter：可以为Envoy配置过滤器。由于Envoy已经支持Lua过滤器，因此可以通过EnvoyFilter启用Lua过滤器，动态改变Envoy的过滤链行为。我之前一直在考虑如何才能动态扩展Envoy的能力，EnvoyFilter提供了很灵活的扩展性。

## 数据面组件

在数据面有两个进程pilot-agent和envoy，这两个进程被放在一个docker容器gcr.io/istio-release/proxyv2中。

### pilot-agent

该进程根据K8S API Server中的配置信息生成Envoy的配置文件，并负责启动Envoy进程。注意Envoy的大部分配置信息都是通过xDS接口从Pilot中动态获取的，因此Agent生成的只是用于初始化Envoy的少量静态配置。在后面的章节中，本文将对Agent生成的Envoy配置文件进行进一步分析。

### Envoy

Envoy由pilot-agent进程启动，启动后，Envoy读取pilot-agent为它生成的配置文件，然后根据该文件的配置获取到Pilot的地址，通过数据面标准API的xDS接口从pilot拉取动态配置信息，包括路由（route），监听器（listener），服务集群（cluster）和服务端点（endpoint）。Envoy初始化完成后，就根据这些配置信息对微服务间的通信进行寻址和路由。

## 命令行工具

kubectl和Istioctl，由于Istio的配置是基于K8S的CRD，因此可以直接采用kubectl对这些资源进行操作。Istioctl则针对Istio对CRD的操作进行了一些封装。Istioctl支持的功能参见该[表格](https://istio.io/docs/reference/commands/istioctl)。

# 数据面标准API
前面讲到，Pilot采用了一套标准的API来向数据面Sidecar提供服务发现，负载均衡池和路由表等流量管理的配置信息。该标准API的文档参见[Envoy v2 API](https://www.envoyproxy.io/docs/envoy/latest/configuration/overview/v2_overview)。[Envoy control plane](https://github.com/envoyproxy/go-control-plane/tree/master/envoy/api/v2)给出了v2 grpc接口相关的数据结构和接口。

（备注：Istio早期采用了Envoy v1 API，目前的版本中则使用V2 API，V1已被废弃）。

## 基本概念和术语

首先我们需要了解数据面API中涉及到的一些基本概念：

* Host/主机：能够进行网络通信的实体（如移动设备、服务器上的应用程序）。在此文档中，主机是逻辑网络应用程序。一块物理硬件上可能运行有多个主机，只要它们是可以独立寻址的。在EDS接口中，也使用“Endpoint”来表示一个应用实例，对应一个IP+Port的组合。
* Downstream/下游：下游主机连接到 Envoy，发送请求并接收响应。
* Upstream/上游：上游主机接收来自 Envoy 的连接和请求，并返回响应。
* Listener/监听器：监听器是命名网地址（例如，端口、unix domain socket等)，可以被下游客户端连接。Envoy 暴露一个或者多个监听器给下游主机连接。
* Cluster/集群：集群是指 Envoy 连接到的逻辑上相同的一组上游主机。Envoy 通过服务发现来发现集群的成员。可以选择通过主动健康检查来确定集群成员的健康状态。Envoy 通过负载均衡策略决定将请求路由到哪个集群成员。
* XDS服务接口
* Istio数据面API定义了xDS服务接口，Pilot通过该接口向数据面sidecar下发动态配置信息，以对Mesh中的数据流量进行控制。xDS中的DS表示discovery service，即发现服务，表示xDS接口使用动态发现的方式提供数据面所需的配置数据。而x则是一个代词，表示有多种discover service。这些发现服务及对应的数据结构如下：
* LDS (Listener Discovery Service)  [envoy.api.v2.Listener](https://github.com/envoyproxy/data-plane-api/blob/master/envoy/api/v2/lds.proto)
* CDS (Cluster Discovery Service)   [envoy.api.v2.RouteConfiguration](https://github.com/envoyproxy/data-plane-api/blob/master/envoy/api/v2/rds.proto)
* EDS (Endpoint Discovery Service)  [envoy.api.v2.Cluster](https://github.com/envoyproxy/data-plane-api/blob/master/envoy/api/v2/cds.proto)
* RDS (Route Discovery Service)     [envoy.api.v2.ClusterLoadAssignment](https://github.com/envoyproxy/data-plane-api/blob/master/envoy/api/v2/eds.proto)

## XDS服务接口的最终一致性考虑

xDS的几个接口是相互独立的，接口下发的配置数据是最终一致的。但在配置更新过程中，可能暂时出现各个接口的数据不匹配的情况，从而导致部分流量在更新过程中丢失。

设想这种场景：在CDS/EDS只知道cluster X的情况下,RDS的一条路由配置将指向Cluster X的流量调整到了Cluster Y。在CDS/EDS向Mesh中Envoy提供Cluster Y的更新前，这部分导向Cluster Y的流量将会因为Envoy不知道Cluster Y的信息而被丢弃。

对于某些应用来说，短暂的部分流量丢失是可以接受的，例如客户端重试可以解决该问题，并不影响业务逻辑。对于另一些场景来说，这种情况可能无法容忍。可以通过调整xDS接口的更新逻辑来避免该问题，对上面的情况，可以先通过CDS/EDS更新Y Cluster，然后再通过RDS将X的流量路由到Y。

一般来说，为了避免Envoy配置数据更新过程中出现流量丢失的情况，xDS接口应采用下面的顺序：

1. CDS 首先更新Cluster数据（如果有变化）
1. EDS 更新相应Cluster的Endpoint信息（如果有变化）
1. LDS 更新CDS/EDS相应的Listener。
1. RDS 最后更新新增Listener相关的Route配置。
1. 删除不再使用的CDS cluster和 EDS endpoints。

## ADS聚合发现服务

保证控制面下发数据一致性，避免流量在配置更新过程中丢失的另一个方式是使用ADS(Aggregated Discovery Services)，即聚合的发现服务。ADS通过一个gRPC流来发布所有的配置更新，以保证各个xDS接口的调用顺序，避免由于xDS接口更新顺序导致的配置数据不一致问题。

关于XDS接口的详细介绍可参考[xDS REST and gRPC protocol](https://github.com/envoyproxy/data-plane-api/blob/master/XDS_PROTOCOL.md)

# Bookinfo 示例程序分析

下面我们以Bookinfo为例对Istio中的流量管理机制，以及控制面和数据面的交互进行进一步分析。

## xDS接口调试方法

首先我们看看如何对xDS接口的相关数据进行查看和分析。Envoy v2接口采用了gRPC，由于gRPC是基于二进制的RPC协议，无法像V1的REST接口一样通过curl和浏览器进行进行分析。但我们还是可以通过Pilot和Envoy的调试接口查看xDS接口的相关数据。

### Pilot调试方法

Pilot在9093端口提供了下述[调试接口](https://github.com/istio/istio/tree/master/pilot/pkg/proxy/envoy/v2)下述方法查看xDS接口相关数据。

```
PILOT=istio-pilot.istio-system:9093

# What is sent to envoy
# Listeners and routes
curl $PILOT/debug/adsz

# Endpoints
curl $PILOT/debug/edsz

# Clusters
curl $PILOT/debug/cdsz
```

### Envoy调试方法

Envoy在localhost的15000端口提供了listener，cluster以及完整的配置数据导出功能。

```
kubectl exec productpage-v1-54b8b9f55-bx2dq -c istio-proxy curl http://127.0.0.1:15000/help
  /: Admin home page
  /certs: print certs on machine
  /clusters: upstream cluster status
  /config_dump: dump current Envoy configs (experimental)
  /cpuprofiler: enable/disable the CPU profiler
  /healthcheck/fail: cause the server to fail health checks
  /healthcheck/ok: cause the server to pass health checks
  /help: print out list of admin commands
  /hot_restart_version: print the hot restart compatibility version
  /listeners: print listener addresses
  /logging: query/change logging levels
  /quitquitquit: exit the server
  /reset_counters: reset all counters to zero
  /runtime: print runtime values
  /runtime_modify: modify runtime values
  /server_info: print server version/status information
  /stats: print server stats
  /stats/prometheus: print server stats in prometheus format
```

进入productpage pod 中的istio-proxy(Envoy) container查看监听端口

```
kubectl exec t productpage-v1-54b8b9f55-bx2dq -c istio-proxy --  netstat -ln
 
Proto Recv-Q Send-Q Local Address           Foreign Address         State       PID/Program name
tcp        0      0 0.0.0.0:9080            0.0.0.0:*               LISTEN      -               
tcp        0      0 127.0.0.1:15000         0.0.0.0:*               LISTEN      13/envoy        
tcp        0      0 0.0.0.0:15001           0.0.0.0:*               LISTEN      13/envoy  
``` 
 
### Envoy启动过程分析

Istio通过K8s的[Admission webhook](https://zhaohuabing.com/2018/05/23/istio-auto-injection-with-webhook/#admission-webhook)机制实现了sidecar的自动注入，Mesh中的每个微服务会被加入Envoy相关的容器。下面是Productpage微服务的Pod内容，可见除productpage之外，Istio还在该Pod中注入了两个容器gcr.io/istio-release/proxy_init和gcr.io/istio-release/proxyv2。

备注：下面Pod description中只保留了需要关注的内容，删除了其它不重要的部分。为方便查看，本文中后续的其它配置文件以及命令行输出也会进行类似处理。

```
ubuntu@envoy-test:~$ kubectl describe pod productpage-v1-54b8b9f55-bx2dq

Name:               productpage-v1-54b8b9f55-bx2dq
Namespace:          default
Init Containers:
  istio-init:
    Image:         gcr.io/istio-release/proxy_init:1.0.0
      Args:
      -p
      15001
      -u
      1337
      -m
      REDIRECT
      -i
      *
      -x

      -b
      9080,
      -d

Containers:
  productpage:
    Image:          istio/examples-bookinfo-productpage-v1:1.8.0
    Port:           9080/TCP
    
  istio-proxy:
    Image:         gcr.io/istio-release/proxyv2:1.0.0
    Args:
      proxy
      sidecar
      --configPath
      /etc/istio/proxy
      --binaryPath
      /usr/local/bin/envoy
      --serviceCluster
      productpage
      --drainDuration
      45s
      --parentShutdownDuration
      1m0s
      --discoveryAddress
      istio-pilot.istio-system:15007
      --discoveryRefreshDelay
      1s
      --zipkinAddress
      zipkin.istio-system:9411
      --connectTimeout
      10s
      --statsdUdpAddress
      istio-statsd-prom-bridge.istio-system:9125
      --proxyAdminPort
      15000
      --controlPlaneAuthPolicy
      NONE
```

#### proxy_init

Productpage的Pod中有一个InitContainer proxy_init，InitContrainer是K8S提供的机制，用于在Pod中执行一些初始化任务.在Initialcontainer执行完毕并退出后，才会启动Pod中的其它container。

我们看一下proxy_init容器中的内容：


```
ubuntu@envoy-test:~$ sudo docker inspect gcr.io/istio-release/proxy_init:1.0.0
[
    {
        "RepoTags": [
            "gcr.io/istio-release/proxy_init:1.0.0"
        ],

        "ContainerConfig": {
            "Env": [
                "PATH=/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
            ],
            "Cmd": [
                "/bin/sh",
                "-c",
                "#(nop) ",
                "ENTRYPOINT [\"/usr/local/bin/istio-iptables.sh\"]"
            ],
            "Entrypoint": [
                "/usr/local/bin/istio-iptables.sh"
            ],
        },
    }
]
```

从上面的命令行输出可以看到，Proxy_init中执行的命令是istio-iptables.sh，该脚本源码较长，就不列出来了，有兴趣可以在Istio 源码仓库的 tools/deb/istio-iptables.sh查看。
该脚本的作用是通过配置iptable来劫持Pod中的流量。结合前面Pod中该容器的命令行参数-p 15001，可以得知Pod中的数据流量被iptable拦截，并发向Envoy的15001端口。  -u 1337参数用于排除用户ID为1337，即Envoy自身的流量，以避免Iptable把Envoy发出的数据又重定向到Envoy，形成死循环。

# 参考资料

1. <a id="ref01">[Istio Traffic Managment Concept](https://istio.io/docs/concepts/traffic-management/#pilot-and-envoy)</a>
1. <a id="ref02">[Data Plane API](https://github.com/envoyproxy/data-plane-api/blob/master/API_OVERVIEW.md)</a>
1. <a id="ref03">[kubernetes Custom Resource](https://kubernetes.io/docs/concepts/extend-kubernetes/api-extension/custom-resources)</a>
1. <a id="ref04">[Istio Pilot design overview](https://github.com/istio/old_pilot_repo/blob/master/doc/design.md)</a>
1. <a id="ref05">[Envoy V2 API](https://www.envoyproxy.io/docs/envoy/latest/configuration/overview/v2_overview)</a>
