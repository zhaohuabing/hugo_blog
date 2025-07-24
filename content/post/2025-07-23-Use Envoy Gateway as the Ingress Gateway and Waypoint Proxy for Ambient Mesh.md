---
layout:     post

title:      "Bringing Full L7 Power to Istio Ambient Mesh with Envoy Gateway"
subtitle:   ""
description: "In this article, we’ll look at how you can use [Envoy Gateway](https://gateway.envoyproxy.io/), an Envoy project open source solution, together with Istio when running in Ambient mode. This will allow you to easily leverage the power of Envoy’s L7 capabilities for Ingress traffic and east-west traffic in your mesh with easy-to-use CRDs."
author: "Huabing Zhao & Ric Hincapie"
date: 2025-07-24
image: "/img/IMG_1922.jpg"

tags:
    - Istio
    - Envoy
    - Envoy Gateway
categories:
    - Tech
    - Open Source
showtoc: false
---

In this article, we’ll look at how you can use [Envoy Gateway](https://gateway.envoyproxy.io/), an Envoy project open source solution, together with Istio when running in Ambient mode. This will allow you to easily leverage the power of Envoy’s L7 capabilities for Ingress traffic and east-west traffic in your mesh with easy-to-use CRDs.

To understand how this integration works, let’s first take a quick look at **Ambient Mesh** itself. Also known as [**Istio Ambient mode**](https://istio.io/latest/docs/ambient/overview/), it’s a sidecar-less service mesh architecture that aims to simplify deployments and can boost efficiency for specific use cases. Unlike sidecar-based meshes, Ambient splits the data plane into two key components: the **ztunnel**, which secures service-to-service communication, and the **Waypoint Proxy**, which handles Layer 7 traffic routing and policy enforcement.

On the other side, **Envoy Gateway** is a Kubernetes-native API gateway built on top of Envoy Proxy. It’s designed to work seamlessly with the Kubernetes Gateway API and takes a batteries-included approach—offering built-in support for authentication, authorization, rate limiting, CORS handling, header manipulation, and more. These capabilities are exposed through familiar Kubernetes-style APIs, letting you fully tap into Envoy’s power without needing complex configurations.

Because both Ambient Mesh and Envoy Gateway are built on top of Envoy, they share a common foundation. This makes integration straightforward and allows **Envoy Gateway to act as both the Ingress Gateway and Waypoint Proxy**—giving you a consistent and powerful way to manage traffic and apply Layer 7 policies across your mesh.

##  **Why use Envoy Gateway with Ambient Mesh?**

**While Ambient Mesh simplifies service mesh operations by removing sidecars, its feature set doesn’t yet match the maturity of the sidecar-based model**. Some advanced Layer 7 capabilities are either missing, considered experimental, or require extra complexity to configure in native Ambient mode.

**Limited VirtualService Support:**
[VirtualService—a key resource for traffic management in classic Istio—is only available at Alpha level in Ambient](https://istio.io/latest/docs/ambient/usage/l7-features/). On top of that, it can’t be used in combination with Gateway API resources. That leaves you with the Gateway API as the only supported option. While it handles basic routing just fine, it’s intentionally generic to support many gateway implementations. As a result, you lose access to some of the richer, Envoy-specific functionality — such as global rate limiting, circuit breaking, and OIDC authentication.

**Lack of  EnvoyFilter Support:**
In Ambient mode, [EnvoyFilters are not supported](https://github.com/istio/istio/issues/43720). These filters are critical in sidecar deployments when you need to tweak or extend proxy behavior at the xDS level—whether for custom logic, telemetry, or integration with external systems. Without them, your ability to fine-tune proxy behavior is limited, which can be a blocker for advanced or production-grade use cases.

With these limitations, it can be challenging to move from a sidecar-based model to Ambient Mesh without losing important functionality.  **Envoy Gateway** helps bridge that gap. It builds on the Gateway API with [a powerful set of custom policies](https://gateway.envoyproxy.io/latest/tasks/)—like ClientTrafficPolicy, BackendTrafficPolicy, SecurityPolicy, EnvoyExtensionPolicy, and EnvoyPatchPolicy—to **unlock Envoy’s full potential within Ambient Mesh**. These policies can be attached directly to core Gateway API resources such as Gateway and HTTPRoute, enabling fine-grained traffic control, enhanced security, pluggable extensions, and even low-level xDS patching—all without sacrificing the simplicity of a sidecar-free architecture.

![](/img/2025-07-23-Use-Envoy-Gateway-as-the-Ingress-Gateway-and-Waypoint-Proxy-for-Ambient-Mesh/1.png)
<center>Unlocking Envoy’s Full Potential with Envoy Gateway Policies in Ambient Mesh</center>

## How Envoy Gateway Works in Ambient Mesh?

In a default Ambient Mesh deployment, the waypoint proxy handles both terminating the incoming HBONE tunnel and establishing a new one to the destination service. It also applies Layer 7 traffic policies during this process.

![](/img/2025-07-23-Use-Envoy-Gateway-as-the-Ingress-Gateway-and-Waypoint-Proxy-for-Ambient-Mesh/2.png)
<center>Traffic Flow in a Default Waypoint Proxy Deployment</center>

However, Ambient also supports a more modular “sandwich” model, where the ztunnel is logically placed before and after the waypoint proxy—like a sandwich. In this setup, the ztunnel is responsible for managing the HBONE tunnels on both sides, while the waypoint proxy focuses solely on L7 traffic management and policy enforcement.
![](/img/2025-07-23-Use-Envoy-Gateway-as-the-Ingress-Gateway-and-Waypoint-Proxy-for-Ambient-Mesh/3.png)
<center>Traffic Flow in a Sandwiched Waypoint Proxy Deployment</center>

Note: This diagram illustrates how traffic flows through various components in Ambient Mesh. While it appears that there are two zTunnels placed before and after Envoy Gateway, they’re actually the same instance—let’s gloss over that detail for simplicity.

This separation of responsibilities makes it possible to swap out the default waypoint proxy and Ingress Gateway with Envoy Gateway. By doing so, you can leverage Envoy Gateway’s advanced Gateway API capabilities without giving up the simplicity of Ambient Mesh.

This also makes it possible to use Envoy Gateway as the Ingress Gateway for Ambient Mesh. The only difference is that the ztunnel needs to be placed only after Envoy Gateway (not in front), since incoming traffic originates outside the mesh and doesn’t arrive over an HBONE tunnel.

## Setting Up Envoy Gateway as the Ingress Gateway

Let’s get our hands dirty with this duo, creating an Envoy Gateway as Ingress, routing to a backend service and defining a global rate limiting for a specific service. Then, you will deploy an Envoy Gateway as a waypoint proxy.

To begin with, you need to have a Kubernetes cluster with Istio Ambient mode installed, like:

```shell
istioctl install --set profile=ambient
```

Then, install the Envoy Gateway with:

```shell
helm install eg oci://docker.io/envoyproxy/gateway-helm \
  --version v0.0.0-latest \
  --set config.envoyGateway.provider.kubernetes.deploy.type=GatewayNamespace \
  -n envoy-gateway-system \
  --create-namespace
```

Notice the flag for the deploy type. With this you make sure the Gateway is deployed where the Gateway resource is created and not in the envoy-gateway-system namespace, which is the default behavior.

Label the default namespace for ambient onboarding:

```shell
kubectl label namespace default istio.io/dataplane-mode=ambient
```

Last but not least, deploy a backend service you wish to call. In this case, we use Istio’s classic [Bookinfo](https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/bookinfo/platform/kube/bookinfo.yaml) in the default namespace.

```shell
kubectl apply -f https://raw.githubusercontent.com/istio/istio/refs/heads/master/samples/bookinfo/platform/kube/bookinfo.yaml
```

With the canvas in place, it’s time to take the brushes. You need a GatewayClass as the Ingress template, a Gateway instantiating this class and the HTTPRoute establishing the data path bridge. Apply them:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg-ingress
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
EOF
```

In Gateway, notice the gatewayClassName referencing eg-ingress above as well as the onboarding to the Ambient mesh:

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/dataplane-mode: ambient
  name: bookinfo-ingress
spec:
  gatewayClassName: eg-ingress
  listeners:
  - allowedRoutes:
      namespaces:
        from: Same
    name: ingress
    port: 80
    protocol: HTTP
EOF
```

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ingress-bookinfo
spec:
  parentRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: bookinfo-ingress
  rules:
  - backendRefs:
    - group: ""
      kind: Service
      name: productpage
      port: 9080
EOF
```

Now, onto some validations. Attention, as this step will help you get Envoy Gateway and Ambient basic debugging skills. First, check the Gateway is created and that its traffic is intercepted by ztunnel:

```shell
$ kubectl get pod -l app.kubernetes.io/name=envoy
NAME                                                       READY   STATUS    RESTARTS   AGE
bookinfo-ingress-bcc6457b8-qfhcv                           2/2     Running   0          3h11m
$ istioctl ztunnel-config connections --node <NODE_NAME> -o yaml | yq '.[].info | select(.name | test("^envoy*"))'
name: bookinfo-ingress-bcc6457b8-qfhcv
namespace: default
serviceAccount: bookinfo-ingress-bcc6457b8-qfhcv
trustDomain: ""
```

Then, inspect the HTTPRoute was effectively attached to the Gateway and it could find the backend service:

```shell
$ kubectl get httproute ingress-bookinfo -oyaml | yq '.status.parents'
- conditions:
    - lastTransitionTime: "2025-07-18T03:20:14Z"
      message: Route is accepted
      observedGeneration: 1
      reason: Accepted
      status: "True"
      type: Accepted
    - lastTransitionTime: "2025-07-18T03:20:14Z"
      message: Resolved all the Object references for the Route
      observedGeneration: 1
      reason: ResolvedRefs
      status: "True"
      type: ResolvedRefs
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parentRef:
    group: gateway.networking.k8s.io
    kind: Gateway
    name: bookinfo-ingress

```

Seems like everything’s in order. Time to make the requests:

```shell
$ export ENVOY_SERVICE=$(kubectl get svc --selector=gateway.envoyproxy.io/owning-gateway-name=bookinfo-ingress -o jsonpath='{.items[0].metadata.name}')
$ kubectl port-forward service/${ENVOY_SERVICE} 8080:80 &
$ curl localhost:8080/productpage -w '%{http_code}\n' -o /dev/null -s
200
```

Ztunnel logs the following:

```shell
2025-07-18T03:33:20.718599Z	info	access	connection complete	src.addr=10.244.1.70:45168 src.workload="envoy-default-bookinfo-ingress-15c0d731-57b6bb576c-8ltvl" src.namespace="default" src.identity="spiffe://cluster.local/ns/default/sa/envoy-default-bookinfo-ingress-15c0d731" dst.addr=10.244.1.68:15008 dst.hbone_addr=10.244.1.68:9080 dst.workload="productpage-v1-54bb874995-kzpnw" dst.namespace="default" dst.identity="spiffe://cluster.local/ns/default/sa/bookinfo-productpage" direction="outbound" bytes_sent=232 bytes_recv=15245 duration="2022ms"
```

That’s Envoy Gateway sandwiched by ztunnel working as an Ingress for Istio Ambient Mesh\!

Hold on. This Ingress needs rate limiting. This is achieved with a new Redis backend, referencing it in the EG config and applying a BackendTrafficPolicy. We’re deploying a demo Redis instance here for demo purpose. In a production setup, you’ll want to provide your own Redis service—properly secured and scaled to meet your traffic demands.

```yaml
cat <<EOF | kubectl apply -f -
kind: Namespace
apiVersion: v1
metadata:
  name: redis-system
---
apiVersion: apps/v1
kind: Deployment
metadata:
  name: redis
  namespace: redis-system
  labels:
    app: redis
spec:
  replicas: 1
  selector:
    matchLabels:
      app: redis
  template:
    metadata:
      labels:
        app: redis
    spec:
      containers:
      - image: redis:6.0.6
        imagePullPolicy: IfNotPresent
        name: redis
        resources:
          limits:
            cpu: 1500m
            memory: 512Mi
          requests:
            cpu: 200m
            memory: 256Mi
---
apiVersion: v1
kind: Service
metadata:
  name: redis
  namespace: redis-system
  labels:
    app: redis
  annotations:
spec:
  ports:
  - name: redis
    port: 6379
    protocol: TCP
    targetPort: 6379
  selector:
    app: redis
EOF
```

Once the redisD DB is ready, go ahead and upgrade the eg helm release’s values adding a rate limit backend:

```shell
helm upgrade eg oci://docker.io/envoyproxy/gateway-helm \
  --set config.envoyGateway.rateLimit.backend.type=Redis \
  --set config.envoyGateway.rateLimit.backend.redis.url="redis.redis-system.svc.cluster.local:6379" \
  --reuse-values \
  -n envoy-gateway-system

```


Then, create a BackendTrafficPolicy that enforces a limit of 3 requests per hour for non-admin users.

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: productpage-rate-limiting
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: ingress-bookinfo
  rateLimit:
    type: Global
    global:
      rules:
      - clientSelectors:
        - headers:
          - type: Distinct
            name: x-user-id
          - name: x-user-id
            value: admin
            invert: true
        limit:
          requests: 3
          unit: Hour
EOF
```


And test it:

```shell
$ while true; do curl localhost:8080/productpage -H "x-user-id: john" -w '%{http_code}\n' -o /dev/null -s; sleep 1; done
Handling connection for 8080
200
Handling connection for 8080
200
Handling connection for 8080
200
Handling connection for 8080
429
Handling connection for 8080
429
```

## Enabling Envoy Gateway as the Waypoint Proxy

For the waypoint proxy, many steps remain the same—you still create a GatewayClass, a Gateway, and HTTPRoutes. However, you define a separate GatewayClass for the waypoint, as its configuration differs from that of the ingress gateway.

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: gateway.networking.k8s.io/v1
kind: GatewayClass
metadata:
  name: eg-waypoint
spec:
  controllerName: gateway.envoyproxy.io/gatewayclass-controller
  parametersRef:
    group: gateway.envoyproxy.io
    kind: EnvoyProxy
    name: waypoint
    namespace: default
---
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: EnvoyProxy
metadata:
  name: waypoint
spec:
  provider:
    kubernetes:
      envoyService:
        type: ClusterIP
        patch:
          type: StrategicMerge
          value:
            spec:
              ports:
                # HACK:ztunnel currently expects the HBONE port to always be on the Waypoint's Service
                # This will be fixed in future PRs to both istio and ztunnel.
                - name: fake-hbone-port
                  port: 15008
                  protocol: TCP
                  targetPort: 15008
    type: Kubernetes
---
apiVersion: gateway.networking.k8s.io/v1
kind: Gateway
metadata:
  labels:
    istio.io/dataplane-mode: ambient
  name: waypoint
spec:
  gatewayClassName: eg-waypoint
  listeners:
  - allowedRoutes:
      namespaces:
        from: Same
    name: ratings
    port: 9080
    protocol: HTTP
  - allowedRoutes:
      namespaces:
        from: Same
    name: fake-hbone
    port: 15008
    protocol: TCP
---
apiVersion: gateway.networking.k8s.io/v1
kind: HTTPRoute
metadata:
  name: ratings
spec:
  hostnames:
  - ratings
  - ratings.default
  - ratings.default.svc.cluster.local
  parentRefs:
  - group: gateway.networking.k8s.io
    kind: Gateway
    name: waypoint
  rules:
  - backendRefs:
    - group: ""
      kind: Service
      name: ratings
      port: 9080
EOF
```

Label the ratings service so it uses the already deployed waypoint. You could also label the namespace for all services to use it:

```shell
$ kubectl label svc ratings istio.io/use-waypoint=waypoint
```


After making the same request as before, check the waypoint’s logs:

```shell
{":authority":"ratings:9080","bytes_received":0,"bytes_sent":358,"connection_termination_details":null,"downstream_local_address":"10.244.1.73:9080","downstream_remote_address":"10.244.1.68:38315","duration":3,"method":"GET","protocol":"HTTP/1.1","requested_server_name":null,"response_code":200,"response_code_details":"via_upstream","response_flags":"-","route_name":"httproute/default/ratings/rule/0/match/0/ratings","start_time":"2025-07-18T05:16:36.829Z","upstream_cluster":"httproute/default/ratings/rule/0","upstream_host":"10.244.1.65:9080","upstream_local_address":"10.244.1.73:33244","upstream_transport_failure_reason":null,"user-agent":"curl/8.7.1","x-envoy-origin-path":"/ratings/0","x-envoy-upstream-service-time":null,"x-forwarded-for":"10.244.1.68","x-request-id":"839bb7b2-af76-496c-9760-b90f118f191c"}

```

Now let’s look at a more advanced scenario—using features in Envoy Gateway that aren’t yet available in Ambient L7. Circuit breaking is a great example, enabling your service to fail fast and avoid cascading failures when upstreams become unhealthy.

For this, we need a failing service. Luckily, ratings has a delayed mode to simulate it. Add to it this env variable:

```shell
kubectl set env deployment/ratings-v1 SERVICE_VERSION=v-delayed
```

For testing, you can use the [hey load testing tool](https://github.com/rakyll/hey) to send traffic directly to the ratings service from within the cluster.

```shell
kubectl run hey --rm -i   --image=williamyeh/hey   http://ratings:9080/ratings/0
If you don't see a command prompt, try pressing enter.

Summary:
  Total:	28.5228 secs
  Slowest:	7.5211 secs
  Fastest:	0.0005 secs
  Average:	3.6650 secs
  Requests/sec:	7.0119


Response time histogram:
  0.000 [1]	|
  0.753 [98]	|■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  1.505 [0]	|
  2.257 [0]	|
  3.009 [0]	|
  3.761 [0]	|
  4.513 [0]	|
  5.265 [0]	|
  6.017 [0]	|
  6.769 [0]	|
  7.521 [101]	|■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
```

The ratings service adds a 7-second delay to half of the responses, which you can observe in the output from the hey command.


Next, create a new BackendTrafficPolicy with a deliberately aggressive circuit breaker configuration—just enough to make it easy to trip during testing.

```yaml
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: BackendTrafficPolicy
metadata:
  name: circuit-breaker-btp
spec:
  targetRefs:
  - group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: ratings
  circuitBreaker:
      maxPendingRequests: 0
      maxParallelRequests: 10
```

Make sure it has been accepted:

```shell
$ kubectl get backendtrafficpolicy circuit-breaker-btp -ojsonpath='{.status.ancestors[0].conditions}'
[{"lastTransitionTime":"2025-07-22T08:53:59Z","message":"Policy has been accepted.","observedGeneration":2,"reason":"Accepted","status":"True","type":"Accepted"}]%
```

Now, run the hey test again to check if the circuit breaker is kicking in as expected:

```shell
$ kubectl run hey --rm -i --image=williamyeh/hey http://ratings:9080/ratings/0
If you don't see a command prompt, try pressing enter.

Summary:
  Total:	0.7135 secs
  Slowest:	0.6990 secs
  Fastest:	0.0007 secs
  Average:	0.1720 secs
  Requests/sec:	280.3131

  Total data:	16200 bytes
  Size/request:	81 bytes

Response time histogram:
  0.001 [1]	|
  0.071 [149]	|■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■■
  0.140 [0]	|
  0.210 [0]	|
  0.280 [0]	|
  0.350 [0]	|
  0.420 [0]	|
  0.490 [0]	|
  0.559 [0]	|
  0.629 [0]	|
  0.699 [50]	|■■■■■■■■■■■■■

(trimmed)

Status code distribution:
  [503]	200 responses

pod "hey" deleted
```

Notice how most of the requests failed in under 100ms—this indicates that the circuit breaker kicked in and started rejecting traffic quickly.

If you check the waypoint logs, you’ll see clear signs of this in action: the UO response flag and response\_code\_details set to overflow show that the circuit breaker was triggered. Envoy Gateway dropped the excess requests without forwarding them to the ratings service, just as expected.

```shell
$ kubectl logs waypoint-7cc857d87b-8kv2z
Defaulted container "envoy" out of: envoy, shutdown-manager
{":authority":"ratings:9080","bytes_received":0,"bytes_sent":81,"connection_termination_details":null,"downstream_local_address":"10.244.1.36:9080","downstream_remote_address":"10.244.1.41:40909","duration":0,"method":"GET","protocol":"HTTP/1.1","requested_server_name":null,"response_code":503,"response_code_details":"upstream_reset_before_response_started{overflow}","response_flags":"UO","route_name":"httproute/default/ratings/rule/0/match/0/ratings","start_time":"2025-07-22T09:14:19.407Z","upstream_cluster":"httproute/default/ratings/rule/0","upstream_host":"10.244.1.37:9080","upstream_local_address":null,"upstream_transport_failure_reason":null,"user-agent":"hey/0.0.1","x-envoy-origin-path":"/ratings/0","x-envoy-upstream-service-time":null,"x-forwarded-for":"10.244.1.41","x-request-id":"f611fd0a-8b7f-4c7d-ad18-6f0f8812ac6b"}
...

```

Now, it’s time for you to try it out\!

## Should You Use Envoy Gateway with Ambient Mesh?

Envoy Gateway and Ambient Mesh are now fully capable of serving your traffic. Together, they deliver a powerful, batteries-included Layer 7 experience—offering out-of-the-box support for advanced features like rate limiting, OIDC and JWT-based authentication, API key validation, CORS handling, and rich observability. All of this fits neatly into Ambient’s streamlined, sidecar-free model.

Of course, there are tradeoffs. You’ll need to run a separate Envoy Gateway control plane (which you might already be doing if you’re using a non-Istio ingress gateway) and manage some additional configuration.

If the built-in ingress and waypoint proxies already meet your needs, there’s no pressure to switch. But if you’re looking for greater control, stronger security, and more flexibility at Layer 7, Envoy Gateway is a powerful way to level up your Ambient Mesh setup.

**✅ When to Use Envoy Gateway with Ambient**

Consider using Envoy Gateway if you:

* Need advanced Layer 7 features like:

  * Rate limiting

  * JWT/OIDC authentication

  * API key validation

  * CORS handling

  * Wasm or ext\_proc extensions

* Want Gateway API compatibility with more powerful, opinionated policies (e.g., SecurityPolicy, ClientTrafficPolicy)

* Prefer a unified control plane to manage both ingress and internal Layer 7 traffic

* Appreciate a batteries-included gateway that works out of the box—without needing to write custom Envoy filters (unless you really want to)

**❌ When You Might Hold Off (For Now)**

You might want to skip Envoy Gateway—at least for now—if you:

* Are still experimenting with Ambient Mesh and don’t need advanced Layer 7 features

* Are fine with the current limitations of Ambient’s built-in Gateway support (e.g., no VirtualService, limited routing options)

* Want to keep your control plane as lightweight and simple as possible, avoiding extra CRDs or configuration overhead

## What's Next?

Envoy Gateway and Ambient are a duo that will optimize some of your workloads, so we encourage you to try it out. It unblocks the migration as your organization doesn't have to wait for the Istio API to include for Ambient the powerful Envoy features you’ve already experienced in this demo.

Curious to see what else Envoy Gateway can do in an Ambient Mesh? Check out the [official tasks](https://gateway.envoyproxy.io/latest/tasks/) to explore its full feature set.

## References

* [Istio Ambient mode layer 7 features](https://istio.io/latest/docs/ambient/usage/l7-features/)
* [Add EnvoyFilter support for waypoint proxies](https://github.com/istio/istio/issues/43720)
* [Envoy Gateway traffic policies](https://gateway.envoyproxy.io/latest/tasks/)
