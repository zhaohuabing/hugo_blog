---
layout:     post

title:      "Kubernetes知识图谱"
subtitle:   ""
excerpt: ""
author:     "Huabing Zhao"
date:       2020-02-22
description: "Kubernetes相关知识汇总"
image: "https://images.pexels.com/photos/1482193/pexels-photo-1482193.jpeg"
published: true
tags:
    - Kubernetes

categories: [ Knowledge Graph ]
showtoc: false
---

- Kubernetes
	- 基本理念
		- 自动化部署，缩扩容和管理容器应用
		- 预期状态管理(Desired State Management)
			- Kubernetes API 对象（声明预期状态）
			- Kubernetes Control Plane（确保集群当前状态匹配预期状态）
				- Kubernetes Master
					- kube-apiserver（API Server）
						- 对外提供各种对象的CRUD REST接口
						- 对外提供Watch机制，通知对象变化
						- 将对象存储到Etcd中
					- kube-controller-manager（守护进程）
						- 功能：通过apiserver监视集群的状态，并做出相应更改，以使得集群的当前状态向预期状态靠拢
						- controllers
							- replication controller
							- endpoints controller
							- namespace controller
							- serviceaccounts controller
							- ......
					-  kube-scheduler（调度器）
						- 功能：将Pod调度到合适的工作节点上运行
						- 调度的考虑因素
							- 资源需求
							- 服务治理要求
							- 硬件/软件/策略限制
							- 亲和以及反亲和要求
							- 数据局域性
							- 负载间的干扰
							- ......
				- Work Node
					- Kubelet（节点代理）
						- 接受通过各种机制（主要是通过apiserver）提供的一组PodSpec
						- 确保PodSpec中描述的容器处于运行状态且运行状况良好
					- Kube-proxy（节点网络代理）
						- 在节点上提供Kubernetes API中定义Service
						- 设置Service对应的IPtables规则
						- 进行流量转发（userspace模式）
    - 部署模式
		- Single node
		- Single head node，multiple workers
			- API Server，Scheduler，and Controller Manager run on a single node
		- Single etcd，HA heade nodes，multiple workers
			- Multiple API Server instances fronted by a load balancer
			- Multiple Scheduler and Controller Manager instances with leader election
			- Single etcd node
		- HA etcd，HA head nodes，multiple workers
			- Multiple API Server instances fronted by a load balancer
			- Multiple Scheduler and Controller Manager instances with leader election
			- Etcd cluster run on nodes seperate from the Kubernetes head nodes
		- Kubernetes Federation
	- 商业模式
    	- 云服务用户：避免使用单一云提供商导致的厂商锁定，避免技术和成本风险
    	- 云服务厂商：使用Kubernetes来打破AWS的先入垄断地位，抢夺市场份额
    - Network
    	- Linux Network Virtualization
           - [Linux tun/tap](https://zhaohuabing.com/post/2020-02-24-linux-taptun/)
        - [Network Namespace](https://zhaohuabing.com/post/2020-03-12-linux-network-virtualization/#network-namespace)
        - [Veth Pair](https://zhaohuabing.com/post/2020-03-12-linux-network-virtualization/#veth)
        - [Linux bridge](https://zhaohuabing.com/post/2020-03-12-linux-network-virtualization/#bridge)
      - Vlan
      - Vxlan
          - [Vxlan原理](https://cizixs.com/2017/09/25/vxlan-protocol-introduction/)
          - [Linux 上实现 vxlan 网络](https://cizixs.com/2017/09/28/linux-vxlan/)
      - Routing Protocol
        - Distance Vector Protocol
        	- BGP
        - Link-State Protocol
        	- OSPF
      - K8s Network
        - Service
              - [Cluster IP](https://zhaohuabing.com/post/2019-03-29-how-to-choose-ingress-for-service-mesh/#cluster-ip)
              - [Headless](https://kubernetes.io/zh/docs/concepts/services-networking/service/#headless-services)
              - [NodePort](https://zhaohuabing.com/post/2019-03-29-how-to-choose-ingress-for-service-mesh/#nodeport)
              - [LoadBalancer](https://zhaohuabing.com/post/2019-03-29-how-to-choose-ingress-for-service-mesh/#loadbalancer)
          - Ingress
              - [K8s Ingress](https://zhaohuabing.com/post/2019-03-29-how-to-choose-ingress-for-service-mesh/#k8s-ingress)
              - [Istio Ingress Gateway](https://zhaohuabing.com/post/2019-03-29-how-to-choose-ingress-for-service-mesh/#istio-gateway)
        - [API Gateway+Service Mesh](https://zhaohuabing.com/post/2019-03-29-how-to-choose-ingress-for-service-mesh/#api-gateway--sidecar-proxy)
        - Kubernetes CNI插件
    		- [Calico](https://www.lijiaocn.com/%E9%A1%B9%E7%9B%AE/2017/04/11/calico-usage.html)
	- Security
    	- [Certificate and PKI](https://zhaohuabing.com/post/2020-03-19-pki/)
		- [Kubernetes 中使用到的证书](https://zhaohuabing.com/post/2020-05-19-k8s-certificate/)

