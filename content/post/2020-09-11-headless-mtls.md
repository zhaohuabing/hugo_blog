---
layout:     post

title:      "Istio 运维实战系列（2）：让人头大的『无头服务』-上"
subtitle:   ""
excerpt: ""
author:     "赵化冰"
date:       2020-09-11
description: "本系列文章将介绍用户从 Spring Cloud，Dubbo 等传统微服务框架迁移到 Istio 服务网格时的一些经验，以及在使用 Istio 过程中可能遇到的一些常见问题的解决方法。"
image: "https://images.pexels.com/photos/4458415/pexels-photo-4458415.jpeg?auto=compress&cs=tinysrgb&dpr=2&h=750&w=1260"
published: true
tags:
    - Istio
    - Envoy
categories: [ Tech ]
---
本系列文章将介绍用户从 Spring Cloud，Dubbo 等传统微服务框架迁移到 Istio 服务网格时的一些经验，以及在使用 Istio 过程中可能遇到的一些常见问题的解决方法。

# 什么是『无头服务』？

『无头服务』即 Kubernetes 中的 Headless Service。Service 是 Kubernetes 对后端一组提供相同服务的 Pod 的逻辑抽象和访问入口。Kubernetes 会根据调度算法为 Pod 分配一个运行节点，并随机分配一个 IP 地址；在很多情况下，我们还会对 Pod 进行水平伸缩，启动多个 Pod 来提供相同的服务。在有多个 Pod 并且 Pod IP 地址不固定的情况下，客户端很难通过 Pod 的 IP 地址来直接进行访问。为了解决这个问题，Kubernetes 采用 Service 资源来表示提供相同服务的一组 Pod。

