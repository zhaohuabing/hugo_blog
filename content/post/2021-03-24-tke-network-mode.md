---
layout:     post

title:      "腾讯云容器网络介绍"
subtitle:   ""
description: "在实现 K8s 网络模型时，为了应对不同的使用场景，TKE（Tencent Kubernetes Engine）提供了 Global Router 和 VPC-CNI 两种网络模式。本文中，我们将通过这两种模式下数据包的转发流程来分析这两种模式各自的实现原理。本文还会对比分析不同网络模式下的网络效率和资源使用情况，以便于大家在创建 TKE 集群时根据应用对网络的需求和使用成本选择合适的网络模型。"
author:     "赵化冰"
date:       2021-03-24
image: "https://images.pexels.com/photos/206901/pexels-photo-206901.jpeg?auto=compress&cs=tinysrgb&dpr=2&h=750&w=1260"
published: true
tags:
    - Tencent
    - TKE
    - Kubernetes
    - Network
categories: [ Tech ]
---

K8s 对于集群 Pod 的网络模型只有下面两点简单的要求：
* 节点上的 Pod 可以不通过 NAT 和其他任何节点上的 Pod 通信
* 节点上的代理（比如：系统守护进程、kubelet）可以和节点上的所有 Pod 通信

在实现该网络模型时，为了应对不同的使用场景，TKE（Tencent Kubernetes Engine）提供了 Global Router 和 VPC-CNI 两种网络模式。本文中，我们将通过这两种模式下数据包的转发流程来分析这两种模式各自的实现原理。本文还会对比分析不同网络模式下的网络效率和资源使用情况，以便于大家在创建 TKE 集群时根据应用对网络的需求和使用成本选择合适的网络模型。

# Global Router 模式

Global Router 模式下，容器网络和 VPC 网络处于不同的网段，这两个网段之间通过三层路由互通，IP 数据包不会经过 NAT 转换。Global Router 模式的原理如下图所示：

![](/img/2021-03-24-tke-network-mode/global-router.png)

Global Router 模式为每一个虚拟机分配了一个容器子网网段。一个虚拟机上的所有 Pod 处于同一个容器网段上，这些 Pod 之间通过虚拟机上的一个虚拟网桥实现了二层互通。当 Pod 要和本虚拟机之外的其他虚机或者 Pod 通信时，则需要通过虚拟机上的网桥 cbr0 和虚拟机的弹性网卡 eth0 进行路由中转。

假设上图 Node1 上的 Pod1（172.20.0.3) 发送了一个 IP 数据包到 Node2 上的 Pod4（172.20.0.66）。我们采用该例子来分析一下 Global Router 网络模式下 Pod 的流量是如何在容器网络和 VPC 网络中进行转发的。

## 出向 - 从 Pod 到虚机

通过 ```ip addr``` 命令查看 Pod 中的网络设备，可以看到 Pod1 中的 eth0 网卡。eth0 是一个 Veth 设备，我们通过 ```ethtool``` 命令可以看到其在虚拟机 namespace 中的对端设备编号为6。

```bash
➜  ~ k exec network-tool-549c7756bd-bnc7x  -- ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
3: eth0@if6: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default 
    link/ether f6:b9:8c:3d:62:8c brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet 172.20.0.3/26 brd 172.20.0.63 scope global eth0
       valid_lft forever preferred_lft forever

➜  ~ k exec network-tool-549c7756bd-bnc7x  -- ethtool -S eth0
NIC statistics:
     peer_ifindex: 6
```

查看虚拟机 Node1 中的网络设备。可以看到编号为6的这张网卡。

