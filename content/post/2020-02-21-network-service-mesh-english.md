---
layout:     post

title:      "Network Service Mesh: A Big Step Toward Cloud-Native NFV"
subtitle:   ""
excerpt: ""
author:     "Huabing Zhao"
date:       2020-02-21
description: "When hearing about Network Service Mesh for the first time, you probably are as curious as I was:  Does it have anything to do with Service Mesh/Istio? In my opinion, Network Service Mesh could be a turn point for NFV. I'll dive into more details in this post."
image: "/img/2020-02-21-network-service-mesh-english/background.png"

tags:
    - Network Service Mesh
    - Service Mesh
    - Istio
    - SDN
    - NFV

categories: [ Tech ]
---

When hearing about the term “Network Service Mesh” for the first time, you probably are as curious as I was: What exactly is it behind this fancy name? Does it have anything to do with Service Mesh/Istio? It turns out that Network Service Mesh is a sandbox project in the CNCF (Cloud Native Foundation), and it’s also a new hotspot in the cloud-native area. In this post, I’ll dive into the architecture and technical details of Network Service Mesh, and also explore the relationship between it and some other similar technologies you might get confused with, including Service Mesh, SDN, and NFV.

# A Short Brief of Kubernetes Network
Kubernetes has become the de-facto standard for cloud-native application orchestration (that is, deployment, scaling, and management of containerized applications), and almost all public and private clouds are providing managed Kubernetes services. Most of the applications deployed in Kubernetes clusters are based on microservices architecture, therefore, there is a large amount of east-west traffic among these services. Kubernetes uses a flat layer 3 network model to address the network needs of these east-west traffics. The model can have different implementations, but all of them must meet the following basic requirements:
* Each pod is assigned a unique IP address.
* Each pod can communicate directly with any other pod in the same cluster without NAT(Network Address Translation).
If we ignore the trivial details of bridging and routing configuration, the Kubernetes network can be depicted as below:

![](/img/2020-02-21-network-service-mesh-english/kubernetes-network-model.png)

As the figure shows, all pods in a Kubernetes cluster can access each other through a flat layer 3 network. The meaning of "flat" here is that a pod can access any other pod in the same cluster just through layer 3 routing without any NAT in the middle, in other words, the source pod and the destination pod see the same IP addresses in the packages exchanged between them.

Of course, the layer 3 network is "flat" only from the perspective of a pod. For actual deployment, the implementation of this L3 network can be an overlay network with complex encapsulating.

# Limitation of Kubernetes Network in NFV
The purpose of the Kubernetes network is to handle east-west traffic among pods in a cluster, so it has a very simple, elegant design. For normal IT or enterprise applications, it's more than enough. But this model doesn't fit the needs of telcos, ISPs, and some advanced enterprise network, it has the following limitations:

* Kubernetes network cannot provide some advanced L2 / L3 network features.
* The Kubernetes network cannot meet some dynamic network requirements of pods.
* Kubernetes networks lack support for cross-cluster / multi-cloud/hybrid-cloud connectivity.

We probably should not take these limitations as issues. Kubernetes is mainly designed as an orchestration tool for enterprise/IT applications, and its current network model has already supported the inter-communication among the pods very well, which is its original intention.

The Telcom industry has been adopting the cloud-native mindset and technologies such as microservices and containerization for a while. However, when trying to leverage Kubernetes' powerful container orchestration capabilities in NFV (Network Function Virtualization) area, the Telcom industry found that Kubernetes' network mode can't meet NFV's needs. NFV requires some advanced L2 / L3 networking, which is missing in the static Kubernetes network mode. For NFV, Kubernetes' limited network support has become its Achilles' Heel.

# What is Network Service Mesh?
Network Service Mesh (NSM) is a CNCF project that provides advanced L2 / L3 networking capabilities for applications deployed in Kubernetes. NSM does not touch the Kubernetes CNI, instead, it's a totally stand-alone mechanism that consists of a number of components that can be deployed in or out of a Kubernetes cluster. It's a cloud-native network solution works across multi-cloud/hybrid-cloud.

