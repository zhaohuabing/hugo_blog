---
layout:     post

title:      "Istio Ambient 模式流量管理实现机制详解（二）"
subtitle:   "ztunnel 流量劫持"
description: ""
author: "赵化冰"
date: 2022-09-29
image: "https://images.unsplash.com/photo-1618564340323-28f633e4c748?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2340&q=80"
published: true
tags:
    - Istio
    - Envoy
    - Service Mesh
    - Ambient Mesh
categories: [ Tech ]
showtoc: true
---

ambient 模式中，应用 pod 通过 node 上的 ztunnel 之间创建的安全通道进行通信，如下图所示：
![](/img/2022-09-10-try-istio-ambient/app-in-ambient-secure-overlay.png)
那么 Istio 是如何将 pod 的流量发送到 ztunnel 的呢？ambient 模式采用了 iptables 规则和[策略路由（Policy-based Routing）](https://en.wikipedia.org/wiki/Policy-based_routing)来将 pod 的流量转发到 ztunnel。下面我们以 [初探 Istio Ambient 模式](https://www.zhaohuabing.com/post/2022-09-10-try-istio-ambient/) 中安装的 demo 为例来详细介绍 ambient 模式是如何对流量进行劫持，并转发到 ztunnel 中的。

kind 集群中有三个 node，如下所示：
```bash
~ k get node
NAME                    STATUS   ROLES           AGE    VERSION
ambient-control-plane   Ready    control-plane   4d9h   v1.25.0
ambient-worker          Ready    <none>          4d9h   v1.25.0
ambient-worker2         Ready    <none>          4d9h   v1.25.0
```
> 备注：试验环境采用的是 kind，kind 中的 node 实际上是一个 docker 容器。

在 ambient-worker2 这个 node 中运行了下面这些应用 pod。
```bash
k get pod -ocustom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName|grep ambient-worker2
productpage-v1-7c548b785b-mhjm6   10.244.2.3    ambient-worker2
ratings-v1-85c74b6cb4-t4pq6       10.244.2.2    ambient-worker2
reviews-v1-6494d87c7b-jnjcl       10.244.2.7    ambient-worker2
reviews-v2-79857b95b-m4lst        10.244.2.5    ambient-worker2
reviews-v3-75f494fccb-5jgzw       10.244.2.8    ambient-worker2
```

在 ambient-worker2 上部署了 ztunnel-gzlxs 来负责处理应用 pod 之间的通信。
```bash
~ k get pod -n istio-system -ocustom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName|grep ztunnel
ztunnel-gzlxs                          10.244.2.10   ambient-worker2
ztunnel-l5d98                          10.244.0.6    ambient-control-plane
ztunnel-w59fl                          10.244.1.19   ambient-worker
```

## outbound 方向

在 PREROUTING chain 的 mangle table 中增加了下面的规则，为源地址在 ztunnel-pods-ips 这个 ipset 中的数据包打上了一个标签 0x100。

```bash
-A PREROUTING -j ztunnel-PREROUTING
-A ztunnel-PREROUTING -p tcp -m set --match-set ztunnel-pods-ips src -j MARK --set-xmark 0x100/0x100
```

在 node 中通过 [ipset](https://ipset.netfilter.org/) 命令可以看到 node 中创建了一个 ztunnel-pods-ips ipset，该 ipset 是一个 ip 地址的集合，其中包含了该 node 上所有被 ambient 模式管理的 pod IP 地址。
```bash
~ docker exec ambient-worker2 ipset list
Name: ztunnel-pods-ips
10.244.2.5
10.244.2.2
10.244.2.3
10.244.2.8
10.244.2.7
```

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
查看 outbound 相关的策略路由规则，可以看到打上了 0x100 标签的数据包将采用 101 这个路由表。由于数据包的目的地址是 service ip，将采用缺省路由，通过 istioout 网络设备发送到 192.168.127.2。 

```bash
~ docker exec ambient-worker2 ip rule
101:	from all fwmark 0x100/0x100 lookup 101
```

```bash
~ docker exec ambient-worker2 ip route show table 101
default via 192.168.127.2 dev istioout
10.244.2.10 dev veth6cc9a213 scope link
```

为了区分请求目的地址为 service ip 和 pod ip 的数据包，ambient 采用了 [geneve tunnel](https://www.rfc-editor.org/rfc/rfc8926.html) 来将目的地址为 service ip 的数据包从 node 路由到 ztunnel pod 中。

查看 geneve tunnel 在 node 这一侧的设备：
```bash
~ ip addr|grep istioout
16: istioout: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default
    inet 192.168.127.1/30 brd 192.168.127.3 scope global istioout

~ ip -d link show istioout
16: istioout: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN mode DEFAULT group default
    link/ether 46:91:e0:6d:2e:25 brd ff:ff:ff:ff:ff:ff promiscuity 0
    geneve id 1001 remote 10.244.2.10 ttl auto dstport 6081 noudpcsum udp6zerocsumrx addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535
```

查看 geneve tunnel 在 ztunnel pod 这一侧的设备：
```bash
~ k -n istio-system exec  ztunnel-gzlxs -- ip addr|grep pistioout
4: pistioout: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN group default qlen 1000
    inet 192.168.127.2/30 scope global pistioout

 ~ k -n istio-system exec  ztunnel-gzlxs -- ip -d link show pistioout
4: pistioout: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/ether 8a:0f:80:ca:ae:d3 brd ff:ff:ff:ff:ff:ff promiscuity 0
    geneve id 1001 remote 10.244.2.1 ttl auto dstport 6081 noudpcsum udp6zerocsumrx addrgenmode eui64 numtxqueues 1 numrxqueues 1 gso_max_size 65536 gso_max_segs 65535
```

![](/img/2022-09-11-ambient-deep-dive-2/ztunnel-outbound.png)

。。。。。 未完待续

# 参考资料

* https://ipset.netfilter.org/










