---
layout:     post

title:      "How service mesh can help during the ONAP Microservice journey"
subtitle:   ""
excerpt: ""
author:     "赵化冰"
date:       2018-06-22
description: ""
image: "https://media.licdn.com/media/gcrc/dms/image/C5612AQGxADrUDCsbLg/article-cover_image-shrink_720_1280/0?e=2128896000&v=beta&t=sI_cpNncTX_zgG6yiGSEs5zIaIllthOzf_8_Blsul6M"
published: true 
tags:
    - Istio 
    - ONAP 
    - Service Mesh 

categories: [ Tech ]
---

[ONAP Beijing is available now](https://www.onap.org/announcement/2018/06/12/onap-announces-availability-of-beijing-release-enabling-a-deployment-ready-platform-for-network-automation-and-orchestration)!

ONAP, as part of LF Networking, now accounts for more than 65% of global subscriber participation through carriers creating a harmonized, de-facto open source platform.
<!-- more -->

While it's so exciting to see that more operators are deploying ONAP in their commercial network, ONAP community realizes that there are still somewhere we can improve to smooth the deployment process. For example, instead of deploying ONAP as a whole, users may just want to pick some modules, integrate these modules with their existing system to get a customized ONAP solution. Actually, this is a very usual usage scenario in open source world. So it should be easy to tailor ONAP to suit the different scenarios and purposes for various users.

To reflect these requirements, According to ONAP Casablanca Developer Event this week in Beijing, China, ONAP is planning enhancements for Casablanca release towards a more mature architecture, which will be modular, mode-drive, and microservice-based. A loose-coupled, microservice based ONAP system can make it much easier for ONAP to address the current customized deployability requirement, also to accelerate the platform maturity.

Microservice based architecture is not a new topic brought for Casablanca. A bunch of ONAP projects have already done great jobs to decompose their applications to microservices during Amsterdam and Beijing. Microservices Bus(MSB) has helped ONAP projects evolve towards the microservice direction in the last two release by providing service registration/discovery, external API gateway, internal API gateway, Java SDK and swagger SDK.

In Casablanca, MSB project will introduce Istio service mesh to provide a reliable, secure and flexible service communication infrastructure layer for ONAP microservices. Service mesh approach uses a sidecar proxy to decouple the service communication and other service infrastructure logic(Telemetry collection, Policy enforcement, etc,) from the business logic of microservices. So the developer can focus the business logic and drop the burden of microservice infrastructure.

There are a couple of service mesh projects on the table, so what's the reasoning behind the choice of Istio?

The main advantage of Istio is introducing a centralized Control Plane to manage the distributed sidecars across the mesh, Control plane is a set of centralized management utilities including:

-   Pilot: routing tables, service discovery, and load balancing pools
-   Mixer: Policy enforcement and telemetry collection
-   Citadel: TLS mutual service authentication and fine-grained RBAC

The other beauty of Istio is its well-designed, highly extendable architecture.

-   Multiple adapters can be plugged into Pilot to populate the services: Kubernetes, Consul, Mesos...
-   Different backends can be connected to Mixer without modification at the application side: Prometheus, Heapster,AWS CloudWatch...
-   Standard API between Pilot and data plane for service discovery, LB pool and routing tables which decouples the sidecar implementation and Pilot: Envoy, Linkerd, Nginmesh are all support Istio now and can work along with Istio as sidecar

We know that even Istio is powerful and promises many benefits, now it's not mature enough for production, so we'd like to take baby steps, we are going to start with a seed project, prove it works, and then roll out to the whole ONAP, it will also be optional. What we're doing is to try to make sure ONAP can work with Istio and leverage the awesome advantages it brings in, but it's the users who make the decision to deploy ONAP with Istio or not.

To minimize the impact to each microservice, we will make the service mesh approach compatible with the existing service-to-service communication approaches. Thanks to the well-designed, highly-extendable architecture of Istio, MSB registry can be plugged into Pilot to populate the ONAP services, and we can use Istio rules to make the requests through MSB API gateway compatible with Envoy sidecar. By this approach, the service mesh is transparent to ONAP microservices, there's no difference in terms of service communication from the service point of view.

Learn more about the plan of ONAP Istio integration by reading the [slides deck](https://wiki.onap.org/display/DW/Casablanca+Release+Developers+Forum+Session+Proposals?preview=/25434845/35521830/MSB%20Plan%20to%20Support%20Microservices-Based%20Architecture%20with%20Istio%20Service%20Mesh.pdf) and welcome to [join us](https://wiki.onap.org/display/DW/Microservices+Bus+Project) in this exciting journey.
