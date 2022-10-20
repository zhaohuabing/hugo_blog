---
layout:     post

title:      "Istio Ambient 模式流量管理实现机制详解（二）"
subtitle:   "ztunnel 流量劫持"
description: "ambient 模式中，应用 pod 通过 ztunnel 之间的安全通道进行通信。要实现这一点，Istio 需要劫持应用 pod 的 outbound 和 inbound 流量，并转发到 ztunnel 进行处理。这是如何实现的呢？"
author: "赵化冰"
date: 2022-09-29
image: "https://images.unsplash.com/photo-1473800447596-01729482b8eb?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1740&q=80"
published: true
tags:
    - Istio
    - Envoy
    - Service Mesh
    - Ambient Mesh
categories: [ Tech ]
showtoc: true
---

ambient 模式中，应用 pod 通过 ztunnel 之间的安全通道进行通信。要实现这一点，Istio 需要劫持应用 pod 的 outbound 和 inbound 流量，并转发到 ztunnel 进行处理。这是如何实现的呢？

Istio 采用了 iptables 规则和[策略路由（Policy-based Routing）](https://en.wikipedia.org/wiki/Policy-based_routing)来将应用 pod 的流量转发到 ztunnel。下面我们以 [初探 Istio Ambient 模式](https://www.zhaohuabing.com/post/2022-09-10-try-istio-ambient/) 中安装的 demo 为例来详细介绍 ambient 模式是如何对流量进行劫持，并转发到 ztunnel 中的。

## 实验环境
实验环境采用了 kind 来安装 k8s 集群，集群中有三个 node，如下所示：
```bash
~ k get node
NAME                    STATUS   ROLES           AGE    VERSION
ambient-control-plane   Ready    control-plane   4d9h   v1.25.0
ambient-worker          Ready    <none>          4d9h   v1.25.0
ambient-worker2         Ready    <none>          4d9h   v1.25.0
```
> 备注：kind 使用一个 container 来模拟一个 node，在 container 里面跑 systemd ，并用 systemd 托管 kubelet 以及 containerd，然后通过容器内部的 kubelet 把其他 K8s 组件，比如 kube-apiserver、etcd、CNI 等跑起来。

在 ambient-worker2 这个 node 中运行了下面这些应用 pod。
```bash
~ k get pod -ocustom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName|grep ambient-worker2
productpage-v1-7c548b785b-mhjm6   10.244.2.3    ambient-worker2
ratings-v1-85c74b6cb4-t4pq6       10.244.2.2    ambient-worker2
reviews-v1-6494d87c7b-jnjcl       10.244.2.7    ambient-worker2
reviews-v2-79857b95b-m4lst        10.244.2.5    ambient-worker2
reviews-v3-75f494fccb-5jgzw       10.244.2.8    ambient-worker2
```

Istio 在 ambient-worker2 上部署了 ztunnel-gzlxs 来负责处理应用 pod 之间的通信。
```bash
~ k get pod -n istio-system -ocustom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName|grep ztunnel
ztunnel-gzlxs                          10.244.2.10   ambient-worker2
ztunnel-l5d98                          10.244.0.6    ambient-control-plane
ztunnel-w59fl                          10.244.1.19   ambient-worker
```

本文使用的 demo 中， pod 和 node 通过 [ptp](https://www.cni.dev/plugins/current/main/ptp/) 方式连接，即 pod 和 node 之间通过一个 veth pair 连接，并通过设置 node 上的路由规则来打通 pod 和 node 之间的网络。下文中流量劫持的相关分析也是基于 kubernetes ptp 网络的。（在编写本文时，ambient 还不支持 [bridige](https://www.cni.dev/plugins/current/main/bridge/) 模式。istio 社区正在进行支持 bridge 模式的相关工作。）

## outbound 流量劫持
outbound 方向的流量劫持主要涉及两个步骤：
1. 采用 node 上的 iptables 规则和策略路由将应用 pod 的 outbound 流量路由到 ztunnel pod。
2. 采用 TPROXY 将进入 ztunnel pod 的 outbound 流量重定向到 envoy 的 15001 端口。

下面我们来介绍 istio 在以上两个步骤中使用到的网络工具和实现原理。

### 应用 pod ipset
由于 kind 部署的 k8s 集群采用了 container 来模拟 node，我们可以采用 ```docker``` 命令进入 ambient-worker2 node。（由于 kind 集群中的 node 实际上是一个 docker container，因此我们可以通过 ```docker exec``` 命令进入 node。）

```bash
docker exec -it ambient-worker2 bash
```

进入 ambient-worker2 node 后，通过 [```ipset```](https://ipset.netfilter.org/) 命令可以看到 node 中创建了一个 ztunnel-pods-ips ipset，该 ipset 是一个 ip 地址的集合，其中包含了该 node 上所有被 ambient 模式管理的应用 pod IP 地址。istio-cni 会 watch node 上的 pod 事件，更新该 ipset 中的 ip 地址。
```bash
~ docker exec ambient-worker2 ipset list
Name: ztunnel-pods-ips
10.244.2.5
10.244.2.2
10.244.2.3
10.244.2.8
10.244.2.7
```
### node 上 outbound 方向的 iptables 规则
然后，我们通过 iptables 命令可以看到 istio-cni 在 node 的 PREROUTING chain 的 mangle table 中增加了下面的规则。
```bash
-A PREROUTING -j ztunnel-PREROUTING
-A ztunnel-PREROUTING -p tcp -m set --match-set ztunnel-pods-ips src -j MARK --set-xmark 0x100/0x100
```
该规则为源地址在 ztunnel-pods-ips 这个 ipset 中的数据包（即该 node 中所有应用 pod 的 outbound 流量）打上了一个标签 0x100。


从下面的 nat 表的规则中可以看到，kubernets 创建的 KUBE-SERVICE chain 被跳过了，因此在 ambient 模式中，应用发出的数据包中的请求目的地址并不会被转换为 pod ip。
```bash
# 首先进入 ztunnel-PREROUTING chain 进行处理
-A PREROUTING -j ztunnel-PREROUTING 
# KUBE-SERVICES chain 将 service ip dnat 到 pod ip
-A PREROUTING -m comment --comment "kubernetes service portals" -j KUBE-SERVICES 

...
# 带有 0x100 标签的数据包将直接跳过 PREROUTING chain 的后续处理，因此不会进行 dnat。
-A ztunnel-PREROUTING -m mark --mark 0x100/0x100 -j ACCEPT
```

### node 上 outbound 方向的策略路由
查看 outbound 相关的策略路由规则，可以看到打上了 0x100 标签的数据包将采用 101 这个路由表，将通过 istioout 网络设备发送到 192.168.127.2。istioout 是 istio-cni 创建的一个 geneve tunnel 设备，该 tunnel 连接了 node 和 ztunnel pod，192.168.127.2 是 tunnel 在 ztunnel pod 端的 ip 地址，我们将在下文中详细介绍该 tunnel。

```bash
~ docker exec ambient-worker2 ip rule
101:	from all fwmark 0x100/0x100 lookup 101
```

```bash
~ docker exec ambient-worker2 ip route show table 101
default via 192.168.127.2 dev istioout
10.244.2.10 dev veth6cc9a213 scope link
```
### istioout geneve tunnel

ambient 采用了 [geneve tunnel](https://www.rfc-editor.org/rfc/rfc8926.html) 来将应用 pod 的 outbound 数据包从 node 路由到 ztunnel pod 中。

查看 geneve tunnel 在 node 这一侧的设备，可以看到分配的地址为 ```192.168.127.1```，其 tunnel 的对端是 ```10.244.2.10```，即该 node 上的 ztunnel pod。
```bash
~ ip addr|grep istioout
16: istioout: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default
    inet 192.168.127.1/30 brd 192.168.127.3 scope global istioout

~ ip -d link show istioout
16: istioout: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN mode DEFAULT group default
    link/ether 46:91:e0:6d:2e:25 brd ff:ff:ff:ff:ff:ff promiscuity 0
    geneve id 1001 remote 10.244.2.10 ttl auto dstport 6081 noudpcsum udp6zerocsumrx addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535
```

查看 geneve tunnel 在 ztunnel pod 这一侧的设备，可以看到分配的地址为 ```192.168.127.2```，其 tunnel 的对端是 ```10.244.2.1```，即连接 ztunnel pod 和 node 的 veth pair 在 node 端的地址。
```bash
~ k -n istio-system exec  ztunnel-gzlxs -- ip addr|grep pistioout
4: pistioout: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    inet 192.168.127.2/30 scope global pistioout

 ~ k -n istio-system exec  ztunnel-gzlxs -- ip -d link show pistioout
4: pistioout: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether 8a:0f:80:ca:ae:d3 brd ff:ff:ff:ff:ff:ff promiscuity 0
    geneve id 1001 remote 10.244.2.1 ttl auto dstport 6081 noudpcsum udp6zerocsumrx addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535
```

### 采用 TPROXY 将流量发送到 ztunnel
outbound 流量进入 ztunnel pod 后，采用透明代理(TPROXY)的方式发送到 ztunnel 的 oubtound 监听端口 15001。我看可以进入 ztunnel pod 查看对应的 iptables 规则。

```bash
~ k -n istio-system exec  ztunnel-gzlxs --  iptables-save|grep pistioout
-A PREROUTING -i pistioout -p tcp -j TPROXY --on-port 15001 --on-ip 127.0.0.1 --tproxy-mark 0x400/0xfff
```

### outbound 方向流量劫持总览
除了上文介绍的内容之外，outbound 流量的完整处理流程还涉及到流量如何从 pod 路由到 node（下图中箭头1），以及经过 ztunnel 处理后如何发出到其他 node（下图中箭头5,6,7）的过程。这些部分的流量路由和 istio 无关，本文不进行详细介绍，有兴趣了解的话可以参考 kubernetes [ptp CNI plugin](https://www.cni.dev/plugins/current/main/ptp/) 的介绍。如果使用不同的 CNI plugin，这些部分的流量路由实现也会有所不同。本例中，outbound 流量劫持的完整流程如下图所示：
![](/img/2022-09-11-ambient-deep-dive-2/ztunnel-outbound.png)
<center>ambient 模式 outbound 流量劫持（ptp 网络）</center>

## inbound 流量劫持
inbound 方向的流量劫持和 outbound 类似，也主要涉及两个步骤：

1. 采用 node 上的策略路由将应用 pod 的 outbound 流量路由到 ztunnel pod。
2. 采用 TPROXY 将进入 ztunnel pod 的 outbound 流量重定向到 envoy 的 15006 和 15008 端口。其中 15006 处理 plain tcp 数据，15008 处理 tls 数据。

下面我们来具体分析 inbound 方向流量劫持的实现原理。

### node 上 inbound 方向的策略路由
inbound 方向的流量会采用 100 这个路由表。从路由表中的规则中可以看到，目的地址是该 node 上应用 pod（10.244.2.*/24）的 IP 数据包将通过 istioin 这个设备路由到 192.168.126.2。istioin 是 istio-cni 创建的一个 geneve tunnel 设备，该 tunnel 连接了 node 和 ztunnel pod，192.168.126.2 是 tunnel 在 ztunnel pod 端的 ip 地址，我们将在下文中详细介绍该 tunnel。

```bash
~ docker exec ambient-worker2 ip rule
103:	from all lookup 100
```

```bash
~ docker exec ambient-worker2 ip route show table 100
10.244.2.2 via 192.168.126.2 dev istioin src 10.244.2.1
10.244.2.3 via 192.168.126.2 dev istioin src 10.244.2.1
10.244.2.5 via 192.168.126.2 dev istioin src 10.244.2.1
10.244.2.7 via 192.168.126.2 dev istioin src 10.244.2.1
10.244.2.8 via 192.168.126.2 dev istioin src 10.244.2.1
10.244.2.10 dev veth6cc9a213 scope link
```
### istioin geneve tunnel

和 outbound 的处理类似，istio 采用了[geneve tunnel](https://www.rfc-editor.org/rfc/rfc8926.html) 来将目的地址为 inbound 数据包从 node 路由到 ztunnel pod 中。

查看 geneve tunnel 在 node 这一侧的设备，可以看到分配的地址为 ```192.168.126.1```，其 tunnel 的对端是 ```10.244.2.10```，即该 node 上的 ztunnel pod。
```bash
~ docker exec ambient-worker2 ip addr|grep istioin
15: istioin: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default
    inet 192.168.126.1/30 brd 192.168.126.3 scope global istioin

~ docker exec ambient-worker2 ip -d link show istioin
15: istioin: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN mode DEFAULT group default
    link/ether 06:8e:86:eb:6e:34 brd ff:ff:ff:ff:ff:ff promiscuity 0
    geneve id 1000 remote 10.244.2.10 ttl auto dstport 6081 noudpcsum udp6zerocsumrx addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535
```

查看 geneve tunnel 在 ztunnel pod 这一侧的设备，可以看到分配的地址为 ```192.168.126.2```，其 tunnel 的对端是 ```10.244.2.1```，即连接 ztunnel pod 和 node 的 veth pair 在 node 端的地址。
```bash
~ k -n istio-system exec  ztunnel-gzlxs -- ip addr|grep pistioin
3: pistioin: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    inet 192.168.126.2/30 scope global pistioin

 ~ k -n istio-system exec  ztunnel-gzlxs -- ip -d link show pistioin
3: pistioin: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether 26:ea:c6:d4:ef:a2 brd ff:ff:ff:ff:ff:ff promiscuity 0
    geneve id 1000 remote 10.244.2.1 ttl auto dstport 6081 noudpcsum udp6zerocsumrx addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535
```
### 采用 TPROXY 将流量发送到 ztunnel
inbound 流量进入 ztunnel pod 后，采用透明代理(TPROXY)的方式发送到 ztunnel 的 oubtound 监听端口 15006(plain tcp)/15008(tls)。我看可以进入 ztunnel pod 查看对应的 iptables 规则。

```bash
k -n istio-system exec  ztunnel-gzlxs --  iptables-save|grep pistioin
# ztunnel 在 15008 端口对 inbound 的 tls 流量进行处理
-A PREROUTING -i pistioin -p tcp -m tcp --dport 15008 -j TPROXY --on-port 15008 --on-ip 127.0.0.1 --tproxy-mark 0x400/0xfff
# ztunnel 在 15006 端口对 inbound 的 plain tcp 流量进行处理
-A PREROUTING -i pistioin -p tcp -j TPROXY --on-port 15006 --on-ip 127.0.0.1 --tproxy-mark 0x400/0xfff
```

### inbound 方向流量劫持总览
除了上文介绍的内容之外，inbound 流量的完整处理流程还涉及到流量经过 ztunnel 处理后路由到应用 pod（下图中箭头5,6,7）的过程。这些部分的流量路由和 istio 无关，本文不进行详细介绍，有兴趣了解的话可以参考 kubernetes [ptp CNI plugin](https://www.cni.dev/plugins/current/main/ptp/) 的介绍。如果使用不同的 CNI plugin，这些部分的流量路由实现也会有所不同。本例中，inbound 流量劫持的完整流程如下图所示：
![](/img/2022-09-11-ambient-deep-dive-2/ztunnel-inbound.png)
<center>ambient 模式 inbound 流量劫持（ptp 网络）</center>

# 小结
在本文中，我们详细分析了 Istio ambient 模式是如何劫持应用 pod 的流量，并将其转发到 ztunnel pod 的。ambient 模式下采用了 iptables，策略路由和 TPROXY 等 linux 的网络工具来对流量进行拦截和路由。从上文的分析中可以看到，由于 ambient 模式修改了 node 上的 iptables 规则和路由，和某些 k8s cni 插件可能出现冲突。相对而言，sidecar 模式只会影响到 pod 自身的 network namespace，和 k8s cni 的兼容性较好。ambient 模式目前只支持[ptp](https://www.cni.dev/plugins/current/main/ptp/) 类型的 k8s 网络，[bridige](https://www.cni.dev/plugins/current/main/bridge/) 模式的支持工作正在进行中。 在本系列的下一篇文章中，我们将继续深入分析 ztunnel 内部对四层流量的处理流程。

# 参考资料

* https://ipset.netfilter.org/
* [policy-based routing](https://docs.pica8.com/display/PicOS21118sp/IP+Rule+of+Management+Network+and+Service+Network#IPRuleofManagementNetworkandServiceNetwork-PolicyRoutingRules)









