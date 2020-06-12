---
layout:     post

title:      "How to Integrate Your Service Registry with Istio?"
subtitle:   ""
excerpt: ""
author:     "Huabing Zhao"
date:       2020-06-12
description: "How can we quickly integrate these existing microservices projects with Istio at minimal modifications? In this post, I will first explain the service registry mechanism of Istio, and then propose several possible options to integrate third-party service discovery with Istio."
image: "https://cdn.pixabay.com/photo/2017/09/17/16/35/boats-2758962_1280.jpg"
published: true
tags:
    - Istio
categories: [ Tech ]
---

Microservice is a powerful software architecture to escalate innovations, and many businesses have been adopting microservice for a long time. However, the transition from monolith to microservice comes with costs. Fundamentally, microservices are distributed systems, often in large scales, which bring the burden of networking such as service discovery, retry, circuit breaker, as well as the observability such as metrics, logging, and distributed tracing.

Istio helps microservices to offloads these common concerns to a dedicated infrastructure layer, so the microservices themselves can shift the burden of microservices to Istio, and focus on their own business logic. With all the promising benefits, more and more microservices projects begin to consider migrating their own microservices infrastructure to Istio.

Istio depends on Kubernetes for service discovery, which means you need to deploy your microservices in Kubernetes clusters and use Kubernetes service for discovery before you can offload service communication to Istio. However, many existing microservices projects are still using Consul, Eureka, or other vendor-specific service discovery rather than the Kubernetes service discovery.

How can we quickly integrate these existing microservices projects with Istio at minimal modifications? In this post, I will first explain the service registry mechanism of Istio, and then propose several possible options to integrate third-party service discovery with Istio.

# Istio Service Model

First, let’s take a look at the service model inside Istio. In the Istio control plane, Pilot is responsible for managing the service within the service mesh. However, Pilot doesn’t handle service discovery by itself. Pilot populates its internal service registry with services from two kinds of data sources.


![](/img/2020-06-02-third-party-registry/pilot-services-source.svg)
Figure 1. Istio service model and data sources

As shown in figure 1, there are two data sources for the Pilot service model:

从上图中可以得知， Pilot 中管理的服务数据有两处数据来源：

* --Service Registry--: A third party service registry. Theoretically, any service registry could be plugged into Pilot via some adapter codes, but only Kubernetes API Server and Consul Catalog are natively supported at the time of this writing.
* --Config Storage--: ServiceEntry and WorkloadEntry are two kinds of Istio configuration resources, which can also be used to add external services into the mesh.

# Consul Integration

In the beginning, Istio mainly focused on Kubernetes environments. Although Consul and Eureka registries were also available in Istio 1.0, these codes were basically prototypes, with some bugs and performance issues.

As our team uses Consul for service discovery in our project, we have been trying to solve these bugs and improve the stability and performance of Consul integration since Itsio 1.0. All the fixes have been pushed to Istio and merged into late releases.

* [Use watching instead of polling to get update from Consul catalog #17881](https://github.com/istio/istio/pull/17881)
* [Fix: Consul high CPU usage (#15509) #15510](https://github.com/istio/istio/pull/15510)
* [Avoid unnecessary service change events(#11971) #12148](https://github.com/istio/istio/pull/12148)
* [Use ServiceMeta to convey the protocol and other service properties #9713](https://github.com/istio/istio/pull/9713)

To connect Consul to Pilot, you just need to specify the registry type and address of the Consul in pilot-discovery command:
```bash
--registries Consul```   ```--consulserverURL http://$consul-ip:$port
```

# Other Service Registries

Although some initial Eureka adapter codes appeared in 1.0, they have been completely removed in later releases. Istio now only natively supports Kubernetes and Consul service registry. For those who are using Eureka or other service registries, there are three possible ways to import services in these registries to Istio.
![](/img/2020-06-02-third-party-registry/service-registry-integration.svg)
Figure 2. Three ways to integrate third-party service registries with Istio

Figure 2 shows the three ways, colored in red, blue, and green, respectively, to integrate service registries with Istio.

## Service Registry Adapter

Like the red arrows show, we can write a custom service registry adapter. The custom adapter gets services and service instances from the third-party service registry, converts them to the standard Pilot service resources, and feeds them to the service controller. The custom adapter needs to implement Pilot serviceregistry.Instance go interface. The implementation codes would be similar to the Consul Service Registry shipped with Pilot.
In order to write a custom service registry adapter, you need to know Pilot source code very well, because the adapter needs to interact with the internal Pilot service model via various non-public APIs. Besides, the custom adapter codes need to be compiled along with Istio source codes to get your own special Pilotd binary. So the major problem of this approach is the coupling of your codes and Istio codes, which may cause some pains when upgrading Istio.

### MCP Server
Blue arrows show the second way: writing your own MCP server to populate Pilot service model with the services from your service registry. The MCP Server fetches services and service instances from the service registry, converts them into ServiceEntry and WorkloadEntry Istio resources, and pushes them to the Pilot MCP config Controller via the MCP protocol.

In this way, the MCP server is a standalone process, so source code level coupling is avoided. You need to set the address of the MCP Server in  [configSources](https://istio.io/docs/reference/config/istio.mesh.v1alpha1/#ConfigSource) parameter of the global mesh options. One thing I’d like to mention is that Istio 1.6 doesn’t support using multiple types of Config controllers together for some unknown reason, implying that you also have to use Galley, the Istio build-in MCP Server, to obtain other configurations instead of directly connecting to Kubernetes API Server.

```yaml
configSources:
  - address:istio-galley.istio-system.svc:9901
  - address:${your-coustom-mcp-server}:9901
```

Since 1.5 release, [most of Galley’s functionalities have been moved into Istiod, and Galley is disabled by default](https://istio.io/news/releases/1.6.x/announcing-1.6/change-notes/). It’s highly likely that Galley will be gradually abandoned in the future, so enabling Galley in production seems not a good idea — you will have to move it out of your deployment, sooner or later.

In addition to this, according to this [MCP over XDS](https://docs.google.com/document/d/1lHjUzDY-4hxElWN7g6pz-_Ws7yIPt62tmX3iGs_uLyI/edit#heading=h.xw1gqgyqs5b) proposal, Istio community is discussing replacing the current MCP wire protocol with XDSv3/UDPA. The communication mechanism between the MCP server and Pilot is likely to change in later releases.

## A Standalone Service to Watch Service Registry and Create ServiceEntry and WorkloadEntry

This approach is shown by the green arrows. All we need to do is writing a standalone service that watches the service registry and pushes the services into Kubernetes API Server in the form of ServiceEntry and WorkloadEntry resources. Then the Kube Config Controller will pull these resources from Kubernetes API Server and push them to Pilot service model.

This approach only depends on two APIs, the service registry watch API and the Kubernetes API server API, both of them are relatively stable.

# Key Takeaway
In this post, we discussed how to integrate third-party service registries with Istio. If you are using Consul, you just need to set the registry type to Consul and specify Consul address in the Pilot-discovery command parameters. For other service registries, there’re three options available: service registry adapter, MCP Server, or a standalone service to push ServiceEntry and WorkloadEntry to Kubernetes API server.

You’re free to choose any one of these approaches for your own microservice project. IMHO, since the first and second approaches have some obvious issues, it makes more sense to start with the third one and consider moving to the MCP server approach after Galley and MCP architecture are stable.