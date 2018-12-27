---
layout:     post

title:      "The obstacles to put Istio into production and how we solve them"
subtitle:   ""
excerpt: ""
author:     "赵化冰"
date:       2018-12-27
description: "After its 1.0 release, our team has begun the efforts to integrate Istio into our system. This article tells our findings and thoughts during this adventure."
image: "/img/2018-12-27-the-obstacles-to-put-istio-into-production/background.jpg"
published: true 
tags:
    - Service Mesh 
    - Istio 
    - Consul 
    - NFV

categories: [ Tech ]
---

><B>What is service mesh?</B>
><BR><BR>
>Service mesh is becoming yet another fancy name in the cloud-native world this year. What exactly it is? By definition, service mesh is a dedicated infrastructure layer for handling service-to-service communication. It’s responsible for the reliable delivery of requests through the complex topology of services that comprise a modern, cloud-native application. Besides, it also facilitates the governance of services.
><BR><BR>
><B>What is Istio?</B>
><BR><BR>
>Istio is an open-source service mesh project lead by Google, IBM and Lyft. As an open platform, Istio lets you connect, secure, control, and observe services.

I have been following the Istio project from its early stage. Over time, it turned out Istio has a good architecture, an active community, promising features and also strong support from big companies. So, after its 1.0 release, our team has begun the efforts to integrate Istio into our system. This article tells our findings and thoughts during this adventure.

# Hybrid Service Mesh

## Not only microservice in the real world

Even microservice Architecture has been widely adopted in the past few years, we have to face the reality that there are still quite a few systems which have not built in Microservice yet, or, some of them may never be built as microservice. The reason is that Microservice is not a silver bullet to solve all the problems, like other Architecture styles, microservice has its own strength and cost. We should make the architecture choice which makes sense based on the business scenarios.

Kubernetes and Istio assume that one container/progress is a service. While this assumption is reasonable with “pure” microservices architecture, it does have problems supporting “coarse-grained” services such as the services in SOA architecture.

## A hybrid service mesh for all kinds of services

In our company, we have some legacy systems which are not microservices-based. Instead, they’re more like SOA services. So there are probably multiple “services” inside one progress. These systems are doing well right now, so we are happy with them and don’t have the incentive to rewrite them to microservices. However, we’d like to put these services into service mesh as well, so they can benefit from all the advantages the Istio provides such as reliable communications, traffic routing, telemetry collection, distributed tracing, policy checking, etc.
![](/img/2018-12-27-the-obstacles-to-put-istio-into-production/microservices.png)
<center>A software system consisting of both “fine-grained” and “coarse-grained” services</center>

To achieve this goal, we created our own service registry (which is based on Consul). All the services are still deployed in Kubernetes cluster, but we integrate our own service registry, instead of Kubernetes, into Pilot instead of Kubernetes. All the “fine-grained” and “coarse-grained” services are registered to this service registry, then these services are pushed to Pilot via a customized Pilot service registry adapter.

With this approach, both the Microservice applications and SOA applications can be managed in the service mesh and interconnect with each other. An additional benefit is that we can even build a hybrid service mesh across Kubernetes clusters and VM/BearMetals, allowing more legacy systems integrated into service mesh without significant changes to their existing software architecture and deployment model.
![](/img/2018-12-27-the-obstacles-to-put-istio-into-production/hybrid-service-mesh.png)
<center>Hybrid Service Mesh for all kind of service</center>

# Support multiple network interfaces

## Why we need multiple network interfaces

Istio has been highly integrated with Kubernetes, therefore, it’s not surprising that Istio now only allows one network interface for each node in the mesh. This is because in Kubernetes each pod only has one network interface (apart from a loopback).

In some cases, we, however, may have multiple network interfaces for a node in the mesh. For example, for NFV(Network Function Virtualization) use case, it is required to provide multiple network interfaces to the virtualized operating environment of the VNF. The main reasons are as follows:

* Functional separation of control and data network planes
* Link aggregation/bonding for redundancy of the network
* Support for implementation of different network SLAs
* Network segregation and Security

Besides, as an open platform, Istio also supports service registries other than Kubernetes, such as Consul or customized service registry, so the services may have been deployed in virtual machines or bare metals, where a node with multiple network interfaces is very common.

## What’s the problem

