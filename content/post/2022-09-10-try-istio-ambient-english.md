---
layout:     post

title:      "Try out Istio Ambient mode"
subtitle:   ""
description: ""
author: "Huaing Zhao"
date: 2022-09-10
image: "https://images.unsplash.com/photo-1558403871-bb6e8113a32e?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2662&q=80"
published: true
tags:
    - Istio
    - Envoy
    - Service Mesh
    - Ambient Mesh
categories: [ Tech ]
showtoc: true
---

Ambient is a new data-plane model that Istio has just announced support for. In this post, we will try to install Istio’s ambient model and use the bookinfo demo to experience the L4 and L7 capabilities offered by ambient.

> Note: L4 refers to the four layers of the OSI standard network model, i.e., TCP layer processing. L7 refers to layer seven of the OSI standard network model, which is the application layer processing, generally referred to as HTTP protocol processing.

# Install Istio ambient mode
According to the ambient [README](https://github.com/istio/istio/tree/experimental-ambient#readme)，ambient currently supports Google GKE, AWS EKS and kind k8s deployment environments . After my experimentation, kind on Ubuntu is the most convenient deployment environment to try ambient. You can refer to[Get Started with Istio Ambient Mesh](https://istio.io/latest/blog/2022/get-started-ambient/) to deploy the Istio experiment version with ambient support. If you do not have access to the official download address, you can download and install from the mirror I built in China by following these steps:

1. First install docker and [kind](https://kind.sigs.k8s.io/docs/user/quick-start/) on an Ubuntu virtual machine.

2. Create a kind k8s cluster:
```bash
kind create cluster --config=- <<EOF
kind: Cluster
apiVersion: kind.x-k8s.io/v1alpha4
name: ambient
nodes:
- role: control-plane
- role: worker
- role: worker
EOF
```
3. Then download and unzip the Istio experiment version that supports ambient mode.

```bash
wget https://zhaohuabing.com/download/ambient/istio-0.0.0-ambient.191fe680b52c1754ee72a06b3e0d3f9d116f2e82-linux-amd64.tar.gz

tar -xvf istio-0.0.0-ambient.191fe680b52c1754ee72a06b3e0d3f9d116f2e82-linux-amd64.tar.gz
```

4. Install Istio, you need to specify the profile as ambient, note that you need to specify the hub if you can't access gcr.io, otherwise the relevant container image may fail to pull due to network reasons.

```bash
cd istio-0.0.0-ambient.191fe680b52c1754ee72a06b3e0d3f9d116f2e82
./bin/istioctl install --set profile=ambient --set hub=zhaohuabing
```

The ambient profile installs Istiod, ingress gateway, ztunnel and istio-cni components in the cluster. The ztunnel and istio-cni are deployed on each node as daemonset. istio-cni is used to detect which application pods are in ambient mode and create iptables rules to redirect outbound and inbound traffic from these pods to the node’s ztunnel. istio-cni will continuously monitors changes to the pods on the node and updates the redirection logic accordingly.

```bash
$ kubectl -n istio-system get pod
NAME                                    READY   STATUS    RESTARTS   AGE
istio-cni-node-27f9k                    1/1     Running   0          85m
istio-cni-node-nxcnf                    1/1     Running   0          85m
istio-cni-node-x2kjz                    1/1     Running   0          85m
istio-ingressgateway-5c87575d87-5chhx   1/1     Running   0          85m
istiod-bdddf595b-tn9px                  1/1     Running   0          87m
ztunnel-5nnnl                           1/1     Running   0          87m
ztunnel-dk42c                           1/1     Running   0          87m
ztunnel-ff26n                           1/1     Running   0          87m
```

# Deploy the demo application

Execute the following command to deploy the Demo application:

```bash
kubectl apply -f samples/bookinfo/platform/kube/bookinfo.yaml
kubectl apply -f samples/bookinfo/networking/bookinfo-gateway.yaml
kubectl apply -f https://zhaohuabing.com/download/ambient/sleep.yaml
kubectl apply -f https://zhaohuabing.com/download/ambient/notsleep.yaml
```

The above command deploys the demo application in the default namespace. Currently, the traffic of the demo application does not go through ztunnel, and the traffic between pods goes through the [k8s service](https://www.zhaohuabing.com/post/2019-03-29-how-to-choose-ingress-for-service-mesh/#undefined) mechanism to communicat with each other, and the traffic between pods is not protected by mTLS.

![](/img/2022-09-10-try-istio-ambient/app-not-in-ambient.png)
<p style="text-align: center;">Communication between applications are plain text</p>

# Put demo application in ambient mode

You can add all application workloads in a namespace to the ambient mesh by labeling the namespace with the following tag.

```bash
kubectl label namespace default istio.io/dataplane-mode=ambient
``` 

The istio-cni component watches the namespace added to the ambient mesh and will set the appropriate traffic redirection policy. If we check the istio-cni logs, we can see that istio-cni creates the appropriate routing rules for the application pod.

```bash
kubectl logs istio-cni-node-nxcnf -n istio-system|grep route
2022-09-10T09:40:07.371761Z	info	ambient	Adding route for reviews-v3-75f494fccb-gh9sr/default: [table 100 10.244.2.8/32 via 192.168.126.2 dev istioin src 10.244.2.1]
2022-09-10T09:40:07.375442Z	info	ambient	Adding route for productpage-v1-7c548b785b-kxdwz/default: [table 100 10.244.2.9/32 via 192.168.126.2 dev istioin src 10.244.2.1]
2022-09-10T09:40:07.379072Z	info	ambient	Adding route for details-v1-76778d6644-cvkc7/default: [table 100 10.244.2.4/32 via 192.168.126.2 dev istioin src 10.244.2.1]
2022-09-10T09:40:07.382887Z	info	ambient	Adding route for ratings-v1-85c74b6cb4-rzn44/default: [table 100 10.244.2.5/32 via 192.168.126.2 dev istioin src 10.244.2.1]
2022-09-10T09:40:07.386015Z	info	ambient	Adding route for reviews-v1-6494d87c7b-f4lvz/default: [table 100 10.244.2.6/32 via 192.168.126.2 dev istioin src 10.244.2.1]
2022-09-10T09:40:07.389121Z	info	ambient	Adding route for reviews-v2-79857b95b-nk8hn/default: [table 100 10.244.2.7/32 via 192.168.126.2 dev istioin src 10.244.2.1]
```

Access the productpage from sleep:

```bash
kubectl exec deploy/sleep -- curl -s http://productpage:9080/ 
```

We should be able to see the output of the productpage service. At this point the traffic has been authenticated and encrypted in both directions with mTLS via ztunnel. We should be able to see the access logs from the ztunnel on the sleep and productpage nodes.

Traffic in the outbound direction (sleep -> ztunnel on the sleep node).

```bash
kubectl  -n istio-system logs ztunnel-dk42c -cistio-proxy --tail 1
[2022-09-10T10:12:33.041Z] "- - -" 0 - - - "-" 84 1839 2 - "-" "-" "-" "-" "envoy://outbound_tunnel_lis_spiffe://cluster.local/ns/default/sa/sleep/10.244.2.9:9080" spiffe://cluster.local/ns/default/sa/sleep_to_http_productpage.default.svc.cluster.local_outbound_internal envoy://internal_client_address/ 10.96.250.29:9080 10.244.1.5:45176 - - capture outbound (no waypoint proxy)
```

Traffic logs in the inbound direction (ztunnel -> productpage on productpage).
```bash
kubectl  -n istio-system logs ztunnel-ff26n -cistio-proxy --tail 1
[2022-09-10T10:18:23.497Z] "CONNECT - HTTP/2" 200 - via_upstream - "-" 84 1839 2 - "-" "-" "6300b128-3a4d-472e-b573-e14743b6c981" "10.244.2.9:9080" "10.244.2.9:9080" virtual_inbound 10.244.1.3:48053 10.244.2.9:15008 10.244.1.3:36748 - - inbound hcm
```
We can see that the outbound traffic log has the word (no waypoint proxy) in it because ambient’s only does L4 processing by default, no L7 processing. The traffic only goes through the ztunnel and not the waypoint proxy, as shown in the figure below.

![](/img/2022-09-10-try-istio-ambient/app-in-ambient-secure-overlay.png)
<p style="text-align: center;">Applications communicate with each other through the ztunnel security overlay</p>


# Enable L7 processing for ambient mode

Currently ambient mode requires a gateway to be defined to enable L7 processing for a service. Create the following gateway to enable L7 processing for the productpage service.

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: Gateway
metadata:
 name: productpage
 annotations:
   istio.io/service-account: bookinfo-productpage
spec:
 gatewayClassName: istio-mesh
EOF
```

Note that the gatewayClassName in the gateway resource must be set to ‘istio-mesh’, otherwise Istio won't create the corresponding waypoint proxy for the productpage.

You can see the waypoint proxy created by Istio at this point.

```bash
kubectl get pod|grep waypoint
bookinfo-productpage-waypoint-proxy-7dc7c7ff6-6q6l7   1/1     Running   0          21s
```
Access the productpage from sleep.

```bash
kubectl exec deploy/sleep -- curl -s http://productpage:9080/ 
```

Let’s look at the actual path that the request goes through.

sleep -> ztunnel on sleep node.

```bash
kubectl  -n istio-system logs ztunnel-dk42c -cistio-proxy --tail 1
[2022-09-10T10:51:36.373Z] "- - -" 0 - - - "-" 84 1894 5 - "-" "-" "-" "-" "10.244.2.12:15006" spiffe://cluster.local/ns/default/sa/sleep_to_server_waypoint_proxy_spiffe://cluster.local/ns/default/sa/bookinfo-productpage 10.244.1.5:47829 10.96.250.29:9080 10.244.1.5:44952 - - capture outbound (to server waypoint proxy)
```

You can see the words (to server waypoint proxy) in the above log, indicating that the request went through the waypoint proxy.

ztunnel on sleepnode-> waypoint proxy.

```bash
kubectl logs bookinfo-productpage-waypoint-proxy-7dc7c7ff6-6q6l7 --tail 3
[2022-09-10T10:51:36.375Z] "GET / HTTP/1.1" 200 - via_upstream - "-" 0 1683 2 2 "-" "curl/7.85.0-DEV" "fe3ba798-4ace-4891-b919-c3ea924f8cb9" "productpage:9080" "envoy://inbound_CONNECT_originate/10.244.2.9:9080" inbound-pod|9080||10.244.2.9 envoy://internal_client_address/ envoy://inbound-pod|9080||10.244.2.9/ envoy://internal_client_address/ - default
[2022-09-10T10:51:36.374Z] "GET / HTTP/1.1" 200 - via_upstream - "-" 0 1683 3 3 "-" "curl/7.85.0-DEV" "fe3ba798-4ace-4891-b919-c3ea924f8cb9" "productpage:9080" "envoy://inbound-pod|9080||10.244.2.9/" inbound-vip|9080|http|productpage.default.svc.cluster.local envoy://internal_client_address/ envoy://inbound-vip|9080||productpage.default.svc.cluster.local/ envoy://internal_client_address/ - default
[2022-09-10T10:51:36.374Z] "CONNECT - HTTP/2" 200 - via_upstream - "-" 84 1894 4 - "-" "-" "eb705930-8b73-4c29-870e-ead523143278" "10.96.250.29:9080" "envoy://inbound-vip|9080||productpage.default.svc.cluster.local/" inbound-vip|9080|internal|productpage.default.svc.cluster.local envoy://internal_client_address/ 10.244.2.12:15006 10.244.1.5:47829 - -
```
productpage node 上的 ztunnel -> productpage
```bash
kubectl  -n istio-system logs ztunnel-ff26n -cistio-proxy --tail 1
[2022-09-10T10:51:36.376Z] "CONNECT - HTTP/2" 200 - via_upstream - "-" 699 1839 1 - "-" "-" "3e0eaa80-7c72-4d46-909a-233a6bd6073e" "10.244.2.9:9080" "10.244.2.9:9080" virtual_inbound 10.244.2.12:41893 10.244.2.9:15008 10.244.2.12:38336 - - inbound hcm
```

After the L7 feature has been enabled in ambient mode, the traffic path between applications is shown in the figure below.
![](/img/2022-09-10-try-istio-ambient/app-in-ambient-l7.png)
<p style="text-align: center;">Application traffic path after enabling waypoint L7 processing</p>

# Routing Traffic

Now let’s try to route the traffic in ambient mode. Ambient mode has the same routing rules as sidecar mode and also uses Virtual service.

First enable the L7 capability for the review service by creating a gateway.

```bash
kubectl apply -f - <<EOF
apiVersion: gateway.networking.k8s.io/v1alpha2
kind: Gateway
metadata:
 name: reviews
 annotations:
   istio.io/service-account: bookinfo-reviews
spec:
 gatewayClassName: istio-mesh
EOF
```

Creat a DR to divide the reviews service into 3 subsets.

```bash
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: reviews
spec:
  host: reviews
  trafficPolicy:
    loadBalancer:
      simple: RANDOM
  subsets:
  - name: v1
    labels:
      version: v1
  - name: v2
    labels:
      version: v2
  - name: v3
    labels:
      version: v3
EOF
```

Create VS and send requests to V1 and V2 versions in 90/10 ratio.

```bash
kubectl apply -f - <<EOF
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: reviews
spec:
  hosts:
    - reviews
  http:
  - route:
    - destination:
        host: reviews
        subset: v1
      weight: 90
    - destination:
        host: reviews
        subset: v2
      weight: 10
EOF
```

Execute the following command to verify that the reviews service requests are routed according to the routing rules defined above.

```bash
kubectl exec -it deploy/sleep -- sh -c 'for i in $(seq 1 10); do curl -s http://istio-ingressgateway.istio-system/productpage | grep reviews-v.-; done'

        <u>reviews-v2-79857b95b-nk8hn</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
        <u>reviews-v1-6494d87c7b-f4lvz</u>
```

# Wrap-up and Key Take-aways

From the above experiments, we can see that ambient mode has solved the deployment dependency problem of application and sidecar in Istio sidecar mode. In ambient mode, the service mesh functionalities are provided through ztunnel and waypoint proxy, which are outside of the application pod, and sidecar injection to the application pods is no longer required. As a result, the lifecycle of application and mesh components such as deployment and upgrade are no longer coupled, bringing the service mesh down to the infrastructure layer as it has promised.

Currently, to enable the L7 processing for a service, you have to create a gateway, which is an additional burden for operations. I was also concerned about the bigger blast radius compared with sidecar. But since a waypoint only serves a service account, this problem can be mitigated by assign a dedicated service account for each service, and it's also a k8s security best-practice we should follow.

Aywany, ambient is still in active development, so I believe these minor issues will be solved soon in future release.

# Reference
* https://istio.io/latest/blog/2022/get-started-ambient/