```bash
[root@VM-0-29-centos ~]# ip addr
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
    inet 127.0.0.1/8 scope host lo
       valid_lft forever preferred_lft forever
    inet6 ::1/128 scope host 
       valid_lft forever preferred_lft forever
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP group default qlen 1000
    link/ether 52:54:00:cf:9f:ad brd ff:ff:ff:ff:ff:ff
    inet 10.0.0.29/24 brd 10.0.0.255 scope global noprefixroute eth0
       valid_lft forever preferred_lft forever
    inet6 fe80::5054:ff:fecf:9fad/64 scope link 
       valid_lft forever preferred_lft forever
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN group default 
    link/ether 02:42:07:83:f1:3a brd ff:ff:ff:ff:ff:ff
    inet 169.254.32.1/28 brd 169.254.32.15 scope global docker0
       valid_lft forever preferred_lft forever
4: cbr0: <BROADCAST,MULTICAST,PROMISC,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP group default qlen 1000
    link/ether f6:23:3e:66:b2:51 brd ff:ff:ff:ff:ff:ff
    inet 172.20.0.1/26 brd 172.20.0.63 scope global cbr0
       valid_lft forever preferred_lft forever
    inet6 fe80::f423:3eff:fe66:b251/64 scope link 
       valid_lft forever preferred_lft forever
5: Veth88a01d46@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master cbr0 state UP group default 
    link/ether 4e:02:63:5d:29:44 brd ff:ff:ff:ff:ff:ff link-netnsid 0
    inet6 fe80::4c02:63ff:fe5d:2944/64 scope link 
       valid_lft forever preferred_lft forever
6: Vethdc4b21b7@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master cbr0 state UP group default 
    link/ether 66:b8:19:aa:9f:91 brd ff:ff:ff:ff:ff:ff link-netnsid 1
    inet6 fe80::64b8:19ff:feaa:9f91/64 scope link 
       valid_lft forever preferred_lft forever
7: Veth91fbf97b@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master cbr0 state UP group default 
    link/ether 0a:17:bd:8e:7b:d4 brd ff:ff:ff:ff:ff:ff link-netnsid 2
    inet6 fe80::817:bdff:fe8e:7bd4/64 scope link 
       valid_lft forever preferred_lft forever
```

通过 ```ethtool``` 命令可以看到其在 Pod1 network namespace 中的对端设备编号为3

```bash
[root@VM-0-29-centos ~]# ethtool -S Vethdc4b21b7
NIC statistics:
     peer_ifindex: 3
```

