---
layout:     post

title:      "Istio Ambient 模式 HBONE 隧道原理详解 - 中"
subtitle:   ""
description: ""
author: "赵化冰"
date: 2022-09-14
image: "https://images.unsplash.com/photo-1558405588-0eff8afefeb3?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2662&q=80"
published: false
tags:
    - Istio
    - Envoy
    - Service Mesh
    - Ambient Mesh
categories: [ Tech ]
showtoc: true
---

Ambient 模式采用了[策略路由（Policy-based Routing）](https://en.wikipedia.org/wiki/Policy-based_routing)来将应用 workload 的流量转发到 ztunnel。


下面我们以 [初探 Istio Ambient 模式](https://www.zhaohuabing.com/post/2022-09-10-try-istio-ambient/) 中安装的 demo 为例来介绍 ambient 模式是如何对流量进行处理的。

kind 集群中有三个 node，如下所示：
```
~ k get node
NAME                    STATUS   ROLES           AGE    VERSION
ambient-control-plane   Ready    control-plane   4d9h   v1.25.0
ambient-worker          Ready    <none>          4d9h   v1.25.0
ambient-worker2         Ready    <none>          4d9h   v1.25.0
```

在 ambient-worker2 这个 node 中运行了下面这些应用 pod。
```
k get pod -ocustom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName|grep ambient-worker2
productpage-v1-7c548b785b-mhjm6   10.244.2.3    ambient-worker2
ratings-v1-85c74b6cb4-t4pq6       10.244.2.2    ambient-worker2
reviews-v1-6494d87c7b-jnjcl       10.244.2.7    ambient-worker2
reviews-v2-79857b95b-m4lst        10.244.2.5    ambient-worker2
reviews-v3-75f494fccb-5jgzw       10.244.2.8    ambient-worker2
```

在 node 中通过 [ipset](https://ipset.netfilter.org/) 命令可以看到 node 中创建了一个 ztunnel-pods-ips ipset，该 ipset 是一个 ip 地址的集合，其中包含了该 node 上所有被 ambient 模式管理的 pod IP 地址。

> 备注：试验环境采用的是 kind，kind 中的 node 实际上是一个 docker 容器。

```
~ docker exec ambient-worker2 ipset list
Name: ztunnel-pods-ips
Type: hash:ip
Revision: 0
Header: family inet hashsize 1024 maxelem 65536
Size in memory: 568
References: 1
Number of entries: 5
Members:
10.244.2.5
10.244.2.2
10.244.2.3
10.244.2.8
10.244.2.7
```

查看策略路由规则：

```bash
~ docker exec ambient-worker2 ip rule
0:	from all lookup local
100:	from all fwmark 0x200/0x200 goto 32766
101:	from all fwmark 0x100/0x100 lookup 101
102:	from all fwmark 0x40/0x40 lookup 102
103:	from all lookup 100
32766:	from all lookup main
32767:	from all lookup default
```

```bash
~ docker exec ambient-worker2 ip route show table 100
10.244.2.2 via 192.168.126.2 dev istioin src 10.244.2.1
10.244.2.3 via 192.168.126.2 dev istioin src 10.244.2.1
10.244.2.5 via 192.168.126.2 dev istioin src 10.244.2.1
10.244.2.7 via 192.168.126.2 dev istioin src 10.244.2.1
10.244.2.8 via 192.168.126.2 dev istioin src 10.244.2.1
10.244.2.10 dev veth6cc9a213 scope link
~ docker exec ambient-worker2 ip route show table 101
default via 192.168.127.2 dev istioout
10.244.2.10 dev veth6cc9a213 scope link
~ docker exec ambient-worker2 ip route show table 102
default via 10.244.2.10 dev veth6cc9a213 onlink
10.244.2.10 dev veth6cc9a213 scope link
```

```bash
~ k get pod -n istio-system -ocustom-columns=NAME:.metadata.name,IP:.status.podIP,NODE:.spec.nodeName|grep 10.244.2.10
ztunnel-gzlxs                          10.244.2.10   ambient-worker2
```

可以看到，该节点上







# 参考资料

* https://ipset.netfilter.org/