Before diving into the details of NSM, we need to understand what is a Network Service first.

It'll be easier to understand Network Service when compared with the Kubernetes service. We can think of a Kubernetes service as an abstract construct providing some kind of application layer(L7) service for clients, such as HTTP or GRPC services. NSM defines Network Service in a similar way, but instead of L7, a Network service provides L2 / L3 service. The differences between Service and Network Service are as follows:：

* Service: It's application workload and provides services at the application layer (L7), such as web services.
* Network Service: It is a network function and provides services at the L2 / L3 layer, which means Network Service processes and forwards packets, and generally does not terminate these packets. The example of Network Services includes Bridge, Router, Firewall, DPI, VPN Gateway, etc.

The following figure shows the relationship between Service and Network Service.
![](/img/2020-02-21-network-service-mesh-english/network-service.jpg)

There can be multiple endpoints behind the scene to actually provide service in Kubernetes. It's also true for NSM Network Service, multiple pods/endpoints are deployed to share the client loads, and this deployment can be horizontally scaled to meet different workloads.

![](/img/2020-02-21-network-service-mesh-english/network-service-endpoint.jpg)

# Network Service Mesh architecture
Network Service Mesh consists of a couple of components, as shown in this figure:

{{<figure src="/img/2020-02-21-network-service-mesh-english/nsm-architecture.jpg" caption="">}}

* Network Service Endpoint (NSE): the implementation of Network Services, which can be a container, pod, virtual machine or physical forwarder. A network service endpoint accepts connection requests from clients which want to receive the Network Service it is offering.

* Network Service Client (NSC): a requester or consumer of the Network Service.

* Network service registry (MSR): the registry of NSM components including NS, NSE, and NSMgr.

* Network Service Manager (NSMgr): the control plane of NSM. It is deployed as a daemon set on each node. NSMgr communicates with each other to form a distributed control plane. NSMgr is mainly responsible for two things:
	* It accepts the Network Service requests from the NSC and matches the request with appropriate NSE, then creates the virtual wire between the NSC and NSE(the actual job is done by the data plane component ).
	* Register the NSE on its node to the NSR.

* Network Service Mesh Forwarder: the data plane component providing end-to-end connections, wires, mechanisms and forwarding elements to a network service. This may be achieved by provisioning mechanisms and configuring forwarding elements directly, or by making requests to an intermediate control plane acting as a proxy capable of providing the four components needed to realize the network service.
For example: FD.io (VPP), OvS, Kernel Networking, SRIOV etc.

There are a few other components in NSM as well, but what we mentioned here are all we need to know to understand how NSM works.

NSM deploys an NSMgr on each Node in the cluster. These NSMgrs talk to each other to select appropriate NSE to meet the Network Service requests from clients, and create a virtual wire between the client and the NSE. From the perspective, these NSMgrs form a mesh to provide L2/L3 network services for the applications, similar to a Service Mesh.

![](/img/2020-02-21-network-service-mesh-english/network-service-mesh.jpg)

# VPN Gateway Example
Let's see how exactly NSM works by using a simple VPN gateway example. Imagining that you need to connect a pod to the corporation intranet to access a service in the private network, as below diagram shows:

![](/img/2020-02-21-network-service-mesh-english/vpn-usecase.png)

So you will need some kind of VPN to accomplish that. In the traditional way to do it, you need to have a VPN gateway installed somewhere you pod can reach to, probably in the same cluster, you also need to manually configure some network details, such as the VPN gateway address, the subnet prefix and IP address, the routes to the corporate intranet, etc, which should not be exposed to the user of VPN Gateway service at all. In this scenario, the client just needs to connect the corporate intranet and do whatever it needs to do, so it shouldn't care about the underlying implementation details of it, such as how the VPN is configured and established.