备注：[Veth](https://zhaohuabing.com/post/2020-03-12-linux-network-virtualization/#Veth) 是 Linux 中的一种虚拟以太设备，Veth 设备总是成对出现的，因此又被称为 Veth pair。我们可以把 Veth 可以看做一条连接了两张网卡的网线，该网线一端的网卡在 Pod 的 Network Namespace 上，另一端的网卡在虚机的 Root Network Namespace 上，任何一张网卡发送的数据包，都可以在另一端的网卡上收到。因此当 Pod 将数据包通过其 eth0 发送出来时，虚机上就可以从 Veth pair 对端的网卡上收到该数据包。

![](/img/2020-03-12-linux-network-virtualization/Veth-pair.jpg)

在前面 Node1 ```ip link``` 命令输出中，我们可以看到编号为4的网络设备，这是 Node1 上用于连接 Pod 的网桥 cbr0。

通过 ```ip link show master``` 命令，我们可以看到加入了网桥 cbr0 中的网卡。其中编号为6的网卡是 Pod1 eth0 在虚拟机 Network Namespace 的 Veth 对端设备。另一个编号为7的网卡是 Pod2 eth0 的 Veth pair 对端设备。

```bash
[root@VM-0-29-centos ~]# ip link show master cbr0
6: Vethdc4b21b7@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master cbr0 state UP mode DEFAULT group default 
    link/ether 66:b8:19:aa:9f:91 brd ff:ff:ff:ff:ff:ff link-netnsid 1
7: Veth91fbf97b@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue master cbr0 state UP mode DEFAULT group default 
    link/ether 0a:17:bd:8e:7b:d4 brd ff:ff:ff:ff:ff:ff link-netnsid 2
```

从上面的分析可以看到，虚拟机中有一个网桥，同一个虚拟机上的所有 Pod 通过 Veth pair 连到该网桥上，Pod 中的出向流量通过 Veth pair 到达了虚拟机中的网桥上。

## 出向 - 目的地为相同虚机节点上的 Pod

Pod1 中的路由表如下所示：

```bash
➜  ~ k exec network-tool-549c7756bd-bnc7x  -- route
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
default         172.20.0.1      0.0.0.0         UG    0      0        0 eth0
172.20.0.0      *               255.255.255.192 U     0      0        0 eth0
```

虚拟机 Node1 上所有 Pod 属于同一个 IP 子网 172.20.0.0/26，这些 Pod 都连接到了虚拟网桥 cbr0 上。如上面路由表的第二条路由条目所示，目地地为子网 172.20.0.0/26 的流量将通过源 Pod 的 eth0 发出去，eth0 的 Veth pair 对端网卡处于网桥上，因此网桥会收到该数据包。网桥收到数据包后，通过二层转发将该数据包从网桥上连接到目的 Pod 的端口发送出去，数据将到达该端的 Veth pair 对端，即该数据包的目的 Pod 上。

## 出向 - 从虚拟机到物理机

如果 Pod 发出的 IP 数据包的目的地址不属于虚拟机上的 Pod 网段，根据上面显示的 Pod 中的缺省路由，数据包会被发送到网关 172.0.0.1。

在前面 Node1 的 ```ip addr``` 命令行输出中，我们可以看到 172.0.0.1 实际上是虚拟网桥 cbr0 的地址。一般来说，网桥（备注：Linux 上的网桥实际上是一个二层交换机，而不是一个桥接设备）工作在二层上，用于连接同一个二层广播域（一个 IP 子网）上的所有节点，并不会处理三层包头。为什么 cbr0 会有一个 IP 地址，并充当了 Pod 的网关呢？

Linux 虚拟网桥比较特殊，可以同时工作在二层和三层上。Linux 虚拟网桥自身带有一张网卡，这张网卡可以设置一个IP地址，例如这里 cbr0 的 172.0.0.1。由于这张网桥自带的网卡和虚拟机上的所有 Pod 连接在同一个网桥上，因此这张网卡可以接收到 Pod 发出的二层数据帧。同时由于这张网卡处于虚拟机的 Root Namespace 中，因此可以参与虚拟机上的三层路由转发。

如下图所示，我们可以认为 172.0.0.1 这张网卡同时工作在网桥 cbr0 和一个连接了 Pod 子网 172.0.0.0/26 和 VPC 子网 10.0.0.0/24 的三层路由器上（虚拟机 Node1 开通了 IP forward，自身就相当于一个路由器）。

![](/img/2021-03-24-tke-network-mode/linux-bridge.png)

当 Pod 发出的数据包通过 Veth pair 到达网桥后，由于 Pod 路由规则指定的网关地址为 172.0.0.1，因此网桥上的这张网卡 172.0.0.1 会收到二层地址为自身 mac 地址的数据包。然后虚拟机会根据如下所示的路由规则进行转发。根据下面的第一条缺省路由，虚拟机则会通过自身 eth0 将数据包 forward 到缺省网关 10.0.0.1 上。

```bash
[root@VM-0-29-centos ~]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         10.0.0.1        0.0.0.0         UG    100    0        0 eth0
10.0.0.0        0.0.0.0         255.255.255.0   U     100    0        0 eth0
172.20.0.0      0.0.0.0         255.255.255.192 U     0      0        0 cbr0
```
其实网关 10.0.0.1 并不是一个真实存在的设备，数据包进入虚拟机的 eth0 后，会通过 [Virtio-networking](https://www.redhat.com/en/virtio-networking-series) 机制被发送到物理机。Virtio-networking 是一种在虚拟机和其宿主物理机之间传递网络数据包的机制，其作用和 Veth pair 类似，只不过 Veth pair 用于在两个 Network Namespace 之间传递网络数据，而 Virtio-networking 则用于在虚拟机和物理机传递网络数据。

Virtio-networking 有在 Kernel space 实现的 [vhost-net/virtio-net](https://www.redhat.com/en/blog/deep-dive-virtio-networking-and-vhost-net)方案，也有完全在 User space 实现的 [vhost-user/virtio-net](https://www.redhat.com/en/blog/how-vhost-user-came-being-virtio-networking-and-dpdk)方案。其中 vhost-net/virtio-net 方案的原理如下图所示：

![](/img/2021-03-24-tke-network-mode/2019-09-12-virtio-networking-fig3.png)
图源自：[Deep dive into Virtio-networking and vhost-net](https://www.redhat.com/en/blog/deep-dive-virtio-networking-and-vhost-net)

该图中包括了用于在虚拟机和物理机之间创建数据通道的控制面和传输数据的数据面。主要包含下面的组件：
* virtio-net device - qemu 为 guest vm 模拟的虚拟网卡。
* virtio-net driver - guest vm 中的网卡驱动。virtio-net device 被模拟为一个 PIC 设备，guest vm 网卡驱动采用 PCI 协议和虚拟网卡通信。
* vhost-net - 物理机 kernel 中 vhost handler 的实现，用于 offload hypervisor 的数据面，以提供更快的包转发路径。
* Tap - 采用了一个 [Tap](https://zhaohuabing.com/post/2020-02-24-linux-taptun/#undefined) 设备来作为 guest vm 在物理机侧的网络数据包出入口。

数据包从虚拟机发送到物理机的大致流程如下：
1. virtio-net driver 将要发送的数据包写入到一块共享内存中。
1. virtio-net 通过控制面通道通知 virtio-host 数据就绪。
1. vhost-net 从共享内存中读取数据。
1. vhost-net 将数据包写入到物理机上该虚拟机网卡对应的的 Tap 设备中。

Virtio-networking 的内容较多，只是该话题即可成为一系列文章。因此此处不再继续展开，我们简单地将其理解为一个虚拟机和物理机之间的网络数据传输通道即可。如果读者有兴趣的话可以阅读本文后面的相关参考资料。

## 出向 - 从源物理机到目的物理机

当物理机从 Tap 上收到 Pod 发出的数据包后，会根据一个下面这样的全局路由表判断其目的 Pod 地址所在的物理机节点。全局路由表指明了目的 Pod 子网所在的物理机地址。除此之外，由于 Pod 和虚拟机处于不同的三层网络，还需要指定从物理机上的哪个虚拟机节点进入 Pod 子网。

确定目的物理机地址后，会对原始的数据包进行 GRE 封包，通过物理机连接到的 Underlay Network 发送到目地物理机节点上。在本例中，由于数据包的目的地址处于子网 172.20.0.64/26，因此 GRE 封包后的目地 IP 地址为 host 2 的地址。

| VPC ID      | Pod Subnet | host IP| Node IP|
| ----------- | ----------- |----------- |----------- |
| 100      | 172.20.0.0/26       | host 1 IP |10.0.0.29|
| 100      | 172.20.0.64/26   | host 2 IP |10.0.0.37|

## 入向 - 从物理机到虚机

对端物理机 host2 上收到 host1 发出的数据包后，首先进行 GRE 解包，解包后得到该数据包的原始目的地址为 172.20.0.66。host2 上应该有一条路由规则，该路由规则将 Node2 的 IP 地址 10.0.0.37 作为 Pod 子网 172.20.0.64/26 的下一跳。根据这条路由规则，物理机将该数据包写入 Node2 对应的 Tap 设备上，通过 vhost-net/virtio-net 发送到虚拟机上的 eth0 上。

备注：由于无法登录到物理机上查看，这部分处理流程是根据相关资料推测得出的。如流程有误，欢迎大家斧正。

## 入向 - 从虚拟机到 Pod

Node2 上的路由规则如下所示。根据路由规则，目的地址为 172.20.0.64/26 子网的数据包被发送到了网桥 cbr0 上，然后通过网桥的二层转发发送到目地节点 172.20.0.67。

```bash
[root@VM-0-37-centos ~]# route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         10.0.0.1        0.0.0.0         UG    100    0        0 eth0
10.0.0.0        0.0.0.0         255.255.255.0   U     100    0        0 eth0
172.20.0.64     0.0.0.0         255.255.255.192 U     0      0        0 cbr0
```

## Global Router 模式实质

如果我们忽略 Global Router 模式的上述实现细节，以一个更高的视角来观看该模式，则该模式可以简化为下图：

虚拟机和容器处于不同的网络上，不同虚拟机上的 Pod 属于容器网络的不同子网，这些网络之间可以通过三层路由互通，数据包的地址不会经过 NAT 转换。

![](/img/2021-03-24-tke-network-mode/global-router-simplified.png)

# VPC-CNI 网络模式

在 VPC-CNI 网络模式下，Pod 与虚拟机都在一个 VPC 网络中，共享相同的 CIDR 网段。集群中所有的 Pod 属于同一个 VPC 子网。根据 Pod 的网卡是否为独立弹性网卡，VPC-CNI 又分为共享网卡和独占网卡两种模型。其中共享网卡模式的原理如下图所示：

![](/img/2021-03-24-tke-network-mode/vpc-cni.png)

从上图中可以看到，共享网卡模式使用了虚拟机上的同一个弹性网卡 eth1 作为该虚拟机上所有 Pod 流量的对外通道。该模式相对于独占网卡模式而言，对主机资源的消耗要小一些，但网络性能也会差一些。但相对于前面介绍的 Global Router 模式而言效率更高，因为 VPC-CNI 共享网卡模式中虚拟机上使用了一个独立的网卡作为 Pod 对外的通信通道。

假设上图 Node1 上的 Pod1（10.0.0.44) 发送一个 IP 数据包到 Node2 上的 Pod4（10.0.0.30）。我们采用该例子来分析一下 VPC-CNI 网络的共享网卡模式下 Pod 的流量是如何转发的。

## 出向 - 从 Pod 到虚机

在 VPC-CNI 模式下，集群中的所有 Pod 属于同一个 VPC 子网。在这种情况下，我们无法再像 Global Router模式一样采用一个 Linux 网桥来连接同一个虚拟机中的所有 Pod。因为由于子网相同，当 Pod 发出的数据包的目地 IP 地址是其他节点上的 Pod 时，网桥无法将该流量发出去。

VPC-CNI 模式通过在 Pod 设置缺省网关和静态 ARP 条目解决了该问题。Pod 中的路由表如下面的命令行输出所示。可以看到出向流量被发送到了缺省网关 169.254.1.1 。一般来说，缺省网关的地址应该和 Pod 的地址处于同一子网中，但这里使用的地址 169.254.1.1 并不在子网 10.0.0.0/24 中，因此无法通过 ARP 协议学习得到该 IP 对应的 MAC 地址。但在 Pod 的 arp 表中有一条 169.254.1.1 的条目，其对应的 MAC 地址为 e2:62:fb:d2:cb:28。那么 Pod 是如何得到缺省网关的 IP 地址的呢？我们可以看到该 ARP 条目的 Flags Mask 是 CM，[M 这个 mask 表示该条目是一条静态条目（Permanent entry）](https://www.geeksforgeeks.org/arp-command-in-linux-with-examples/)，静态条目并不是通过 arp 协议学习得到的，而是手动插入或者通过程序写入的。Pod 中该 apr 条目应该是 VPC CNI 插件在设置 Pod 网络时添加的。

```bash
➜  ~ k exec network-tool-549c7756bd-6tfkf -- route -n
Kernel IP routing table
Destination     Gateway         Genmask         Flags Metric Ref    Use Iface
0.0.0.0         169.254.1.1     0.0.0.0         UG    0      0        0 eth0
169.254.1.1     0.0.0.0         255.255.255.255 UH    0      0        0 eth0

➜  ~ k exec network-tool-549c7756bd-6tfkf -- arp     
Address                  HWtype  HWaddress           Flags Mask            Iface
169.254.1.1              ether   e2:62:fb:d2:cb:28   CM                    eth0
```

查看 Node1 中的网络设备，可以看到 e2:62:fb:d2:cb:28 对应于 Pod1 网卡在虚机 Node1 中的 Veth pair 对端 16: eni8ba8b48a483@if3。

因此 Pod 的网关地址 169.254.1.1 只是连接 Pod 和虚拟机的 Veth pair 对端设备在 Pod 路由表中的一个填充符，其 IP 地址具体是什么值并没有意义，这里采用了一个 169 保留网段的地址，可以避免占用 VPC 网段的地址。

```bash
[root@VM-0-49-centos ~]# ip link
1: lo: <LOOPBACK,UP,LOWER_UP> mtu 65536 qdisc noqueue state UNKNOWN mode DEFAULT group default qlen 1000
    link/loopback 00:00:00:00:00:00 brd 00:00:00:00:00:00
2: eth0: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000
    link/ether 52:54:00:6a:d6:a9 brd ff:ff:ff:ff:ff:ff
3: docker0: <NO-CARRIER,BROADCAST,MULTICAST,UP> mtu 1500 qdisc noqueue state DOWN mode DEFAULT group default 
    link/ether 02:42:99:5e:7a:5d brd ff:ff:ff:ff:ff:ff
4: eth1: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc fq_codel state UP mode DEFAULT group default qlen 1000
    link/ether 20:90:6f:cd:76:76 brd ff:ff:ff:ff:ff:ff
5: eni9cdadcec1a4@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default 
    link/ether 72:c9:77:c8:0d:99 brd ff:ff:ff:ff:ff:ff link-netnsid 0
6: eni90454969e0a@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default 
    link/ether d6:bb:78:55:14:a0 brd ff:ff:ff:ff:ff:ff link-netnsid 1
10: enia59decf1cc3@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default 
    link/ether e6:b6:ea:2c:b6:16 brd ff:ff:ff:ff:ff:ff link-netnsid 5
11: eniec98d9f243c@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default 
    link/ether aa:ab:c2:5d:05:90 brd ff:ff:ff:ff:ff:ff link-netnsid 2
13: eni78dddf1c1d5@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default 
    link/ether 02:00:e7:ff:5e:b1 brd ff:ff:ff:ff:ff:ff link-netnsid 4
16: eni8ba8b48a483@if3: <BROADCAST,MULTICAST,UP,LOWER_UP> mtu 1500 qdisc noqueue state UP mode DEFAULT group default 
    link/ether e2:62:fb:d2:cb:28 brd ff:ff:ff:ff:ff:ff link-netnsid 3
```

由于 Veth pair 连接了 Pod network namespace 和虚拟机的 root network namespace，因此当 Pod 通过其 eth0 发送数据包时，虚机上就可以从 Veth pair 对端的网卡上收到该数据包。

即通过缺省路由和设置 ARP 静态条目，Pod 的出向流量被从 Pod eth0 网卡发出，通过 Veth pair 发送到了虚拟机上。

## 出向 - 目的地为相同虚机节点上的 Pod

从 Pod 中出来的流量的目的地可能是同一虚机上的其他 Pod，也可以是其他虚机上的 Pod，或者同一 VPC 中的虚机。我们需要采用不同的网络路径对这些不同目的地的流量进行路由。但是在 VPC-CNI 网络中，所有节点上的 Pod 都属于同一个 IP 子网，因此无法按照数据包目的地址进行路由。为了解决该问题，虚机上采用了策略路由[Policy Based Route](https://en.wikipedia.org/wiki/Policy-based_routing)。策略路由是一种比普通路由算法更为灵活的路由方式，除了目地地址以外，策略路由还可以根据源地址、协议类型、端口等将来自 Pod 的出向流量路由到不同的目的地。

虚拟机 Node1 上的路由策略和路由表如下所示：

```bash
[root@VM-0-49-centos ~]# ip rule
0:	from all lookup local
512:	from all to 10.0.0.41 lookup main¹
512:	from all to 10.0.0.44 lookup main²
1536:	from 10.0.0.41 lookup 100³
1536:	from 10.0.0.44 lookup 100⁴
32766:	from all lookup main
32767:	from all lookup default

[root@VM-0-49-centos ~]# ip route show table main
default via 10.0.0.1 dev eth0 proto dhcp metric 100 
default via 10.0.0.1 dev eth1 proto dhcp metric 101 
10.0.0.0/24 dev eth0 proto kernel scope link src 10.0.0.49 metric 100 
10.0.0.41 dev eniec98d9f243c scope link⁵ 
10.0.0.44 dev eni8ba8b48a483 scope link⁶

[root@VM-0-49-centos ~]# ip route show table 100
default via 10.0.0.1 dev eth1 onlink
```
在上面 ```ip rule``` 命令输出的路由策略中，可以看到上标为 1 和 2 的两条路由策略指定目的地为本节点中 Pod 的 IP 包采用 main 路由表。在 main 路由表中，上标为 5 和 6 的两条路由将发送到这两个 IP 地址的数据包分别发送到了本节点的两个 Pod 的 Veth pair 对端设备上。[Veth pair 可以看做一条网线连接了两张网卡](https://zhaohuabing.com/post/2020-03-12-linux-network-virtualization/#Veth)，从 Veth pair 一端进入的数据包会原封不动地从另一端收到，因此这些数据包就这样被发送到了同一虚机节点上的其他 Pod 上。来自本虚拟机节点外部的其他流量到达虚拟机后，也是通过该条路由被发送到 Pod 上的。

## 出向 - 从虚拟机到物理机

类似地，上标为 3 和 4 的两条路由策略指定源地址为本虚拟机点中 Pod IP 地址的数据包采用 100 路由表。在该路由表中只有一条缺省路由，将这些数据包通过 eth1 接口发送到网关 10.0.0.1。 

在这之后的流程和 Global Router 模式相同，会采用 vhost-net/virtio-net 将数据包从虚拟机发送到物理机上。和 Global Router 唯一不同的是，VPC-CNI 采用了独立的弹性网卡 eth1 来处理 Pod 的流量，并未像 Global Router 模式一样使用虚拟机自身的 eth0。

## 出向 - 从源物理机到目的物理机
和 Global Router 模式类似，当物理机上收到 Pod 发出的数据包后，也会根据一个下面这样的全局路由表判断其目的 Pod 地址所在的物理机节点，然后进行 GRE 封包，通过物理机连接到的 Underlay Network 发送到目地物理机节点上。

由于集群中所有 Pod 都在同一个 VPC 子网中，vpc-cni 模式的全局路由表是按照 Pod 节点而不是子网粒度进行设置的。在本例中，由于数据包的目的地址是 10.0.0.30，因此 GRE 封包后的目地 IP 地址为 host 2 的地址。

| VPC ID      | Pod/Node IP | host IP
| ----------- | ----------- |----------- |
| 100      | 10.0.0.41       | host 1 IP |
| 100      | 10.0.0.44     | host 1 IP |
| 100      | 10.0.0.30     | host 2 IP |
| 100      | 10.0.0.35     | host 2 IP |

由于 Pod 和虚机机节点都处于 VPC 的子网中，因此 Pod 和虚拟机之间也可以直接进行通信，采用的是相同的路由表。VPC 中虚拟机之间的通信也是类似的原理。

## 入向 - 从物理机到虚机

对端物理机 host2 上收到 host1 发出的数据包后，首先进行 GRE 解包，解包后得到该数据包的原始目的地址为 10.0.0.30。然后根据 host2 上的路由规则将该数据包写入虚拟机节点 Node2 对应的 Tap 设备上，通过 vhost-net/virtio-net 发送到虚拟机上对应的网卡 eth1 上。

备注：由于无法登录到物理机上查看，这部分处理流程是根据相关资料推测得出的。如流程有误，欢迎大家斧正。

## 入向 - 从虚拟机到 Pod

虚拟机 Node2 上的 main 路由表中上标为 7 的路由条目将发向 10.0.0.3 的数据包通过 Veth pair 在虚拟机端的设备 eni0f548c70045 发送给 Pod 4。

``` bash
[root@VM-0-40-centos ~]# ip route show table main
default via 10.0.0.1 dev eth0 proto dhcp metric 100 
default via 10.0.0.1 dev eth1 proto dhcp metric 101 
10.0.0.0/24 dev eth0 proto kernel scope link src 10.0.0.22 metric 100 
10.0.0.30 dev eni0f548c70045 scope link⁷ 
10.0.0.35 dev eni353b4974c2c scope link
```

## 独占网卡模式

在独占网卡模式下，VPC-CNI 插件会在每一个 Pod 中插入一张独立的弹性网卡，相对于共享网卡模式而言，其性能更高，但资源消耗也更多。因此在相同规格的虚拟机上，独占网卡模式下能够支持的 Pod 会比共享网卡模式更少一些。

相对于共享网卡模式，独占网卡模式下的数据流量路径更简单清晰，如下图所示：

![](/img/2021-03-24-tke-network-mode/vpc-cni-exclusive-mode.png)

以图中 Node 1 为例，虚拟机上的弹性网卡被直接放到了 Pod1 和 Pod2 的 Network Namespace 中。和共享网卡模式不同的是，Pod 到虚拟机的流量无需经过 Veth pair 和共享网卡进行中转，直接通过 vhost-net/virtio-net 机制发送到了物理机上，因此效率更高。流量到达虚拟机后，后续的转发方式和共享网卡模式是完全相同的。

## VPC-CNI 模式实质

如果我们忽略上面介绍的这些技术细节，以上帝视角来看 VPC-CNI 模式，则可以把 VPC-CNI 网络模式看做一个扁平的二层网络，该网络中所有的虚拟机和 Pod 之间都可以直接进行通信，IP 地址不会经过 NAT 转换。

![](/img/2021-03-24-tke-network-mode/vpc-cni-simplified.png)

# TKE 网络模式小结

|网络模式|网络规划|流量出入口|网络效率|资源占用|成本|
|----|----|------|----|----|---|
|Global Router|容器网络独立于 VPC 网络，每个虚拟机节点一个独立容器子网网段。容器 IP 地址分配不占用 VPC 子网地址空间。|容器和虚拟机共享虚拟机弹性网卡。|网络效率一般，适用于对网络效率没有特殊要求的应用。|相对于其他两种模式，对主机资源占用最少。|低|
|VPC-CNI 共享网卡|Pod 与虚拟机都在一个 VPC 网络中，共享相同的 CIDR 网段。集群中所有的 Pod 属于同一个 VPC 子网。|虚拟机中所有容器共享一张单独的弹性网卡，不占用虚拟机自身的弹性网卡。|网络效率较高，适用于对网络效率要求较高的应用。|对主机资源占用相对于 Global Router 模式更多，但比独占网卡模式小。|中|
|VPC-CNI 独占网卡|Pod 与虚拟机都在一个 VPC 网络中，共享相同的 CIDR 网段。集群中所有的 Pod 属于同一个 VPC 子网。|虚拟机中每个 Pod 分配一张单独的弹性网卡。|网络效率最高，适合于对网络效率敏感的特殊应用，例如网关、实时媒体流等。|对主机资源占用最大。|高|

# 参考链接

* [腾讯云容器网络概述](https://cloud.tencent.com/document/product/457/50353)
* [弹性网卡使用限制](https://cloud.tencent.com/document/product/576/18527)
* [Linux 策略路由](https://man7.org/linux/man-pages/man8/ip-rule.8.html)
* [Deep dive into Virtio-networking and vhost-net](https://www.redhat.com/en/blog/deep-dive-virtio-networking-and-vhost-net)
* [Linux Tun/Tap 介绍](https://zhaohuabing.com/post/2020-02-24-linux-Taptun/#undefined)
* [Linux network namespace， Veth， birdge与路由](https://zhaohuabing.com/post/2020-03-12-linux-network-virtualization)
* [vhost-net/virtio-net 原理](https://www.eet-china.com/mp/a13515.html)
* [Virtio-networking series](https://www.redhat.com/en/virtio-networking-series)

