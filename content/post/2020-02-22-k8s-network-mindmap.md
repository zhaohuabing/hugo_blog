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

{{% mind %}}
- Kubernetes
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
    	  {{% /mind %}}

