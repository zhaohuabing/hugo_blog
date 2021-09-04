---
layout:     post

title:      "What Can Service Mesh Learn from SDN?"
subtitle:   ""
excerpt: ""
author:     "赵化冰"
date:       2019-11-23
description: "what is the relationship between Service Mesh and SDN — Is Service Mesh the next generation of SDN? What can Service Mesh learn from the experience of SDN? I’d like to share some of my own opinions in this article."
image: "https://upload.wikimedia.org/wikipedia/commons/f/f0/%CE%91%CE%B8%CE%B1%CE%BC%CE%B1%CE%BD%CE%B9%CE%BA%CE%AC_%CE%8C%CF%81%CE%B7_%CF%85%CF%80%CF%8C_%CF%84%CE%BF_%CF%86%CF%89%CF%82_%CF%84%CE%BF%CF%85_%CE%A6%CE%B5%CE%B3%CE%B3%CE%B1%CF%81%CE%B9%CE%BF%CF%8D_-_%CE%A3%CF%84%CE%AC%CE%B8%CE%B7%CF%82_%CE%9A%CE%BF%CF%85%CF%84%CF%83%CE%B9%CE%B1%CF%8D%CF%84%CE%B7%CF%82.jpg"
published: true 
tags:
    - Service Mesh 
    - Istio 
    - SDN

categories: [ Tech ]
---

Service Mesh is yet another emerging fancy tech word in the field of microservices recently. If you have a telecommunication or networking background, you may have already noticed that Service Mesh and SDN (Software Defined Network) look similar. Both of them use a software layer to manage and control the network infrastructure, and they also share the same architecture, which consists of a control plane and a data plane.

So what is the relationship between Service Mesh and SDN — Is Service Mesh the next generation of SDN? What can Service Mesh learn from the experience of SDN? I’d like to share some of my own opinions in this article.

# Traditional network

First, let’s look into a little bit of the history of networks and how SDN is invented.
A traditional network is a distributed, decentralized architecture. Each switch or router has its embedded control plane and this embedded control plane decides how to route the traffic on its own. They do coordinate with each other via some routing protocols, but there is no central management point responsible for the end to end route decisions.

The advantage of this architecture is that it is highly fault-tolerant. If a part of the network fails, the entire network can also work with little or even no interruption of the application traffic, because oftentimes the devices can avoid the failed path and find another alternative route by themselves.

{{< figure src="/img/2019-11-23-what-can-service-mesh-learn-from-sdn-english/network-devices.png" caption="Decentralized Traditional Network">}}

This decentralized architecture works well with the HTTP based web applications, which is mainly some web page with pictures and texts and users don’t care much about a small delay when loading the page. But with the explosive growth of the Internet, new kinds of web applications emerged, and they have different demands for the network. For example, video calls can tolerate minor signal loss but require very little latency, while online games require a very stable and fast network but may not need much bandwidth. The traditional network is just not flexible enough to match these demands:

* Lack of network QoS assurance: Because each device makes its own routing decision, there is no way to achieve end-to-end QoS service assurance in a traditional network.
* Inefficient service deployment: Devices are manually configured through command lines or network management systems, and the configurations are incompatible with each other. As a result, the service deployment is very inefficient.
* Slow business innovation: Coupling of control plane and data plane in the hardware layer results in a long development cycle for new services. To introduce a new service, it often takes several years to design, develop and manufacture new network gears.

# How SDN solves the problem of traditional network

SDN is intended to address these issues of traditional networks. The architecture of SDN is shown as below:

{{< figure src="/img/2019-10-26-what-can-service-mesh-learn-from-sdn/sdn.png" caption="SDN Architecture">}}

As you can see from the figure, SDN is a layered architecture:

* Infrastructure Layer: It is the data path that is responsible for handling and forwarding the packets.
* Control Layer: It is a logically central point that directing traffic across the whole network. The control layer generates routing tables and sends it to the infrastructure layer.
* Application Layer: Applications that use services from the control layer to accomplish various business requirements.

Standard interfaces are used between different layers of SDN:

* Southbound API: The standard southbound interface decouples the control layer and the infrastructure layer. This interface uses some network protocols such as OpenFlow and NetConf.
* Northbound API: With the programmable northbound API provided by the control layer, new kinds of services can be realized purely by software applications, which profoundly accelerates the time to market of new services.

# Challenges of Microservices
In a microservice system, remote calls are used for inter-service communication. The communication logic such as service discovery, load balancing, Circuit breaker, etc., is normally a code library and compiled into the service binary.

{{< figure src="/img/2019-11-23-what-can-service-mesh-learn-from-sdn-english/microservice.png" caption="Microservices Communication">}}

Looks quite familiar, right? This microservice system has similar problems to a traditional network:

* Since microservices are polyglot, we need different libs to handle inter-service communication for different languages, and the configuration of these libs usually are incompatible with each other, which makes the operation of these microservices very difficult.
* The library solution also results in the tight coupling between the business logic and service communication infrastructure. If we need to fix a bug or introduce a new feature in the communication layer, all services need to be modified and upgraded, which is a big cost in a production system.

# Is Service Mesh the next generation SDN?

From the above analysis, we can see that SDN and Service Mesh are introduced to solve similar problems. So, you might be wondering: Is Service Mesh the next generation of SDN?

OK, I think it’s yes, and no. Yes because they are all based on the same concept of separated control plane and data plane, no because they work on different OSI network layers. SDN mainly works on the L1 to L4, whereas service Mesh focuses on the L7 layer and above.

