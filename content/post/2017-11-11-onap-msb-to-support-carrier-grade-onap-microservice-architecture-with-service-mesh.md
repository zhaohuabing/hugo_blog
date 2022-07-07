---
layout:     post

title:      "LFN ONAP Beijing Release Developer Forum:
MSB to Support Carrier Grade ONAP Microservice Architecture with Service Mesh"
subtitle:   ""
excerpt: ""
author:     "赵化冰"
date:       2017-11-11
description: "In this session, I'll talk about the MSB Plan for R2 and Beyond. I'll also discuss the OMSA(ONAP Microservice Architecture): the vision of ONAP Microservice Architecture to support Carrier-Grade requirements of ONAP Microservices, which includes Service Orchestration, Service Discovery, Inter-service Communication, Service Governance and Service Monitoring and External API Gateway."
image: "https://images.pexels.com/photos/6560976/pexels-photo-6560976.jpeg?auto=compress&cs=tinysrgb&dpr=2&h=750&w=1260"
published: true
showtoc: false
tags:
    - ONAP
    - Microservice
    - API Gateway
categories:
    - Presentations
metadata:
    - text: "Santa Clara, CA, USA 2017/11"
    - text: "活动链接"
      link: "hhttps://onapbeijing2017.sched.com/event/D5q2"
    - text: "讲稿下载"
      link: "/img/2017-11-11-onap-msb-to-support-carrier-grade-onap-microservice-architecture-with-service-mesh/onap-msb-to-support-carrier-grade-onap-microservice-architecture-with-service-mesh.pdf"
---
## Introduction

In this session, I'll talk about the MSB Plan for R2 and Beyond. I'll also discuss the OMSA(ONAP Microservice Architecture): the vision of ONAP Microservice Architecture to support Carrier-Grade requirements of ONAP Microservices, which includes Service Orchestration, Service Discovery, Inter-service Communication, Service Governance and Service Monitoring and External API Gateway.

ONAP Architecture Principle:  ONAP modules should be designed as microservices: service-based with clear, concise function addressed by each service with loose coupling.

MSB Plan for R2 and Beyond:
* Stability and Reliability: Reliable communication with retries and circuit breaker
* Security: Secured communication with TLS
* Performance: Latency aware load balancing with warm cache
* Observability: Metrics measurement and distributed tracing without instrumentingapplication 
* Manageability: Routing rule and rate limiting enforcement 
* Testability: Fault injection to test resilienceof ONAP

![](/img/2017-11-11-onap-msb-to-support-carrier-grade-onap-microservice-architecture-with-service-mesh/msb.png)


## Slides

[download pdf](/img/2017-11-11-onap-msb-to-support-carrier-grade-onap-microservice-architecture-with-service-mesh/onap-msb-to-support-carrier-grade-onap-microservice-architecture-with-service-mesh.pdf)