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
            - Veth Pair
            - Network Namespace
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
{{% /mind %}}

