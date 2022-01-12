---
layout:     post

title:      "Envoy 源码流程图"
subtitle:   ""
description: "最近在实现 MetaProtocol 时阅读了 Envoy 相关的一些源码。这里将一些重要流程的时序图记录下来，以备后续查看。"
author:     "赵化冰"
date:       2021-08-11
image: "https://upload.wikimedia.org/wikipedia/commons/a/a3/Lake_in_Dome_Creek.jpg"
published: true
tags:
    - Envoy
categories: [ Tech ]
---

最近在实现 [MetaProtocol](https://github.com/aeraki-mesh/meta-protocol-proxy) 时阅读了 Envoy 相关的一些源码。这里将一些重要流程的时序图记录下来，以备后续查看。

# TCP Proxy

{{< figure src="/img/2021-08-11-envoy-code/tcpproxy.png" caption="TCP Proxy 时序图">}}

# Dubbo Proxy

{{< figure src="/img/2021-08-11-envoy-code/dubboproxy.png" caption="Dubbo Proxy 时序图">}}

# RDS

RDS（路由发现服务）的代码包括下面三个主要的流程：
* 订阅 RDS 
    * 执行线程：[Main Thread](https://blog.envoyproxy.io/envoy-threading-model-a8d44b922310)
    * 工作流程：RDS 订阅是在 HCM 配置工厂类中处理的，详细流程如下：
        1. Envoy 在初始化 Network Filter Chain 时调用 HttpConnectionManagerFilterConfigFactory 的 createFilterFactoryFromProtoTyped 方法。
        1. 该方法中会创建一个 RouteConfigProviderManager 对象。代码中只会创建一个单实例，所有的 HCM 初始化过程会共用一个 RouteConfigProviderManager Singleton 对象。由于所有 HCM 初始化都是在 Main Thread 中进行的，因此对该 Singleton 的访问不会存在并发冲突。[（相关代码）](https://github.com/envoyproxy/envoy/blob/c98cd1320d7aed7bfa1de2a8313d1d116e68833a/source/extensions/filters/network/http_connection_manager/config.cc#L158)
        1. 根据 HCM 的路由配置是 RDS 还是静态配置，分别创建 RdsRouteConfigProvider 或者 StaticRouteConfigProvider [（相关代码）](https://github.com/envoyproxy/envoy/blob/5b4bad85bd7adb923cf25dd319f8f3f45b7c2670/source/common/router/rds_impl.cc#L38)。该方法中会创建一个 RdsRouteConfigSubscription 对象，该对象负责具体的订阅逻辑，然后再以 RdsRouteConfigSubscription 作为参数来创建 RdsRouteConfigSubscription。注意这里 RdsRouteConfigProvider 实例是和 RDS 配置的 hash 值一一对应的，同样的 RDS 配置（即 config_source 和 route_config_name 相同），只会创建一个 RdsRouteConfigProvider，以避免多个 HCM 重复订阅相同的 RDS。如果一个 RDS 配置对应的 RdsRouteConfigProvider 已经存在，会将已有的 RdsRouteConfigProvider 返回给 HCM 。即多个 HCM 配置的 RDS 相同的话，会共用一个 RdsRouteConfigProvider 实例。 [（相关代码）](https://github.com/envoyproxy/envoy/blob/5b4bad85bd7adb923cf25dd319f8f3f45b7c2670/source/common/router/rds_impl.cc#L338)。
        1. 在 RdsRouteConfigSubscription 的构造方法中，会从 context 中拿到 ClusterManager 的SubscriptionFactory，然后通过 subscriptionFromConfigSource 方法对该 RDS 进行订阅。 subscriptionFromConfigSource 方法中会将自身作为SubscriptionCallbacks 参数，以接收 RDS 更新通知。[（相关代码）](https://github.com/envoyproxy/envoy/blob/5b4bad85bd7adb923cf25dd319f8f3f45b7c2670/source/common/router/rds_impl.cc#L95)
* 处理 RDS 的配置更新
    * 执行线程：[Main Thread](https://blog.envoyproxy.io/envoy-threading-model-a8d44b922310)
     * 工作流程：
       1. RdsRouteConfigSubscription 的 onConfigUpdate 方法收到 RDS 配置更新的回调，然后调用 RdsRouteConfigProvider 的 onConfigUpdate 方法。[（相关代码）](https://github.com/envoyproxy/envoy/blob/5b4bad85bd7adb923cf25dd319f8f3f45b7c2670/source/common/router/rds_impl.cc#L115)
       2. RdsRouteConfigProvider 通过 [Thread local storage](https://blog.envoyproxy.io/envoy-threading-model-a8d44b922310) 机制将配置更新到各个 worker thread 中。
* 使用 RDS 配置对请求进行路由 
    * 执行线程：[Worker Thread](https://blog.envoyproxy.io/envoy-threading-model-a8d44b922310)
    * 工作流程：
      1. Envoy 调用到 Network Filter Chain 中的 HCM filter。
      1. HCM filter 调用到 HTTP Filter Chain 中的 Router。
      2. Router 拿到缓存的 RDS 配置，根据 RDS 配置进行路由。
{{< figure src="/img/2021-08-11-envoy-code/rds.png" caption="RDS 时序图">}}