In contrast, NSM uses a simple declarative way to provide the VPN service to the clients. This figure shows the YAML definitions of the VPN network service, network service endpoint, and network service client.

{{<figure src="/img/2020-02-21-network-service-mesh-english/vpn-usecase-yaml.png" caption="">}}

* Defines vpn-gateway Network Service with NetworkService CRD. The yaml specification shows that vpn-gateway NS accepts IP payload, and it uses a selector to match pods with label "app: vpng" as the backend pods that provides this Network Service.
* The client uses an annotation "Ns.networkservicemesh.io:vpn-gateway" to request for the Network Service.

NSM has an admission webhook deployed in Kubernetes, which injects an init container into the client pod. This init container requests the desired Network Service specified in the annotation by negotiating with the NSMgr in the same node. This process is transparent to the client, the application container is started after the Network Service has been set up by NSM.

{{<figure src="/img/2020-02-21-network-service-mesh-english/vpn-usecase-setup-connection.png" caption="">}}

1. Vpng-pod has been deployed to provide VPN gateway network service.
1. NSMgr registers vpng-pod as an NSE to the API Server (Service Registry).
1. The NSM init container in the client pod sends a request for vpn-gateway network service to the NSMgr on the same node.
1. NSMgr queries API Server (Service Registry) for available network service endpoints.
1. The chosen NSE may reside on the same or a different node. If it's on a remote node, the NSMgr calls its peer on that node to forward the request.
1. The NSMgr on the NSE node requests a connection on behalf of the NSC.
1. The NSE accepts the request if it still has enough resources to handle it.
1. The NSMgr on the NSE node creates a network interface and inject it to the NSE's Pod.
1. If the NSE and NSC are on different nodes, the NSMgr on the NSE node notifies the NSMgr on the NSC node that the service request has been The NSMgr on the NSE node creates a network interface and inject it to the NSE's Pod..
1. The NSMgr on the NSC node creates a network interface and inject it to the NSC's pod, it also sets the routes to the corporate network.

Note: The two interfaces on the NSC and NSE pods are connected through a virtual wire established by NSM data plane, which could be a block of shared memory or a tunnel, depends on the locations of NSC and NSE.

# Network Service Mesh and CNI
As can be seen from the introduction of NSM in the previous section, NSM is not an implementation or extension of Container Networking Interface(CNI), it's a totally different mechanism.

CNI works in the life cycle of Kubernetes runtime. It only concerns network allocation during a pod's initialization and deletion phases. CNI provides basic Layer 3 network connections between pods in a Cluster. That's it, you can't ask CNI for more advanced networking capabilities.

![](/img/2020-02-21-network-service-mesh-english/cni.png)

NSM works out of Kubernetes runtime' life cycle and it's much more flexible. Various Network Services can be implemented by 3-rd parties and introduced into the Kubernetes world. The implementation details are wrapped into NSE and the complicated network configuration such as IP address, subnet, routes are done by NSM. A client can request and use a Network Service just by a single line of annotation in its YAML deployment file, without noticing all these networking details.

In a word, NSM is a powerful complement to the Kubernetes CNI network model. NSM provides dynamic, advanced network services for pods while CNI provides basic L3 connectivity in a cluster.

# Network Service Mesh and Service Mesh
NSM borrows the concept of Service Mesh, but they work on different layers of the OSI model.
Service Mesh works at Layer 4 and Layer 7 (primarily Layer 7), handling service-to-service communication(service discovery, LB, retries, circuit breaker, advanced routing with application layer headers) and also providing security and insight for microservices.

Network Service Mesh works at layer 2 and layer 3, providing advanced L2/L3 network services such as virtual L2 networks, virtual L3 networks, VPNs, firewalls, and DPI, etc.

If needed, Service Mesh and Network Service Mesh can actually work together. For example, you can create an overlay L3 network across multiple clouds with NSM, and then build an Istio Service Mesh on top of that L3 network.

