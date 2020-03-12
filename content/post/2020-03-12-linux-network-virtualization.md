---
layout:     post

title:      "Linux network namespace， veth， birdge与路由"
subtitle:   ""
excerpt: ""
author:     "赵化冰"
date:       2020-03-12
description: "介绍Linux的network namespace, veth，bridge与路由。"
image: "https://images.pexels.com/photos/1141853/pexels-photo-1141853.jpeg"
published: true 
tags:
    - Network
    - Linux
categories: [ Tech ]
---

# Network Namespace

A namespace wraps a global system resource in an abstraction that makes it appear to the processes within the namespace that they have  their own isolated instance of the global resource.  Changes to the  global resource are visible to other processes that are members of the namespace, but are invisible to other processes.  One use of       namespaces is to implement containers. (摘录自[Linux man page](http://man7.org/linux/man-pages/man7/namespaces.7.html)中对namespace的介绍)

Namespace是Linux提供的一种对于系统全局资源的隔离机制；从进程的视角来看，同一个namespace中的进程看到的是该namespace自己独立的一份全局资源，这些资源的变化只在本namespace中可见，对其他namespace没有影响。容器就是采用namespace机制实现了对网络，进程空间等的隔离。不同的Container（在K8S中是以Pod为单位）属于不同namespace，实现了Container或Pod之间的资源互相隔离，互不影响。

Linux提供了以下七种namespace：

| 类型    | 用途                                   |
| ------- | -------------------------------------- |
| Cgroup  | Cgroup root directory                  |
| IPC     | System V IPC,    POSIX message queues  |
| Network | Network devices,   stacks, ports, etc. |
| Mount   | Mount points                           |
| PID     | Process IDs                            |
| User    | User and group IDs                     |
| UTS     | Hostname and NIS  domain name          |

Network namespace允许你在Linux中创建相互隔离的网络视图，每个网络名字空间都有独立的网络配置，比如：网络设备、路由表等。新建的网络名字空间与主机默认网络名字空间之间是隔离的。我们平时默认操作的是主机的默认网络名字空间。

# Veth

The veth devices are virtual Ethernet devices.  They can act as tunnels between network namespaces to create a bridge to a physical network device in another namespace, but can also be used as standalone network devices. 

veth devices are always created in interconnected pairs.  A pair can be created using the command: 

```bash
# ip link add <p1-name> type veth peer name <p2-name> 
```

In the above, p1-name and p2-name are the names assigned to the two connected end points. Packets transmitted on one device in the pair are immediately received on the other device.  When either devices is down the link state of the pair is down.(摘录自[Linux man page](http://man7.org/linux/man-pages/man4/veth.4.html)中对veth的介绍)

从Linux Man page的描述可以看到，veth和tap/tun类似，也是linux提供的一种虚拟网络设备；但与tap/tun不同的是，veth总是成对出现的，从一端进入的数据包将会在另一端出现，因此又常常称为veth pair。我们可以把veth pair看成一条网线两端连接的两张以太网卡，如下图所示：

![](/img/2020-03-12-linux-network-virtualization/veth-pair.jpg)

由于network namespace隔离了网络相关的全局资源，因此从网络角度来看，一个network namespace可以看做一个独立的虚机；即使在同一个主机上创建的两个network namespace，相互之间缺省也是不能进行网络通信的。

veth提供了一种连接两个network namespace的方法。如果我们把上图中网线两端的网卡分别放入两个不同的network namespace，就可以把这两个network namespace连起来，形成一个点对点的二层网络，如下图所示：

```bash
            +------------------+              +------------------+
            |        ns1       |              |      ns2         |
            |                  |  veth pair   |                  |
            |                +-+              +-+                |
            | 192.168.1.1/24 | +--------------+ | 192.168.1.2/24 |
            |   (veth-ns1)   +-+              +-+   (veth-ns2)   |
            |                  |              |                  |
            |                  |              |                  |
            |                  |              |                  |
            +------------------+              +------------------+
```
下面我们通过试验来实现上图中的网络拓扑。首先创建两个network namespace ns1和ns2。
```bash
ip netns add ns1
ip netns add ns2
```
创建一个veth pair。
```bash
ip link add veth-ns1 type veth peer name veth-ns2
```
将veth pair一端的虚拟网卡放入ns1，另一端放入ns2，这样就相当于采用网线将两个network namespace连接起来了。
```bash
ip link set veth-ns1 netns ns1
ip link set veth-ns2 netns ns2
```
为两个网卡分别设置IP地址，这两个网卡的地址位于同一个子网192.168.1.0/24中。
```bash
ip -n ns1 addr add 192.168.1.1/24 dev veth-ns1
ip -n ns2 addr add 192.168.1.2/24 dev veth-ns2
```
使用ip link命令设置两张虚拟网卡状态为up。
```bash
ip -n ns1 link set veth-ns1 up
ip -n ns2 link set veth-ns2 up
```
从ns1 ping ns2的ip地址。
```bash
ip netns exec ns1 ping 192.168.1.2
PING 192.168.1.2 (192.168.1.2) 56(84) bytes of data.
64 bytes from 192.168.1.2: icmp_seq=1 ttl=64 time=0.147 ms
64 bytes from 192.168.1.2: icmp_seq=2 ttl=64 time=0.034 ms
```

#  Bridge

veth实现了点对点的虚拟连接，可以通过veth连接两个namespace，如果我们需要将3个或者多个namespace接入同一个二层网络时，就不能只使用veth了。在物理网络中，如果需要连接多个主机，我们会使用网桥，或者又称为交换机。Linux也提供了网桥的虚拟实现。下面我们试验通过Linux bridge来连接三个namespace。

该试验的网络拓扑如下图所示：

```bash
            +------------------+     +------------------+     +------------------+
            |                  |     |                  |     |                  |
            |                  |     |                  |     |                  |
            |                  |     |                  |     |                  |
            |       ns1        |     |       ns2        |     |       ns3        |
            |                  |     |                  |     |                  |
            |                  |     |                  |     |                  |
            |                  |     |                  |     |                  |
            |  192.168.1.1/24  |     |  192.168.1.2/24  |     |  192.168.1.3/24  |
            +----(veth-ns1)----+     +----(veth-ns2)----+     +----(veth-ns3)----+
                     +                          +                        +
                     |                          |                        |
                     |                          |                        |
                     +                          +                        +
            +--(veth-ns1-br)-------------(veth-ns2-br)------------(veth-ns3-br)--+
            |                                                                    |
            |                           virtual-bridge                           |
            |                                                                    |
            +--------------------------------------------------------------------+
```






# 参考文档

* [Linux man page: namespaces](http://man7.org/linux/man-pages/man7/namespaces.7.html)
* [Linux man page: veth](http://man7.org/linux/man-pages/man4/veth.4.html)