{{< figure src="/img/2019-10-26-what-can-service-mesh-learn-from-sdn/sdn-vs-service-mesh.jpg" caption="Comparison between SDN and Service Mesh">}}

As I mentioned before, Service Mesh uses an SDN like architecture to solve the microservice communication problems.
{{< figure src="/img/2019-10-26-what-can-service-mesh-learn-from-sdn/service-mesh.jpg" caption="Service Mesh Architecture">}}

Almost all of the popular Service Mesh projects on the table are implemented like this, including[Istio](https://istio.io),[Linkerd](https://linkerd.io),[Kuma](https://kuma.io),etc.

In this architecture, the data plane takes the role of the white-box switch in SDN. At present, the envoy is the most popular data plane implementation, so Envoy’s xDS v2 interface is used as the de-facto data plane protocol.

Most of the innovation and competition happens on the control plane. As an attempt to algin various control plane implementations, Microsoft initiated the SMI (Service Mesh Interface) control plane interface. SMI has also been supported by some other service mesh players such as Linkerd, Consul connect and Gloo, but interestingly, as one of the most important Service Mesh projects, Istio has not yet expressed its opinion. Due to the fact of lacking a unified control plane interface, there are not many innovations in the application layer now.

# Manage hardware devices with Service Mesh
The SDN control plane can manage various devices, no matter it’s a hardware white box or a software vSwitch. This is an important inspiration for Service Mesh. Can we use Service Mesh control plane to manage hardware devices as well?

There is an experiment of [F5 BIG-IP and Istio integration](https://aspenmesh.io/2019/03/expanding-service-mesh-without-envoy/). Some services in Service Mesh need to access data in a legacy database system, which is in another network. To protect the database, an F5 BIG-IP is placed in front of the database as an edge proxy:

* Services in the mesh can only access the legacy database via the F5 BIG-IP
* Enforce mTLS for the connection between F5 BIG-IP and services
* F5 BIG-IP uses SPIFFE identity to authenticate microservices

This experiment proves that hardware devices can be integrated with service mesh to deliver a valuable business solution. But in this case, we have to manually configure the F5 BIG IP side, including opening the ports for the DB, configuring TLS certificates, setting authentication and access policies, etc. Imagine that if we could just use the Service Mesh control plane to send the needed configuration to the F5 device, the service provisioning process would be profoundly simplified.
{{< figure src="/img/2019-10-26-what-can-service-mesh-learn-from-sdn/hardware-sidecar.jpg" caption="F5 BIG-IP Managed by Service Mesh Control Plane">}}

# Service Mesh applications

Just like SDN, Service Mesh can also expose its capabilities through a programmable API interface to the application layer. At present, Service Mesh is still in its infancy and there are not many innovations in the application layer, but from the history of SDN, we can see that there is a big room for us to fill in the application layer of Service Mesh.

Below is an example of Service Mesh applications: Service subscription and SLA management：

{{< figure src="/img/2019-10-26-what-can-service-mesh-learn-from-sdn/user-ubscription.jpg" caption="Service Mesh application: service subscription and SLA management">}}

1. The user uses the APP to subscribes to services and sets the SLA (Service Level Agreement) of his subscription, including the number of requests per second, the response time, etc.
2. The APP calls the Service Mesh control plane API to create the corresponding routing rule and policy.
3. The control plane converts the routing rule and operation policy into proxy configuration and sends the configuration to proxies via data plane protocol.
4. When receiving the user request, the proxy gets the user identity from the request and processes the request accordingly. For example, if the proxy receives more traffic than the system can handle, the requests from a user of higher SLA are forwarded to the service first, and lower SLA requests may be dropped.

It’s just a very simple example of Service Mesh applications. Leveraging the basic capabilities provided by the service Mesh control plane, including security policy, mesh topology, and request metrics, we can create a large number of value-added services, such as canary deployment, Chaos testing, service monitoring system, etc.

# Conclusion

Both SDN and Service Mesh are invented to solve similar problems, but they aim at different network layers. Service Mesh is not the next generation of SDN, but Service Mesh can learn from the experience of SDN and evolve in the following directions:

* Northbound interface: The northbound interface of Service Mesh is a high-level abstraction and is relatively easy to work out a unified standard. SMI (Service Mesh Interface) has been proposed as a standard for the northbound interface. However, there are some potential problems in SMI, such as how to avoid SMI becoming the smallest common subset of different Service Mesh implementations? How to extend SMI to support other application layer protocols besides HTTP?
* Southbound interface: Envoy’s xDS has become the de-facto standard for southbound interfaces, but the xDS interface has some implementation-specific details in its protocol, such as Listener, Filter, etc. It’s better to replace these with more abstract concepts so the southbound interface can be more easily adopted by other data plane implementations.
* Hardware management: The Service Mesh control plane could provide unified management for both the software and hardware proxies. This approach would significantly reduce operational costs in a complex environment.
* Innovations in the application layer: the mesh capabilities exposed by the northbound interface could drive innovations in the application layer, which may become the next hot spot of Service Mesh.

# References
* Part of this post is inspired by Eric Brewer’s talk on Service Mesh day 2019 ( https://www.youtube.com/watch?v=do-PrVi0ifk)
* Expanding Service Mesh Without Envoy ( https://aspenmesh.io/expanding-service-mesh-without-envoy/)