The current Pilot implementation to build inbound listeners has a problem. It is using the IP address reported by Envoy proxy to build the inbound listeners(The IP address is conveyed by the id in the node structure of the xDS request, such as sidecar~192.168.206.23~productpage-v1–54b8b9f55-bx2dq.default~default.svc.cluster.local).

In case that there is more than one IP Address in the pod, only the IP address of the first network interface has been sent to Pilot. When services in the pod are registered via the IP address of the second network interface, the Pilot doesn’t know these services are located in the same pod with the proxy and then doesn’t build inbound listeners for them, causing an infinite loop when the envoy receives a request and results in envoy crash because of running out of file descriptors.
![](/img/2018-12-27-the-obstacles-to-put-istio-into-production/multi-network-issue.png)
<center>Envoy crash caused by incorrect listeners</center>

## How to support multiple interfaces

All the IPs of the node should be sent to Pilot with the discovery request. So Pilot can use all the IP addresses to tell which services are located with the proxy and build correct inbound listeners for that proxy.
![](/img/2018-12-27-the-obstacles-to-put-istio-into-production/multi-network-solution.png)
<center>The solution for multiple network interfaces</center>
A pull request has already been submitted to fix it. Multiple network interfaces support will be available in Istio release 1.1.

RP: https://github.com/istio/istio/pull/9688

Issue: https://github.com/istio/istio/issues/9441

# Service Mesh and API Gateway

## Kubernetes Ingress

In the early stage, Istio just uses the Kubernetes Ingress to expose the services to the outside world. The main problem of using Kubernetes Ingress lies in the fact that it can’t be managed by Istio control plane, so Istio features like routing rules, distributed tracing, Telemetry and policy check are not available at the ingress. This may cause something wrong with some promised advanced use cases of Istio such as A/B testing and canary deployment.

## Istio Gateway

Istio team realized the problem and introduced gateway resource in the v1alpha3 routing API. A VirtualService can be bound to a gateway to control the forwarding of traffic arriving at a particular host or gateway port. By this means, now Istio can control the traffic both inside the mesh and at the gateway in a unified manner. All the Istio promised features can also be applied to the gateway traffic.

## API Gateway

As a type of traffic entrance, API Gateway does have some overlapped features with K8S Ingress and Istio Gateway, such as virtual hosting, SSL termination, service discovery and load balancing. However, the key objective of using API Gateway is to expose your services as managed APIs. So, the API Gateway layer mainly serves some specific API management functionalities such as Authentication & Authorization, Transformation & Transportation, API Lifecycle Management, Billing and Rate limiting, etc.
![](/img/2018-12-27-the-obstacles-to-put-istio-into-production/ingress-comparation.png)
<center>Functionalities of Kubernetes ingress, Istio gateway and API gateway</center>

## Service mesh and API Gateway should work together

As we discussed above, neither Istio Gateway nor API gateway could finish the jobs on their own. So it’s better to have them work together to provide a comprehensive, full-functional traffic entrance for the service mesh.

The below figure illustrates how API Gateway and mesh sidecar can coexist. API Gateway offloads the service discovery and traffic management features to the sidecar and focuses on the API management features. It’s a much clearer picture, the two components now are serving two fundamentally different requirements.

![](/img/2018-12-27-the-obstacles-to-put-istio-into-production/api-gateway-and-envoy.png)
<center>How API gateway and service mesh works together</center>

# The missing part: async communication

There are two inter-service communication styles for microservices - sync RPC (Remote Procedure Call) and async messaging. However, Istio only addressed one of them, async communication support is totally missed right now. If you are serious about leveraging Istio in production, this is one thing you have to consider.

For us, one important use case is canary deployment. Both the REST requests and Kafka messages should be split between old and new versions when implementing a canary deployment, but Istio can only deal with REST traffic.

To solve this problem, we build a Kafka message filter mechanism on the consumer side to receive traffic rules from the control plane and help split the messages. It would be helpful if Istio could consider support Kafka message routing in the future release.
![](/img/2018-12-27-the-obstacles-to-put-istio-into-production/async.png)
<center>Async messaging splitting between services</center>

# Conclusion

Istio provides an infrastructure layer to facilitate the communication and management for microservice. Istio doesn't eliminate the complexity brought by microservice architecture, but it can shift the complexity from individual microservice to an abstract layer in a unified manner to make it more manageable.

If you have any thoughts, please leave a message under the article or contact me by [email](mailto:zhaohuabing@gmail.com).