![](/img/2020-02-21-network-service-mesh-english/istio-on-top-of-nsm.png)

# Network Service Mesh and SDN

SDN (Soft Defined Network) disaggregates network control and forwarding functions from individual switches and routers, and places them instead in a centralized SDN controller, as this figure shows:

![](/img/2020-02-21-network-service-mesh-english/sdn.png)

NSM and SDN do have overlap on OSI layers. SDN works on L1 / L2 / L3, and NSM works on L2 / L3, but in different areas. NSM intends to provide advanced L2 / L3 network services in a cloud-native way for Kubernetes, while SDN is mainly used to facilitate the configuration and management of network gears.

NSM can wrap the capabilities of SDN into Network Services to be used by pods in Kubernetes. The below figure shows an example of using SDN together with NSM to provide QoE (Quality of Experience) services in a Kubernetes cluster.

{{<figure src="/img/2020-02-21-network-service-mesh-english/qoe.png" caption="">}}

In this example, NSM provides QoE network services and the virtual wire between the client and QoE network service endpoint in Kubernetes; the SDN controller configures the network devices and implements the actual QoE mechanism in the transport network.

# Network Service Mesh and NFV

Network Functions Virtualization (NFV) is the decoupling of network functions from proprietary hardware appliances and running them as software. These virtualized network functions(VNFs) are normally packaged as virtual machines (VMs).

However, containers could be much less resource consuming and much more efficient than VMs. It can take minutes to spin up a VM, while only a few seconds for a container.

The major problem of this solution is that the container orchestrator, Kubernetes, lacks the networking capabilities which is a must for NFV. The emerging of NSM fixed the missing part of this puzzle, provides a cloud-native NFV solution. VNFs could be implemented as NSM Network Service, and these Network Services can be connected to form service function chains (SFC). With Kubernetes's powerful orchestration, VNFs can also be easily horizontally scaled to meet different workloads.

This is an example of SFC implemented with NSM:

{{<figure src="/img/2020-02-21-network-service-mesh-english/sfc.png" caption="">}}

At present, NFV is driven by telecommunications standards (such as the ETSI NFV family). Telecommunication standards are great to ensure interoperability among different vendors or operators, but it's terribly inefficient because of the long process to come out a standard. Open source projects, like NSM, may bring revolutionary changes to NFV in the near future.

# Key Takeaways
Network Service Mesh is a CNCF sandbox project that provides complicated L2/L3 networking capabilities for Kubernetes. It maps the concept of service mesh but works in L2/L3 instead of L4/L7. Network Service Mesh complements Kubernetes' original network model, providing a cloud-native way to deploy and use advanced L2/L3 network services. Network Service Mesh can also work with Service Mesh and SDN to provide comprehensive network solutions for applications deployed in the Kubernetes cluster. As a nice way to implement cloud-native Network Functions(CNFs) and SFCs, Network Service Mesh is a big step toward the next generation of NFV, and will have significant impacts on cloud, 5G, and edge computing.

# References
* https://drive.google.com/drive/folders/1f5fek-PLvoycMTCp6c-Dn_d9_sBNTfag
* https://www.youtube.com/watch?v=YeAKtUFaqQ0
* https://www.youtube.com/watch?v=AWHkn_dqAUA&t=331s
* https://static.sched.com/hosted_files/kccnceu19/26/NSM%20Deep%20Dive%20KubeCon%20EU%202019%20%28developer%20centric%29.pdf
* https://www.youtube.com/watch?v=mrkW83_kLLM&t=2990s
* https://docs.google.com/presentation/d/1aG56Oqv7I1JpNsY4VPNpyoKppT-BRyOdYE43fr9ylNs/edit#slide=id.g64538f607d_2_94
* https://docs.google.com/presentation/d/1-nlBx0Qo4oCmlwYc72dirVcw19y5MAwvKu0wc4lk1VA/edit#slide=id.g790e663adc_0_145