在缺省情况下，Kubernetes 会为 Service 分配一个 Cluster IP，不管后端的 Pod IP 如何变化，Service 的 Cluster IP 始终是固定的。因此客户端可以通过这个 Cluster IP 来访问这一组 Pod 提供的服务，而无需再关注后端的各个真实的 Pod IP。我们可以将 Service 看做放在一组 Pod 前的一个负载均衡器，而 Cluster IP 就是该负载均衡器的地址，这个负载均衡器会关注后端这组 Pod 的变化，并把发向 Cluster IP 的请求转发到后端的 Pod 上。(备注：这只是对 Service 的一个简化描述，如果对 Service 的内部实现感兴趣，可以参考这篇文章[如何为服务网格选择入口网关？](https://zhaohuabing.com/post/2019-03-29-how-to-choose-ingress-for-service-mesh)）

对于无状态的应用来说，客户端并不在意其连接的是哪一个 Pod，采用 Service 是没有问题的。但在某些特殊情况下，并不能这样做。例如，如果后端的这一组 Pod 是有状态的，需要由客户端根据某种应用相关的算法来选择哪一个 Pod 提供服务；或者客户端需要连接所有的后端 Pod，这时我们就不能在这一组 Pod 前放一个负载均衡器了。这种情况下，我们需要采用 Headless Service，即无头服务（该命名把多个 Pod 前面的负载均衡器比作服务的头，很形象是不是？）。在定义 Headless Service，我们需要把 Service 的 Cluster IP 显示设置为 None，这样 Kubernetes DNS 在解析该 Service 时会直接返回其后端的多个 Pod IP，而不是 Service 的 Cluster IP。

假设从客户端访问一个 Redis 集群，采用带 Cluster IP 的普通 Service 和 Headless Service 的过程分别如下图所示：

![](/img/2020-09-11-headless-mtls/headless-service.png)

# Istio 中『无头服务』的 mTLS 故障

由于 Headless Service 的特殊性，Istio 中对 Headless Service 的处理和普通 Service 有所不同，在应用迁移到 Isito 的过程中也常常遇到由于 Headless Service 导致的一些问题。下面我们就一个由于 Headless Service 的 mTLS 故障导致的典型案例进行说明。

故障现象：运维同学反馈从带 Envoy Sidecar 的 Pod 中不能访问 Redis 服务器，但在没有安装 Sidecar 的 Pod 中可以正常访问该 Redis 服务器。

遇到无法进行出向访问的问题，我们可以首先通过 Envoy 的管理接口来查看 Envoy 的访问日志。在客户端 Pod 中运行下面的命令查看 Envoy 日志：

```bash
kubectl logs -f redis-client-6d4c6c975f-bm5w6 -c istio-proxy
```

日志中对 Redis 的访问记录如下，其中 UR，URX 是 Response Flag，表示 upstream connection failure，即连接上游失败。

```
[2020-09-12T13:38:23.077Z] "- - -" 0 UF,URX "-" "-" 0 0 1001 - "-" "-" "-" "-" "10.1.1.24:6379" outbound|6379||redis.default.svc.cluster.local - 10.1.1.24:6379 10.1.1.25:45940 - -
```

我们可以通过 Envoy 管理接口导出其 xDS 配置，以进一步分析其失败原因。

```bash
kubectl exec redis-client-6d4c6c975f-bm5w6 -c istio-proxy curl http://127.0.0.1:15000/config_dump
```

由于是出向访问错误，因此我们主要关注客户端中该出向访问的 Cluster 的配置。在导出的 xDS 配置中，可以看到 Redis Cluster 的配置如下面的 yaml 片段所示（为了方便读者查看，去掉了该 yaml 中一些无关的内容）：

```yaml
{
     "version_info": "2020-09-13T00:33:43Z/5",
     "cluster": {
      "@type": "type.googleapis.com/envoy.api.v2.Cluster",
      "name": "outbound|6379||redis.default.svc.cluster.local",
      "type": "ORIGINAL_DST",
      "connect_timeout": "1s",
      "lb_policy": "CLUSTER_PROVIDED",
      "circuit_breakers": {
        ...
      },

      # mTLS 相关设置
      "transport_socket": {
       "name": "envoy.transport_sockets.tls",
       "typed_config": {
        "@type": "type.googleapis.com/envoy.api.v2.auth.UpstreamTlsContext",
        "common_tls_context": {
         "alpn_protocols": [
          "istio-peer-exchange",
          "istio"
         ],

         # 访问 Redis 使用的客户端证书
         "tls_certificate_sds_secret_configs": [
          {
           "name": "default",
           "sds_config": {
            "api_config_source": {
             "api_type": "GRPC",
             "grpc_services": [
              {
                "envoy_grpc": {
                "cluster_name": "sds-grpc"
               }
              }
             ]
            }
           }
          }
         ],

         "combined_validation_context": {
          "default_validation_context": {
           # 用于验证 Redis 服务器身份的 spiffe indentity
           "verify_subject_alt_name": [
            "spiffe://cluster.local/ns/default/sa/default"
           ]
          },
          # 用于验证 Redis 服务器的根证书
          "validation_context_sds_secret_config": {
           "name": "ROOTCA",
           "sds_config": {
            "api_config_source": {
             "api_type": "GRPC",
             "grpc_services": [
              {
               "envoy_grpc": {
                "cluster_name": "sds-grpc"
               }
              }
             ]
            }
           }
          }
         }
        },
        "sni": "outbound_.6379_._.redis.default.svc.cluster.local"
       }
      },
      "filters": [
       {
         ...
       }
      ]
     },
     "last_updated": "2020-09-13T00:33:43.862Z"
    }
```

在 transport_socket 部分的配置中，我们可以看到 Envoy 中配置了访问 Redis Cluster 的 tls 证书信息，包括 Envoy Sidecar 用于访问 Redis 使用的客户端证书，用于验证 Redis 服务器证书的根证书，以及采用 spiffe 格式表示的，需验证的服务器端身份信息。 这里的证书相关内容是使用 xDS 协议中的 SDS（Secret discovery service） 获取的，由于篇幅原因在本文中不对此展开进行介绍。如果需要了解 Istio 的证书和 SDS 相关机制，可以参考这篇文章[一文带你彻底厘清 Isito 中的证书工作机制](https://zhaohuabing.com/post/2020-05-25-istio-certificate)。从上述配置可以得知，当收到 Redis 客户端发起的请求后，客户端 Pod 中的 Envoy Sidecar 会使用 mTLS 向 Redis 服务器发起请求。

Redis 客户端中 Envoy Sidecar 的 mTLS 配置本身看来并没有什么问题。但我们之前已经得知该 Redis 服务并未安装 Envoy Sidecar，因此实际上 Redis 服务器端只能接收 plain TCP 请求。这就导致了客户端 Envoy Sidecar 在向 Redis 服务器创建链接时失败了。

Redis 客户端以为是这样的：

![](/img/2020-09-11-headless-mtls/headless-mtls1.png)

但实际上是这样的：

![](/img/2020-09-11-headless-mtls/headless-mtls2.png)

在服务器端没有安装 Envoy Sidecar，不支持 mTLS 的情况下，按理客户端的 Envoy 不应该采用 mTLS 向服务器端发起连接。这是怎么回事呢？我们对比一下客户端 Envoy 中的其他 Cluster 中的相关配置。

一个访问正常的 Cluster 的 mTLS 相关配置如下：

```yaml
   {
     "version_info": "2020-09-13T00:32:39Z/4",
     "cluster": {
      "@type": "type.googleapis.com/envoy.api.v2.Cluster",
      "name": "outbound|8080||awesome-app.default.svc.cluster.local",
      "type": "EDS",
      "eds_cluster_config": {
       "eds_config": {
        "ads": {}
       },
       "service_name": "outbound|8080||awesome-app.default.svc.cluster.local"
      },
      "connect_timeout": "1s",
      "circuit_breakers": {
       ...
      },
      ...

      # mTLS 相关的配置
      "transport_socket_matches": [
       {
        "name": "tlsMode-istio",
        "match": {
         "tlsMode": "istio"  #对带有 "tlsMode": "istio" lable 的 endpoint，启用 mTLS
        },
        "transport_socket": {
         "name": "envoy.transport_sockets.tls",
         "typed_config": {
          "@type": "type.googleapis.com/envoy.api.v2.auth.UpstreamTlsContext",
          "common_tls_context": {
           "alpn_protocols": [
            "istio-peer-exchange",
            "istio",
            "h2"
           ],
           "tls_certificate_sds_secret_configs": [
            {
             "name": "default",
             "sds_config": {
              "api_config_source": {
               "api_type": "GRPC",
               "grpc_services": [
                {
                 "envoy_grpc": {
                  "cluster_name": "sds-grpc"
                 }
                }
               ]
              }
             }
            }
           ],
           "combined_validation_context": {
            "default_validation_context": {},
            "validation_context_sds_secret_config": {
             "name": "ROOTCA",
             "sds_config": {
              "api_config_source": {
               "api_type": "GRPC",
               "grpc_services": [
                {
                 "envoy_grpc": {
                  "cluster_name": "sds-grpc"
                 }
                }
               ]
              }
             }
            }
           }
          },
          "sni": "outbound_.6379_._.redis1.dubbo.svc.cluster.local"
         }
        }
       },
       {
        "name": "tlsMode-disabled",
        "match": {},   # 对所有其他的 enpoint，不启用 mTLS，使用 plain TCP 进行连接
        "transport_socket": {
         "name": "envoy.transport_sockets.raw_buffer"
        }
       }
      ]
     },
     "last_updated": "2020-09-13T00:32:39.535Z"
    }
```

从配置中可以看到，一个正常的 Cluster 中有两部分 mTLS 相关的配置：tlsMode-istio 和 tlsMode-disabled。tlsMode-istio 部分和 Redis Cluster 的配置类似，但包含一个匹配条件（match部分），该条件表示只对带有 "tlsMode" : "istio" lable 的 endpoint 启用 mTLS；对于不带有该标签的 endpoint 则会采用 tlsMode-disabled 部分的配置，使用 raw_buffer，即 plain TCP 进行连接。

查看 [Istio 的相关源代码](https://github.com/istio/istio/blob/514fb926e32fb95d8ee9b63d1741bf399c386a5e/pkg/kube/inject/webhook.go#L570)，可以得知，当 Istio webhook 向 Pod 中注入 Envoy Sidecar 时，会同时为 Pod 添加一系列 label，其中就包括 "tlsMode" : "istio" 这个 label，如下面的代码片段所示：

```go
  patchLabels := map[string]string{
		label.TLSMode:                                model.IstioMutualTLSModeLabel,
		model.IstioCanonicalServiceLabelName:         canonicalSvc,
		label.IstioRev:                               revision,
		model.IstioCanonicalServiceRevisionLabelName: canonicalRev,
	}
```

由于 Pod 在被注入 Envoy Sidecar 的同时被加上了该标签，客户端 Enovy Sidecar 在向该 Pod 发起连接时，根据 endpoint 中的标签匹配到 tlsMode-istio 中的配置，就会采用 mTLS；而如果一个 Pod 没有被注入 Envoy Sidecar，自然不会有该 Label，因此不能满足前面配置所示的匹配条件，客户端的 Envoy Sidecar 会根据 tlsMode-disabled 中的配置，采用 plain TCP 连接该 endpoint。这样同时兼容了服务器端支持和不支持 mTLS 两种情况。 

下图展示了 Istio 中是如何通过 endpoint 的标签来兼容 mTLS 和 plain TCP 两种情况的。

![](/img/2020-09-11-headless-mtls/istio-tlsmode-how.png)

通过和正常 Cluster 的对比，我们可以看到 Redis Cluster 的配置是有问题的，按理 Redis Cluster 的配置也应该通过 endpoint 的 tlsMode 标签进行判断，以决定客户端的 Envoy Sidecar 是通过 mTLS 还是 plain TCP 发起和 Redis 服务器的连接。但实际情况是 Redis Cluster 中只有 mTLS 的配置，导致了前面我们看到的连接失败故障。

Redis 是一个 Headless Service，通过在社区查找相关资料，发现 Istio 1.6 版本前对 Headless Service 的处理有问题，导致了该故障。参见这个 Issue [Istio 1.5 prevents all connection attempts to Redis (headless) service #21964](https://github.com/istio/istio/issues/21964)。

# 解决方案

找到了故障原因后，要解决这个问题就很简单了。我们可以通过一个 Destination Rule 禁用 Redis Service 的 mTLS。如下面的 yaml 片段所示：

```yaml
kind: DestinationRule
metadata:
  name: redis-disable-mtls
spec:
  host: redis.default.svc.cluster.local
  trafficPolicy:
    tls:
      mode: DISABLE 
```

再查看客户端 Envoy 中的 Redis Cluster 配置，可以看到 mTLS 已经被禁用，Cluster 中不再有 mTLS 相关的证书配置。

```yaml
    {
     "version_info": "2020-09-13T09:02:28Z/7",
     "cluster": {
      "@type": "type.googleapis.com/envoy.api.v2.Cluster",
      "name": "outbound|6379||redis.dubbo.svc.cluster.local",
      "type": "ORIGINAL_DST",
      "connect_timeout": "1s",
      "lb_policy": "CLUSTER_PROVIDED",
      "circuit_breakers": {
        ...
      },
      "metadata": {
       "filter_metadata": {
        "istio": {
         "config": "/apis/networking.istio.io/v1alpha3/namespaces/dubbo/destination-rule/redis-disable-mtls"
        }
       }
      },
      "filters": [
       {
        "name": "envoy.filters.network.upstream.metadata_exchange",
        "typed_config": {
         "@type": "type.googleapis.com/udpa.type.v1.TypedStruct",
         "type_url": "type.googleapis.com/envoy.tcp.metadataexchange.config.MetadataExchange",
         "value": {
          "protocol": "istio-peer-exchange"
         }
        }
       }
      ]
     },
     "last_updated": "2020-09-13T09:02:28.514Z"
    }
```

此时再尝试从客户端访问 Redis 服务器，一切正常！

# 小结

Headless Service 是 Kubernetes 中一种没有 Cluster IP 的特殊 Service，Istio 中对 Headless Service 的处理流程和普通 Service 有所不同。由于 Headless Service 的特殊性，我们在将应用迁移到 Istio 的过程中常常会遇到与此相关的问题。这次我们遇到的问题是由于 Istio 1.6 版本前对 Headless Service 处理的一个 Bug 导致无法连接到 Headless Service。该问题是一个高频故障，我们已经遇到过多次。可以通过创建Destination Rule 禁用 Headless Service 的 mTLS 来规避该问题。该故障在1.6版本中已经修复，建议尽快升级到 1.6 版本，以彻底解决本问题。除了这一个故障以外，我们还在迁移过程中遇到了其他一些关于 Headless Service 的有意思的问题，在下一篇文章中再继续和大家分享。


# 参考文档

* [如何为服务网格选择入口网关？](https://zhaohuabing.com/post/2019-03-29-how-to-choose-ingress-for-service-mesh)
* [Understanding Envoy Proxy HTTP Access Logs](https://blog.getambassador.io/understanding-envoy-proxy-and-ambassador-http-access-logs-fee7802a2ec5)
* [一文带你彻底厘清 Isito 中的证书工作机制](https://zhaohuabing.com/post/2020-05-25-istio-certificate)
