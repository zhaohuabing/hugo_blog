---
layout:     post

title:      "Kubernetes Controller 机制详解（一）"
subtitle:   "Kubernetes API List/Watch 机制 与 Informer 客户端库"
description: "Kubernetes(简称K8s) 是一套容器编排和管理系统，可以帮助我们部署、扩展和管理容器化应用程序。在 K8s 中，Controller 是一个重要的组件，它可以根据我们的期望状态和实际状态来进行调谐，以确保我们的应用程序始终处于所需的状态。本系列文章将解析 K8s Controller 的实现机制，并介绍如何编写一个 Controller。"
author: "赵化冰"
date: 2023-03-09
image: "https://images.unsplash.com/photo-1432821596592-e2c18b78144f?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2370&q=80"
published: true
tags:
    - Kubernetes
categories:
    - Tech
showtoc: true
---

Kubernetes(简称K8s) 是一套容器编排和管理系统，可以帮助我们部署、扩展和管理容器化应用程序。在 K8s 中，Controller 是一个重要的组件，它可以根据我们的期望状态和实际状态来进行调谐，以确保我们的应用程序始终处于所需的状态。本系列博文将解析 K8s Controller 的实现机制，并介绍如何编写一个 Controller。

# Controller 原理

在 K8s 中，用户通过**声明式 API** 定义资源的“预期状态”，Controller 则负责监视资源的实际状态，当资源的实际状态和“预期状态”不一致时，Controller 则对系统进行必要的更改，以确保两者一致，这个过程被称之为调谐（Reconcile）。

例如下图中，用户定义了一个 Deployment 资源，其中指定了运行的容器镜像，副本数等信息。Deployment Controller 会根据该定义在 K8s 节点上创建对应的 Pod，并对这些 Pod 进行持续监控。如果某个 Pod 异常退出了，Deployment Controller 会重新创建一个 Pod，以保证系统的实际状态和用户定义的“预期状态”（8个副本）一致。

![](/img/2023-03-09-how-to-create-a-k8s-controller/deployment-controller.png)
<p style="text-align: center;">K8s Controller 的控制循环</p>

K8s 中有多种类型的 Controller，例如 Deployment Controller、ReplicaSet Controller 和 StatefulSet Controller等。每个控制器都有不同的工作原理和适用场景，但它们的基本原理都是相同的。我们也可以根据需要编写 Controller 来实现自定义的业务逻辑。

> 有时候 Controller 也被叫做 Operator。这两个术语的混用有时让人感到迷惑。Controller 是一个通用的术语，凡是遵循 “Watch K8s 资源并根据资源变化进行调谐” 模式的控制程序都可以叫做 Controller。而 Operator 是一种专用的 Controller，用于在 Kubernetes 中管理一些复杂的，有状态的应用程序。例如在 Kubernetes 中管理 MySQL 数据库的 MySQL Operator。

# K8s HTTP API 的 List Watch 机制

前面我们讲到 Controller 需要监控 K8s 中资源的状态，这是如何实现的呢？

K8s API Server 提供了获取某类资源集合的 HTTP API，此类 API 被称为 List 接口。例如下面的 URL 可以列出 default namespace 下面的 pod。

```
HTTP GET api/v1/namespaces/default/pods
```

在该 URL 后面加上参数 ```?watch=true```，则 API Server 会对 default namespace 下面的 pod 的状态进行持续监控，并在 pod 状态发生变化时通过 [chunked](https://datatracker.ietf.org/doc/html/rfc9112#name-chunked-transfer-coding) Response (HTTP 1.1) 或者 [Server Push](https://datatracker.ietf.org/doc/html/rfc9113#name-server-push)（HTTP2）通知到客户端。K8s 称此机制为 [watch](https://kubernetes.io/docs/reference/using-api/api-concepts/#efficient-detection-of-changes)。

```
HTTP GET api/v1/namespaces/default/pods?watch=true
```

![](/img/2023-03-09-how-to-create-a-k8s-controller/k8s-http-api-watch.png)
<p style="text-align: center;">K8s HTTP API 的 Watch 机制</p>


通过使用 ```curl``` 命令向 K8s API Server 发起 HTTP GET 请求，我们可以很直观地查看 K8s 的 List 和 Watch 接口的返回数据。

首先通过 ```kubectl proxy``` 启动 API Server 的代理服务器。

```
kubectl proxy --port 8080
```

通过 ```curl``` 来 List pod 资源。

```
curl http://localhost:8080/api/v1/namespaces/default/pods
```

在该命令的输出中，我们可以看到 HTTP Response 是一个 json 格式的数据结构，里面列出来目前 default namespace 中的所有 pod。在返回数据结构中有一个 ```resourceVersion``` 字段，该字段的值是此次 List 操作得到的资源的版本号。我们在 watch 请求中可以带上该版本号作为参数，API Server 会 watch 将该版本之后的资源变化并通知客户端。

```json
{
  "kind": "PodList",
  "apiVersion": "v1",
  "metadata": {
    "resourceVersion": "770715" //资源版本号
  },
  "items": [
    {
      "metadata": {
        "name": "foo",
        "namespace": "default",
        "uid": "d6adfe72-4e90-4b6e-bf14-b6192acb5d07",
        "resourceVersion": "762448",
        "creationTimestamp": "2023-03-10T16:16:02Z",
        "annotations": {…},
        "managedFields": […]
      },
      "spec": {…},
      "status": {…}
    },
	{
      "metadata": {
        "name": "bar",
        "namespace": "default",
        "uid": "bac55478-ad8d-49a6-bab2-23bfdc788736",
        "resourceVersion": "762904",
        "creationTimestamp": "2023-03-10T16:19:17Z",
        "annotations": {…},
        "managedFields": […]
      },
      "spec": {…},
      "status": {…}
    }
  ]
}
```

在请求中加上 watch 参数，并带上前面 List 返回的版本号，以 watch pod 资源的变化。

```
curl http://localhost:8080/api/v1/namespaces/default/pods?watch=true&resourceVersion=770715
```

在另一个终端中创建一个名为 test 的 pod，然后将其删除，可以看到下面的输出：

```json
{"type":"ADDED","object":{"kind":"Pod","apiVersion":"v1","metadata":{"name":"network-tool1","namespace":"default","uid":"c7173455-4a47-4d7f-818d-6634df001f15","resourceVersion":"744176","creationTimestamp":"2023-03-09T06:59:09Z","annotations":{"kubectl.kubernetes.io/last-applied-configuration":"{\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"annotations\":{\"sidecar.istio.io/inject\":\"false\"},\"name\":\"network-tool1\",\"namespace\":\"default\"},\"spec\":{\"containers\":[{\"image\":\"zhaohuabing/network-tool\",\"name\":\"network-tool1\",\"securityContext\":{\"capabilities\":{\"add\":[\"NET_ADMIN\"]}}}]}}\n","sidecar.istio.io/inject":"false"},"managedFields":[{"manager":"kubectl-client-side-apply","operation":"Update","apiVersion":"v1","time":"2023-03-09T06:59:09Z","fieldsType":"FieldsV1","fieldsV1":{"f:metadata":{"f:annotations":{".":{},"f:kubectl.kubernetes.io/last-applied-configuration":{},"f:sidecar.istio.io/inject":{}}},"f:spec":{"f:containers":{"k:{\"name\":\"network-tool1\"}":{".":{},"f:image":{},"f:imagePullPolicy":{},"f:name":{},"f:resources":{},"f:securityContext":{".":{},"f:capabilities":{".":{},"f:add":{}}},"f:terminationMessagePath":{},"f:terminationMessagePolicy":{}}},"f:dnsPolicy":{},"f:enableServiceLinks":{},"f:restartPolicy":{},"f:schedulerName":{},"f:securityContext":{},"f:terminationGracePeriodSeconds":{}}}},{"manager":"kubelet","operation":"Update","apiVersion":"v1","time":"2023-03-10T13:36:54Z","fieldsType":"FieldsV1","fieldsV1":{"f:status":{"f:conditions":{"k:{\"type\":\"ContainersReady\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:status":{},"f:type":{}},"k:{\"type\":\"Initialized\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:status":{},"f:type":{}},"k:{\"type\":\"Ready\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:status":{},"f:type":{}}},"f:containerStatuses":{},"f:hostIP":{},"f:phase":{},"f:podIP":{},"f:podIPs":{".":{},"k:{\"ip\":\"10.244.0.6\"}":{".":{},"f:ip":{}}},"f:startTime":{}}}}]},"spec":{"volumes":[{"name":"kube-api-access-rdz4f","projected":{"sources":[{"serviceAccountToken":{"expirationSeconds":3607,"path":"token"}},{"configMap":{"name":"kube-root-ca.crt","items":[{"key":"ca.crt","path":"ca.crt"}]}},{"downwardAPI":{"items":[{"path":"namespace","fieldRef":{"apiVersion":"v1","fieldPath":"metadata.namespace"}}]}}],"defaultMode":420}}],"containers":[{"name":"network-tool1","image":"zhaohuabing/network-tool","resources":{},"volumeMounts":[{"name":"kube-api-access-rdz4f","readOnly":true,"mountPath":"/var/run/secrets/kubernetes.io/serviceaccount"}],"terminationMessagePath":"/dev/termination-log","terminationMessagePolicy":"File","imagePullPolicy":"Always","securityContext":{"capabilities":{"add":["NET_ADMIN"]}}}],"restartPolicy":"Always","terminationGracePeriodSeconds":30,"dnsPolicy":"ClusterFirst","serviceAccountName":"default","serviceAccount":"default","nodeName":"aeraki-control-plane","securityContext":{},"schedulerName":"default-scheduler","tolerations":[{"key":"node.kubernetes.io/not-ready","operator":"Exists","effect":"NoExecute","tolerationSeconds":300},{"key":"node.kubernetes.io/unreachable","operator":"Exists","effect":"NoExecute","tolerationSeconds":300}],"priority":0,"enableServiceLinks":true,"preemptionPolicy":"PreemptLowerPriority"},"status":{"phase":"Running","conditions":[{"type":"Initialized","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-09T06:59:09Z"},{"type":"Ready","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-10T13:36:54Z"},{"type":"ContainersReady","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-10T13:36:54Z"},{"type":"PodScheduled","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-09T06:59:09Z"}],"hostIP":"172.20.0.2","podIP":"10.244.0.6","podIPs":[{"ip":"10.244.0.6"}],"startTime":"2023-03-09T06:59:09Z","containerStatuses":[{"name":"network-tool1","state":{"running":{"startedAt":"2023-03-10T13:36:53Z"}},"lastState":{"terminated":{"exitCode":255,"reason":"Unknown","startedAt":"2023-03-09T06:59:18Z","finishedAt":"2023-03-10T13:31:39Z","containerID":"containerd://63447ff37e212b476f96fd7529d734a7ae965c38d596d585bbe6a14b7b38f0ec"}},"ready":true,"restartCount":1,"image":"docker.io/zhaohuabing/network-tool:latest","imageID":"docker.io/zhaohuabing/network-tool@sha256:5843e4f12742f0e34932ba42205f177a62d930eadb419d99fa4881483ea46629","containerID":"containerd://a8c787bc61c1f09d901ac91065b1462533ea32293c43afe3021efd8c92366375","started":true}],"qosClass":"BestEffort"}}}
{"type":"ADDED","object":{"kind":"Pod","apiVersion":"v1","metadata":{"name":"network-tool","namespace":"default","uid":"548a29a9-9359-4858-8a18-48633d29d394","resourceVersion":"744186","creationTimestamp":"2023-03-09T09:30:14Z","annotations":{"kubectl.kubernetes.io/last-applied-configuration":"{\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"annotations\":{\"sidecar.istio.io/inject\":\"false\"},\"name\":\"network-tool\",\"namespace\":\"default\"},\"spec\":{\"containers\":[{\"image\":\"zhaohuabing/network-tool\",\"name\":\"network-tool\",\"securityContext\":{\"capabilities\":{\"add\":[\"NET_ADMIN\"]}}}]}}\n","sidecar.istio.io/inject":"false"},"managedFields":[{"manager":"kubectl-client-side-apply","operation":"Update","apiVersion":"v1","time":"2023-03-09T09:30:14Z","fieldsType":"FieldsV1","fieldsV1":{"f:metadata":{"f:annotations":{".":{},"f:kubectl.kubernetes.io/last-applied-configuration":{},"f:sidecar.istio.io/inject":{}}},"f:spec":{"f:containers":{"k:{\"name\":\"network-tool\"}":{".":{},"f:image":{},"f:imagePullPolicy":{},"f:name":{},"f:resources":{},"f:securityContext":{".":{},"f:capabilities":{".":{},"f:add":{}}},"f:terminationMessagePath":{},"f:terminationMessagePolicy":{}}},"f:dnsPolicy":{},"f:enableServiceLinks":{},"f:restartPolicy":{},"f:schedulerName":{},"f:securityContext":{},"f:terminationGracePeriodSeconds":{}}}},{"manager":"kubelet","operation":"Update","apiVersion":"v1","time":"2023-03-10T13:36:56Z","fieldsType":"FieldsV1","fieldsV1":{"f:status":{"f:conditions":{"k:{\"type\":\"ContainersReady\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:status":{},"f:type":{}},"k:{\"type\":\"Initialized\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:status":{},"f:type":{}},"k:{\"type\":\"Ready\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:status":{},"f:type":{}}},"f:containerStatuses":{},"f:hostIP":{},"f:phase":{},"f:podIP":{},"f:podIPs":{".":{},"k:{\"ip\":\"10.244.0.8\"}":{".":{},"f:ip":{}}},"f:startTime":{}}}}]},"spec":{"volumes":[{"name":"kube-api-access-cwjmv","projected":{"sources":[{"serviceAccountToken":{"expirationSeconds":3607,"path":"token"}},{"configMap":{"name":"kube-root-ca.crt","items":[{"key":"ca.crt","path":"ca.crt"}]}},{"downwardAPI":{"items":[{"path":"namespace","fieldRef":{"apiVersion":"v1","fieldPath":"metadata.namespace"}}]}}],"defaultMode":420}}],"containers":[{"name":"network-tool","image":"zhaohuabing/network-tool","resources":{},"volumeMounts":[{"name":"kube-api-access-cwjmv","readOnly":true,"mountPath":"/var/run/secrets/kubernetes.io/serviceaccount"}],"terminationMessagePath":"/dev/termination-log","terminationMessagePolicy":"File","imagePullPolicy":"Always","securityContext":{"capabilities":{"add":["NET_ADMIN"]}}}],"restartPolicy":"Always","terminationGracePeriodSeconds":30,"dnsPolicy":"ClusterFirst","serviceAccountName":"default","serviceAccount":"default","nodeName":"aeraki-control-plane","securityContext":{},"schedulerName":"default-scheduler","tolerations":[{"key":"node.kubernetes.io/not-ready","operator":"Exists","effect":"NoExecute","tolerationSeconds":300},{"key":"node.kubernetes.io/unreachable","operator":"Exists","effect":"NoExecute","tolerationSeconds":300}],"priority":0,"enableServiceLinks":true,"preemptionPolicy":"PreemptLowerPriority"},"status":{"phase":"Running","conditions":[{"type":"Initialized","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-09T09:30:14Z"},{"type":"Ready","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-10T13:36:56Z"},{"type":"ContainersReady","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-10T13:36:56Z"},{"type":"PodScheduled","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-09T09:30:14Z"}],"hostIP":"172.20.0.2","podIP":"10.244.0.8","podIPs":[{"ip":"10.244.0.8"}],"startTime":"2023-03-09T09:30:14Z","containerStatuses":[{"name":"network-tool","state":{"running":{"startedAt":"2023-03-10T13:36:56Z"}},"lastState":{"terminated":{"exitCode":255,"reason":"Unknown","startedAt":"2023-03-09T09:30:18Z","finishedAt":"2023-03-10T13:31:39Z","containerID":"containerd://b52804466bbe6ad9d233b8c080b8d33289c247dbcf1be4d2bd9c609099041a96"}},"ready":true,"restartCount":1,"image":"docker.io/zhaohuabing/network-tool:latest","imageID":"docker.io/zhaohuabing/network-tool@sha256:5843e4f12742f0e34932ba42205f177a62d930eadb419d99fa4881483ea46629","containerID":"containerd://020d9b471682786883498e220bc48f932973f64fff6c5629559da3dca9d2358e","started":true}],"qosClass":"BestEffort"}}}
{"type":"MODIFIED","object":{"kind":"Pod","apiVersion":"v1","metadata":{"name":"network-tool","namespace":"default","uid":"548a29a9-9359-4858-8a18-48633d29d394","resourceVersion":"759935","creationTimestamp":"2023-03-09T09:30:14Z","deletionTimestamp":"2023-03-10T15:59:10Z","deletionGracePeriodSeconds":30,"annotations":{"kubectl.kubernetes.io/last-applied-configuration":"{\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"annotations\":{\"sidecar.istio.io/inject\":\"false\"},\"name\":\"network-tool\",\"namespace\":\"default\"},\"spec\":{\"containers\":[{\"image\":\"zhaohuabing/network-tool\",\"name\":\"network-tool\",\"securityContext\":{\"capabilities\":{\"add\":[\"NET_ADMIN\"]}}}]}}\n","sidecar.istio.io/inject":"false"},"managedFields":[{"manager":"kubectl-client-side-apply","operation":"Update","apiVersion":"v1","time":"2023-03-09T09:30:14Z","fieldsType":"FieldsV1","fieldsV1":{"f:metadata":{"f:annotations":{".":{},"f:kubectl.kubernetes.io/last-applied-configuration":{},"f:sidecar.istio.io/inject":{}}},"f:spec":{"f:containers":{"k:{\"name\":\"network-tool\"}":{".":{},"f:image":{},"f:imagePullPolicy":{},"f:name":{},"f:resources":{},"f:securityContext":{".":{},"f:capabilities":{".":{},"f:add":{}}},"f:terminationMessagePath":{},"f:terminationMessagePolicy":{}}},"f:dnsPolicy":{},"f:enableServiceLinks":{},"f:restartPolicy":{},"f:schedulerName":{},"f:securityContext":{},"f:terminationGracePeriodSeconds":{}}}},{"manager":"kubelet","operation":"Update","apiVersion":"v1","time":"2023-03-10T13:36:56Z","fieldsType":"FieldsV1","fieldsV1":{"f:status":{"f:conditions":{"k:{\"type\":\"ContainersReady\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:status":{},"f:type":{}},"k:{\"type\":\"Initialized\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:status":{},"f:type":{}},"k:{\"type\":\"Ready\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:status":{},"f:type":{}}},"f:containerStatuses":{},"f:hostIP":{},"f:phase":{},"f:podIP":{},"f:podIPs":{".":{},"k:{\"ip\":\"10.244.0.8\"}":{".":{},"f:ip":{}}},"f:startTime":{}}}}]},"spec":{"volumes":[{"name":"kube-api-access-cwjmv","projected":{"sources":[{"serviceAccountToken":{"expirationSeconds":3607,"path":"token"}},{"configMap":{"name":"kube-root-ca.crt","items":[{"key":"ca.crt","path":"ca.crt"}]}},{"downwardAPI":{"items":[{"path":"namespace","fieldRef":{"apiVersion":"v1","fieldPath":"metadata.namespace"}}]}}],"defaultMode":420}}],"containers":[{"name":"network-tool","image":"zhaohuabing/network-tool","resources":{},"volumeMounts":[{"name":"kube-api-access-cwjmv","readOnly":true,"mountPath":"/var/run/secrets/kubernetes.io/serviceaccount"}],"terminationMessagePath":"/dev/termination-log","terminationMessagePolicy":"File","imagePullPolicy":"Always","securityContext":{"capabilities":{"add":["NET_ADMIN"]}}}],"restartPolicy":"Always","terminationGracePeriodSeconds":30,"dnsPolicy":"ClusterFirst","serviceAccountName":"default","serviceAccount":"default","nodeName":"aeraki-control-plane","securityContext":{},"schedulerName":"default-scheduler","tolerations":[{"key":"node.kubernetes.io/not-ready","operator":"Exists","effect":"NoExecute","tolerationSeconds":300},{"key":"node.kubernetes.io/unreachable","operator":"Exists","effect":"NoExecute","tolerationSeconds":300}],"priority":0,"enableServiceLinks":true,"preemptionPolicy":"PreemptLowerPriority"},"status":{"phase":"Running","conditions":[{"type":"Initialized","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-09T09:30:14Z"},{"type":"Ready","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-10T13:36:56Z"},{"type":"ContainersReady","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-10T13:36:56Z"},{"type":"PodScheduled","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-09T09:30:14Z"}],"hostIP":"172.20.0.2","podIP":"10.244.0.8","podIPs":[{"ip":"10.244.0.8"}],"startTime":"2023-03-09T09:30:14Z","containerStatuses":[{"name":"network-tool","state":{"running":{"startedAt":"2023-03-10T13:36:56Z"}},"lastState":{"terminated":{"exitCode":255,"reason":"Unknown","startedAt":"2023-03-09T09:30:18Z","finishedAt":"2023-03-10T13:31:39Z","containerID":"containerd://b52804466bbe6ad9d233b8c080b8d33289c247dbcf1be4d2bd9c609099041a96"}},"ready":true,"restartCount":1,"image":"docker.io/zhaohuabing/network-tool:latest","imageID":"docker.io/zhaohuabing/network-tool@sha256:5843e4f12742f0e34932ba42205f177a62d930eadb419d99fa4881483ea46629","containerID":"containerd://020d9b471682786883498e220bc48f932973f64fff6c5629559da3dca9d2358e","started":true}],"qosClass":"BestEffort"}}}
{"type":"MODIFIED","object":{"kind":"Pod","apiVersion":"v1","metadata":{"name":"network-tool","namespace":"default","uid":"548a29a9-9359-4858-8a18-48633d29d394","resourceVersion":"760008","creationTimestamp":"2023-03-09T09:30:14Z","deletionTimestamp":"2023-03-10T15:59:10Z","deletionGracePeriodSeconds":30,"annotations":{"kubectl.kubernetes.io/last-applied-configuration":"{\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"annotations\":{\"sidecar.istio.io/inject\":\"false\"},\"name\":\"network-tool\",\"namespace\":\"default\"},\"spec\":{\"containers\":[{\"image\":\"zhaohuabing/network-tool\",\"name\":\"network-tool\",\"securityContext\":{\"capabilities\":{\"add\":[\"NET_ADMIN\"]}}}]}}\n","sidecar.istio.io/inject":"false"},"managedFields":[{"manager":"kubectl-client-side-apply","operation":"Update","apiVersion":"v1","time":"2023-03-09T09:30:14Z","fieldsType":"FieldsV1","fieldsV1":{"f:metadata":{"f:annotations":{".":{},"f:kubectl.kubernetes.io/last-applied-configuration":{},"f:sidecar.istio.io/inject":{}}},"f:spec":{"f:containers":{"k:{\"name\":\"network-tool\"}":{".":{},"f:image":{},"f:imagePullPolicy":{},"f:name":{},"f:resources":{},"f:securityContext":{".":{},"f:capabilities":{".":{},"f:add":{}}},"f:terminationMessagePath":{},"f:terminationMessagePolicy":{}}},"f:dnsPolicy":{},"f:enableServiceLinks":{},"f:restartPolicy":{},"f:schedulerName":{},"f:securityContext":{},"f:terminationGracePeriodSeconds":{}}}},{"manager":"kubelet","operation":"Update","apiVersion":"v1","time":"2023-03-10T15:59:10Z","fieldsType":"FieldsV1","fieldsV1":{"f:status":{"f:conditions":{"k:{\"type\":\"ContainersReady\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:message":{},"f:reason":{},"f:status":{},"f:type":{}},"k:{\"type\":\"Initialized\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:status":{},"f:type":{}},"k:{\"type\":\"Ready\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:message":{},"f:reason":{},"f:status":{},"f:type":{}}},"f:containerStatuses":{},"f:hostIP":{},"f:phase":{},"f:podIP":{},"f:podIPs":{".":{},"k:{\"ip\":\"10.244.0.8\"}":{".":{},"f:ip":{}}},"f:startTime":{}}}}]},"spec":{"volumes":[{"name":"kube-api-access-cwjmv","projected":{"sources":[{"serviceAccountToken":{"expirationSeconds":3607,"path":"token"}},{"configMap":{"name":"kube-root-ca.crt","items":[{"key":"ca.crt","path":"ca.crt"}]}},{"downwardAPI":{"items":[{"path":"namespace","fieldRef":{"apiVersion":"v1","fieldPath":"metadata.namespace"}}]}}],"defaultMode":420}}],"containers":[{"name":"network-tool","image":"zhaohuabing/network-tool","resources":{},"volumeMounts":[{"name":"kube-api-access-cwjmv","readOnly":true,"mountPath":"/var/run/secrets/kubernetes.io/serviceaccount"}],"terminationMessagePath":"/dev/termination-log","terminationMessagePolicy":"File","imagePullPolicy":"Always","securityContext":{"capabilities":{"add":["NET_ADMIN"]}}}],"restartPolicy":"Always","terminationGracePeriodSeconds":30,"dnsPolicy":"ClusterFirst","serviceAccountName":"default","serviceAccount":"default","nodeName":"aeraki-control-plane","securityContext":{},"schedulerName":"default-scheduler","tolerations":[{"key":"node.kubernetes.io/not-ready","operator":"Exists","effect":"NoExecute","tolerationSeconds":300},{"key":"node.kubernetes.io/unreachable","operator":"Exists","effect":"NoExecute","tolerationSeconds":300}],"priority":0,"enableServiceLinks":true,"preemptionPolicy":"PreemptLowerPriority"},"status":{"phase":"Running","conditions":[{"type":"Initialized","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-09T09:30:14Z"},{"type":"Ready","status":"False","lastProbeTime":null,"lastTransitionTime":"2023-03-10T15:59:10Z","reason":"ContainersNotReady","message":"containers with unready status: [network-tool]"},{"type":"ContainersReady","status":"False","lastProbeTime":null,"lastTransitionTime":"2023-03-10T15:59:10Z","reason":"ContainersNotReady","message":"containers with unready status: [network-tool]"},{"type":"PodScheduled","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-09T09:30:14Z"}],"hostIP":"172.20.0.2","podIP":"10.244.0.8","podIPs":[{"ip":"10.244.0.8"}],"startTime":"2023-03-09T09:30:14Z","containerStatuses":[{"name":"network-tool","state":{"terminated":{"exitCode":137,"reason":"Error","startedAt":"2023-03-10T13:36:56Z","finishedAt":"2023-03-10T15:59:10Z","containerID":"containerd://020d9b471682786883498e220bc48f932973f64fff6c5629559da3dca9d2358e"}},"lastState":{"terminated":{"exitCode":255,"reason":"Unknown","startedAt":"2023-03-09T09:30:18Z","finishedAt":"2023-03-10T13:31:39Z","containerID":"containerd://b52804466bbe6ad9d233b8c080b8d33289c247dbcf1be4d2bd9c609099041a96"}},"ready":false,"restartCount":1,"image":"docker.io/zhaohuabing/network-tool:latest","imageID":"docker.io/zhaohuabing/network-tool@sha256:5843e4f12742f0e34932ba42205f177a62d930eadb419d99fa4881483ea46629","containerID":"containerd://020d9b471682786883498e220bc48f932973f64fff6c5629559da3dca9d2358e","started":false}],"qosClass":"BestEffort"}}}
{"type":"MODIFIED","object":{"kind":"Pod","apiVersion":"v1","metadata":{"name":"network-tool","namespace":"default","uid":"548a29a9-9359-4858-8a18-48633d29d394","resourceVersion":"760031","creationTimestamp":"2023-03-09T09:30:14Z","deletionTimestamp":"2023-03-10T15:58:40Z","deletionGracePeriodSeconds":0,"annotations":{"kubectl.kubernetes.io/last-applied-configuration":"{\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"annotations\":{\"sidecar.istio.io/inject\":\"false\"},\"name\":\"network-tool\",\"namespace\":\"default\"},\"spec\":{\"containers\":[{\"image\":\"zhaohuabing/network-tool\",\"name\":\"network-tool\",\"securityContext\":{\"capabilities\":{\"add\":[\"NET_ADMIN\"]}}}]}}\n","sidecar.istio.io/inject":"false"},"managedFields":[{"manager":"kubectl-client-side-apply","operation":"Update","apiVersion":"v1","time":"2023-03-09T09:30:14Z","fieldsType":"FieldsV1","fieldsV1":{"f:metadata":{"f:annotations":{".":{},"f:kubectl.kubernetes.io/last-applied-configuration":{},"f:sidecar.istio.io/inject":{}}},"f:spec":{"f:containers":{"k:{\"name\":\"network-tool\"}":{".":{},"f:image":{},"f:imagePullPolicy":{},"f:name":{},"f:resources":{},"f:securityContext":{".":{},"f:capabilities":{".":{},"f:add":{}}},"f:terminationMessagePath":{},"f:terminationMessagePolicy":{}}},"f:dnsPolicy":{},"f:enableServiceLinks":{},"f:restartPolicy":{},"f:schedulerName":{},"f:securityContext":{},"f:terminationGracePeriodSeconds":{}}}},{"manager":"kubelet","operation":"Update","apiVersion":"v1","time":"2023-03-10T15:59:10Z","fieldsType":"FieldsV1","fieldsV1":{"f:status":{"f:conditions":{"k:{\"type\":\"ContainersReady\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:message":{},"f:reason":{},"f:status":{},"f:type":{}},"k:{\"type\":\"Initialized\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:status":{},"f:type":{}},"k:{\"type\":\"Ready\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:message":{},"f:reason":{},"f:status":{},"f:type":{}}},"f:containerStatuses":{},"f:hostIP":{},"f:phase":{},"f:podIP":{},"f:podIPs":{".":{},"k:{\"ip\":\"10.244.0.8\"}":{".":{},"f:ip":{}}},"f:startTime":{}}}}]},"spec":{"volumes":[{"name":"kube-api-access-cwjmv","projected":{"sources":[{"serviceAccountToken":{"expirationSeconds":3607,"path":"token"}},{"configMap":{"name":"kube-root-ca.crt","items":[{"key":"ca.crt","path":"ca.crt"}]}},{"downwardAPI":{"items":[{"path":"namespace","fieldRef":{"apiVersion":"v1","fieldPath":"metadata.namespace"}}]}}],"defaultMode":420}}],"containers":[{"name":"network-tool","image":"zhaohuabing/network-tool","resources":{},"volumeMounts":[{"name":"kube-api-access-cwjmv","readOnly":true,"mountPath":"/var/run/secrets/kubernetes.io/serviceaccount"}],"terminationMessagePath":"/dev/termination-log","terminationMessagePolicy":"File","imagePullPolicy":"Always","securityContext":{"capabilities":{"add":["NET_ADMIN"]}}}],"restartPolicy":"Always","terminationGracePeriodSeconds":30,"dnsPolicy":"ClusterFirst","serviceAccountName":"default","serviceAccount":"default","nodeName":"aeraki-control-plane","securityContext":{},"schedulerName":"default-scheduler","tolerations":[{"key":"node.kubernetes.io/not-ready","operator":"Exists","effect":"NoExecute","tolerationSeconds":300},{"key":"node.kubernetes.io/unreachable","operator":"Exists","effect":"NoExecute","tolerationSeconds":300}],"priority":0,"enableServiceLinks":true,"preemptionPolicy":"PreemptLowerPriority"},"status":{"phase":"Running","conditions":[{"type":"Initialized","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-09T09:30:14Z"},{"type":"Ready","status":"False","lastProbeTime":null,"lastTransitionTime":"2023-03-10T15:59:10Z","reason":"ContainersNotReady","message":"containers with unready status: [network-tool]"},{"type":"ContainersReady","status":"False","lastProbeTime":null,"lastTransitionTime":"2023-03-10T15:59:10Z","reason":"ContainersNotReady","message":"containers with unready status: [network-tool]"},{"type":"PodScheduled","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-09T09:30:14Z"}],"hostIP":"172.20.0.2","podIP":"10.244.0.8","podIPs":[{"ip":"10.244.0.8"}],"startTime":"2023-03-09T09:30:14Z","containerStatuses":[{"name":"network-tool","state":{"terminated":{"exitCode":137,"reason":"Error","startedAt":"2023-03-10T13:36:56Z","finishedAt":"2023-03-10T15:59:10Z","containerID":"containerd://020d9b471682786883498e220bc48f932973f64fff6c5629559da3dca9d2358e"}},"lastState":{"terminated":{"exitCode":255,"reason":"Unknown","startedAt":"2023-03-09T09:30:18Z","finishedAt":"2023-03-10T13:31:39Z","containerID":"containerd://b52804466bbe6ad9d233b8c080b8d33289c247dbcf1be4d2bd9c609099041a96"}},"ready":false,"restartCount":1,"image":"docker.io/zhaohuabing/network-tool:latest","imageID":"docker.io/zhaohuabing/network-tool@sha256:5843e4f12742f0e34932ba42205f177a62d930eadb419d99fa4881483ea46629","containerID":"containerd://020d9b471682786883498e220bc48f932973f64fff6c5629559da3dca9d2358e","started":false}],"qosClass":"BestEffort"}}}
{"type":"DELETED","object":{"kind":"Pod","apiVersion":"v1","metadata":{"name":"network-tool","namespace":"default","uid":"548a29a9-9359-4858-8a18-48633d29d394","resourceVersion":"760032","creationTimestamp":"2023-03-09T09:30:14Z","deletionTimestamp":"2023-03-10T15:58:40Z","deletionGracePeriodSeconds":0,"annotations":{"kubectl.kubernetes.io/last-applied-configuration":"{\"apiVersion\":\"v1\",\"kind\":\"Pod\",\"metadata\":{\"annotations\":{\"sidecar.istio.io/inject\":\"false\"},\"name\":\"network-tool\",\"namespace\":\"default\"},\"spec\":{\"containers\":[{\"image\":\"zhaohuabing/network-tool\",\"name\":\"network-tool\",\"securityContext\":{\"capabilities\":{\"add\":[\"NET_ADMIN\"]}}}]}}\n","sidecar.istio.io/inject":"false"},"managedFields":[{"manager":"kubectl-client-side-apply","operation":"Update","apiVersion":"v1","time":"2023-03-09T09:30:14Z","fieldsType":"FieldsV1","fieldsV1":{"f:metadata":{"f:annotations":{".":{},"f:kubectl.kubernetes.io/last-applied-configuration":{},"f:sidecar.istio.io/inject":{}}},"f:spec":{"f:containers":{"k:{\"name\":\"network-tool\"}":{".":{},"f:image":{},"f:imagePullPolicy":{},"f:name":{},"f:resources":{},"f:securityContext":{".":{},"f:capabilities":{".":{},"f:add":{}}},"f:terminationMessagePath":{},"f:terminationMessagePolicy":{}}},"f:dnsPolicy":{},"f:enableServiceLinks":{},"f:restartPolicy":{},"f:schedulerName":{},"f:securityContext":{},"f:terminationGracePeriodSeconds":{}}}},{"manager":"kubelet","operation":"Update","apiVersion":"v1","time":"2023-03-10T15:59:10Z","fieldsType":"FieldsV1","fieldsV1":{"f:status":{"f:conditions":{"k:{\"type\":\"ContainersReady\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:message":{},"f:reason":{},"f:status":{},"f:type":{}},"k:{\"type\":\"Initialized\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:status":{},"f:type":{}},"k:{\"type\":\"Ready\"}":{".":{},"f:lastProbeTime":{},"f:lastTransitionTime":{},"f:message":{},"f:reason":{},"f:status":{},"f:type":{}}},"f:containerStatuses":{},"f:hostIP":{},"f:phase":{},"f:podIP":{},"f:podIPs":{".":{},"k:{\"ip\":\"10.244.0.8\"}":{".":{},"f:ip":{}}},"f:startTime":{}}}}]},"spec":{"volumes":[{"name":"kube-api-access-cwjmv","projected":{"sources":[{"serviceAccountToken":{"expirationSeconds":3607,"path":"token"}},{"configMap":{"name":"kube-root-ca.crt","items":[{"key":"ca.crt","path":"ca.crt"}]}},{"downwardAPI":{"items":[{"path":"namespace","fieldRef":{"apiVersion":"v1","fieldPath":"metadata.namespace"}}]}}],"defaultMode":420}}],"containers":[{"name":"network-tool","image":"zhaohuabing/network-tool","resources":{},"volumeMounts":[{"name":"kube-api-access-cwjmv","readOnly":true,"mountPath":"/var/run/secrets/kubernetes.io/serviceaccount"}],"terminationMessagePath":"/dev/termination-log","terminationMessagePolicy":"File","imagePullPolicy":"Always","securityContext":{"capabilities":{"add":["NET_ADMIN"]}}}],"restartPolicy":"Always","terminationGracePeriodSeconds":30,"dnsPolicy":"ClusterFirst","serviceAccountName":"default","serviceAccount":"default","nodeName":"aeraki-control-plane","securityContext":{},"schedulerName":"default-scheduler","tolerations":[{"key":"node.kubernetes.io/not-ready","operator":"Exists","effect":"NoExecute","tolerationSeconds":300},{"key":"node.kubernetes.io/unreachable","operator":"Exists","effect":"NoExecute","tolerationSeconds":300}],"priority":0,"enableServiceLinks":true,"preemptionPolicy":"PreemptLowerPriority"},"status":{"phase":"Running","conditions":[{"type":"Initialized","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-09T09:30:14Z"},{"type":"Ready","status":"False","lastProbeTime":null,"lastTransitionTime":"2023-03-10T15:59:10Z","reason":"ContainersNotReady","message":"containers with unready status: [network-tool]"},{"type":"ContainersReady","status":"False","lastProbeTime":null,"lastTransitionTime":"2023-03-10T15:59:10Z","reason":"ContainersNotReady","message":"containers with unready status: [network-tool]"},{"type":"PodScheduled","status":"True","lastProbeTime":null,"lastTransitionTime":"2023-03-09T09:30:14Z"}],"hostIP":"172.20.0.2","podIP":"10.244.0.8","podIPs":[{"ip":"10.244.0.8"}],"startTime":"2023-03-09T09:30:14Z","containerStatuses":[{"name":"network-tool","state":{"terminated":{"exitCode":137,"reason":"Error","startedAt":"2023-03-10T13:36:56Z","finishedAt":"2023-03-10T15:59:10Z","containerID":"containerd://020d9b471682786883498e220bc48f932973f64fff6c5629559da3dca9d2358e"}},"lastState":{"terminated":{"exitCode":255,"reason":"Unknown","startedAt":"2023-03-09T09:30:18Z","finishedAt":"2023-03-10T13:31:39Z","containerID":"containerd://b52804466bbe6ad9d233b8c080b8d33289c247dbcf1be4d2bd9c609099041a96"}},"ready":false,"restartCount":1,"image":"docker.io/zhaohuabing/network-tool:latest","imageID":"docker.io/zhaohuabing/network-tool@sha256:5843e4f12742f0e34932ba42205f177a62d930eadb419d99fa4881483ea46629","containerID":"containerd://020d9b471682786883498e220bc48f932973f64fff6c5629559da3dca9d2358e","started":false}],"qosClass":"BestEffort"}}}
```

从上面 HTTP Watch 返回的 Response 中，可以看到有三种类型的事件：ADDED，MODIFIED 和 DELETED。ADDED 表示创建了新的 Pod，Pod 的状态变化会产生 MODIFIED 类型的事件，DELETED 则表示 Pod 被删除。

利用 K8s 的 HTTP API，我们可以编写一个最简化版本的 “Controller”。例如下面的程序，该程序的实现逻辑和前面的 curl 请求是相同的，也是通过 HTTP GET 请求来 watch pod 资源。这个 “Controller” 只是用于展示 HTTP API 的 Watch 机制，其中并没有调谐的业务逻辑，只是将 HTTP Response 中收到的事件打印出来。

```go
package main

import (
	"crypto/tls"
	"encoding/json"
	"fmt"
	"net/http"
	"time"
)

const token = "eyJhbGciOiJSUzI1NiIsImtpZCI6ImFRM2J0Z3NmUk1hR2VhV2VRbE5vbkVHbGRSMUIwdEdTU3ZPb21TSXEtMkUifQ.eyJpc3MiOiJrdWJlcm5ldGVzL3NlcnZpY2VhY2NvdW50Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9uYW1lc3BhY2UiOiJkZWZhdWx0Iiwia3ViZXJuZXRlcy5pby9zZXJ2aWNlYWNjb3VudC9zZWNyZXQubmFtZSI6ImFwaS1leHBsb3Jlci10b2tlbi02enMycSIsImt1YmVybmV0ZXMuaW8vc2VydmljZWFjY291bnQvc2VydmljZS1hY2NvdW50Lm5hbWUiOiJhcGktZXhwbG9yZXIiLCJrdWJlcm5ldGVzLmlvL3NlcnZpY2VhY2NvdW50L3NlcnZpY2UtYWNjb3VudC51aWQiOiJmNzMwNDZhYS1jYTcyLTQ0ZjAtODMzNy0zYzk4NWY1NjJkNmYiLCJzdWIiOiJzeXN0ZW06c2VydmljZWFjY291bnQ6ZGVmYXVsdDphcGktZXhwbG9yZXIifQ.ZK6O4ss4qn2qwvw315jjnyvva8EnUszfXDH6vpxa-R5nxbD3t1pDN5us0AYZEkLfTPgDYc9DsKFUmkWCum7AIpAqB79bM8p7NNNDiU5V-DphwT9BAAJqSG2UKhzHtxyY4rzwdKs5n2gVIWGYytmgUYffbkltAMWMJcT7sVUQRMDS3m4we_GS8MDl1mNLzghmPqfcBQKRKJNS0JCjLpdexYZaqw79e4HSa_sMh02P_azWiJWxhDvT-VZPJELmkiwpV6named87SMijBd6EIIu3IOFAa7mqCKzNtp8AJQSc-Ey53AkQlH_7BGRuyfNqx16lhE3ioBbk0NVQkKwVwONkw"
const apiServer = "https://127.0.0.1:55429"

type Pod struct {
	Metadata struct {
		Name              string    `json:"name"`
		Namespace         string    `json:"namespace"`
		CreationTimestamp time.Time `json:"creationTimestamp"`
	} `json:"metadata"`
}

type Event struct {
	EventType string `json:"type"`
	Object    Pod    `json:"object"`
}

func main() {
	// create an HTTP client with authorization token or certificate
	client := &http.Client{
		Transport: &http.Transport{
			TLSClientConfig: &tls.Config{
				InsecureSkipVerify: true, // only use this for testing purposes
			},
		},
	}
	req, err := http.NewRequest("GET", apiServer+"/api/v1/namespaces/default/pods?watch=true",
		nil)
	if err != nil {
		panic(err)
	}
	req.Header.Set("Authorization", "Bearer "+token)

	// send the initial request to list all pods
	resp, err := client.Do(req)
	if err != nil {
		panic(err)
	}
	defer resp.Body.Close()

  var event Event
	decoder := json.NewDecoder(resp.Body)

    // read the response and parse event
	for {
		if err := decoder.Decode(&event); err != nil {
			panic(err)
		}
		fmt.Printf("%s Pod %s \n", event.EventType, event.Object.Metadata.Name)
	}
}
```

为了方便开发者使用，k8s 提供了对封装了 HTTP watch 机制的 go client。如果使用 k8s go client，几十行代码就可以实现一个简单的 Controller，如下所示：

```go
// Example Kubernetes controller using Go and the Kubernetes API client libraries

package main

import (
	"context"
	"fmt"
	corev1 "k8s.io/api/core/v1"
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/watch"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/rest"
)

func main() {
	// create a Kubernetes API client
	config, err := rest.InClusterConfig()
	if err != nil {
		panic(err.Error())
	}
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		panic(err.Error())
	}

	// watch for changes to pods
	watcher, err := clientset.CoreV1().Pods("").Watch(context.Background(), metav1.ListOptions{})
	if err != nil {
		panic(err.Error())
	}

	// loop through events from the watcher
	for event := range watcher.ResultChan() {
		pod := event.Object.(*corev1.Pod)
		switch event.Type {
		case watch.Added:
			fmt.Printf("Pod %s added\n", pod.Name)
			// todo: reconcile logic goes here
		case watch.Modified:
			fmt.Printf("Pod %s modified\n", pod.Name)
			// todo: reconcile logic goes here
		case watch.Deleted:
			fmt.Printf("Pod %s deleted\n", pod.Name)
			// todo: reconcile logic goes here
		}
	}
}
```

# Informer 机制

采用 k8s HTTP API 可以查询 K8s API 资源对象并 Watch 其变化，但大量的 HTTP 调用会对 API Server 造成较大的负荷，而且网络调用可能存在较大的延迟。除此之外，开发者还需要在程序中处理资源的缓存，HTTP 链接出问题后的重连等。为了解决这些问题并简化 Controller 的开发工作，K8s 在 client go 中提供了一个 informer 客户端库。

在 Kubernetes 中，Informer 是一个客户端库，用于监视 Kubernetes API 服务器中的资源并将它们的当前状态缓存到本地。Informer 提供了一种方法，让客户端应用程序可以高效地监视资源的更改，而无需不断地向 API 服务器发出请求。

相比直接采用 HTTP Watch，使用 Kubernetes Informer 有以下优势：

* 减少 API 服务器的负载：通过在本地缓存资源信息，Informer 减少了需要向 API 服务器发出的请求数量。这可以防止由于 API 服务器过载而影响整个集群的性能。

* 提高应用程序性能：使用缓存的数据，客户端应用程序可以快速访问资源信息，而无需等待 API 服务器响应。这可以提高应用程序性能并减少延迟。

* 简化代码：Informer 提供了一种更简单、更流畅的方式来监视 Kubernetes 中的资源更改。客户端应用程序可以使用现有的 Informer 库来处理这些任务，而无需编写复杂的代码来管理与 API 服务器的连接并处理更新。

* 更高的可靠性：由于 Informer 在本地缓存数据，因此即使 API 服务器不可用或存在问题，它们也可以继续工作。这可以确保客户端应用程序即使在底层 Kubernetes 基础结构出现问题时也能保持功能。

采用 Informer 库编写的 Controller 的架构如下图所示：

![](/img/2023-03-09-how-to-create-a-k8s-controller/client-go-controller-interaction.jpeg)
<p style="text-align: center;">Kubernetes Informer 架构<sup>2</sup></p>

图中间的虚线将图分为上下两部分，其中上半部分是 Informer 库中的组件，下半部分则是使用 Informer 库编写的自定义 Controller 中的组件，这两部分一起组成了一个完整的 Controller。

采用 Informer 机制编写的 Controller 中的主要流程如下：

1. Reflector 采用 K8s HTTP API List/Watch API Server 中指定的资源。

    Reflector 会先 List 资源，然后使用 List 接口返回的 resourceVersion 来 watch 后续的资源变化。对应的源码：[Reflector ListAndWatch](https://github.com/kubernetes/client-go/blob/6df09021f998a3b005b8612d21c254b1b4d3d48b/tools/cache/reflector.go#L322)。
	
1. Reflector 将 List 得到的资源列表和后续的资源变化放到一个 FIFO（先进先出）队列中。

    对应的源码：
	* [使用 List 的结果刷新 FIFO 队列](https://github.com/kubernetes/client-go/blob/6df09021f998a3b005b8612d21c254b1b4d3d48b/tools/cache/reflector.go#L563)
	* [将 Watch 收到的事件加入到 FIFO 队列](https://github.com/kubernetes/client-go/blob/6df09021f998a3b005b8612d21c254b1b4d3d48b/tools/cache/reflector.go#L742)

1. Informer 在一个循环中从 FIFO 队列中拿出资源对象进行处理。对应源码：[processLoop](https://github.com/kubernetes/client-go/blob/012954e4d5d6e5d0923a00a5a49f76a8a3f11438/tools/cache/controller.go#L192)。

1. Informer 将从 FIFO 队列中拿出的资源对象放到 Indexer 中。对应的源码：[processDeltas](https://github.com/kubernetes/client-go/blob/012954e4d5d6e5d0923a00a5a49f76a8a3f11438/tools/cache/controller.go#L473)。

    Indexer 是 Informer 中的一个本地缓存，该缓存提供了索引功能（这是该组件取名为 Indexer 的原因），允许基于特定条件（如标签、注释或字段选择器）快速有效地查找资源。此处代码中的 clientState 就是 Indexer，来自于[NewIndexerInformer](https://github.com/kubernetes/client-go/blob/012954e4d5d6e5d0923a00a5a49f76a8a3f11438/tools/cache/controller.go#L392)方法中构建的 Indexer，该 Indexer 作为 clientState 参数传递给了 newInformer 方法。
   
1. Indexer 将收到的资源对象放入其内部的缓存 [ThreadSafeStore](https://github.com/kubernetes/client-go/blob/012954e4d5d6e5d0923a00a5a49f76a8a3f11438/tools/cache/thread_safe_store.go#L41) 中。
1. 回调 Controller 的 ResourceEventHandler，将资源对象变化通知到应用逻辑。对应的源码：[processDeltas](https://github.com/kubernetes/client-go/blob/012954e4d5d6e5d0923a00a5a49f76a8a3f11438/tools/cache/controller.go#L476)。
1. 在 ResourceEventHandler 对资源对象的变化进行处理。
    
	ResourceEventHandler 处于用户的 Controller 代码中，k8s 推荐的编程范式是将收到的消息放入到一个队列中，然后在一个循环中处理该队列中的消息，执行调谐逻辑。推荐该模式的原因是采用队列可以解耦消息生产者（Informer）和消费者（Controller 调谐逻辑），避免消费者阻塞生产者。在用户代码中需要注意几点：
	* 前面我们已经讲到，Reflector 会使用 List 的结果刷新 FIFO 队列，因此 ResourceEventHandler 收到的资源变化消息其实包含了 Informer 启动时获取的完整资源列表，Informer 会采用 ADDED 事件将列表的资源通知到用户 Controller。该机制屏蔽了 List 和 Watch 的细节，保证用户的 ResourceEventHandler 代码中会接收到 Controller 监控的资源的完整数据，包括启动 Controller 前已有的资源数据，以及之后的资源变化。
	* ResourceEventHandler 中收到的消息中只有资源对象的 key，用户在 Controller 中可以使用该 key 为关键字，通过 Indexer 查询本地缓存中的完整资源对象。

下面是采用 Informer 机制来创建 Controller 的例子。该示例代码来自于 [Kubernetes Client Go Repository](https://github.com/kubernetes/client-go/blob/master/examples/workqueue/main.go)，为方便阅读去掉了部分非关键代码。

该示例 Controller 监控了 default namespace 中的 Pod 资源，在 syncToStdout 方法中打印了 pod 名称。可以看到该 Controller 的代码结构和上图是一致的。除此之外，我们在编码时需要注意下面几点：

* 在启动 Controller 时需要调用 ``` informer.Run(stopCh) ``` 方法（参见 107 行）。该方法会调用 Reflector 的 [ListAndWatch](https://github.com/kubernetes/client-go/blob/6df09021f998a3b005b8612d21c254b1b4d3d48b/tools/cache/reflector.go#L322) 方法。ListAndWatch 首先采用 HTTP List API 从 K8s API Server 获取当前的资源列表，然后调用 HTTP Watch API 对资源变化进行监控，并把 List 和 Watch 的收到的资源通过 ResourceEventHandlerFuncs 的 AddFunc UpdateFunc DeleteFunc 三个回调接口分发给 Controller。
* 在开始对队列中的资源事件进行处理之前，先调用 ```cache.WaitForCacheSync(stopCh, c.informer.HasSynced)``` （参见 110 行）。正如其方法名所示，该方法确保 Informer 的本地缓存已经和 K8s API Server 的资源数据进行了同步。当 Reflector 成功调用 ListAndWatch 方法从 K8s API Server 获取到需要监控的资源数据并保存到本地缓存后，会将 ```c.informer.HasSynced``` 设置为 true。在开始业务处理前调用该方法可以确保在本地缓存中的资源数据是和 K8s API Server 中的数据一致的。
* 在对事件进行处理之后，需要调用 ```queue.Done(key)``` 方法将事件从队列中删除，以避免重复处理。
* 如果处理时发生异常，可以通过 ```c.queue.AddRateLimited(key)``` 将出错事件的 key 重新加入到队列中。该方法会对重新加入队列的错误消息进行限流，缺省的限流规则是 10 qps。这意味着当 1 秒内出错的消息大于 10 条时，10 条后的错误消息就会在等待一段时间后才会被重新加入到队列中（参见 74 行的 handleErr 方法）。

{{< highlight go "linenos=inline" >}}

package main

import (
	"flag"
	"fmt"
	"time"

	"k8s.io/klog/v2"

	v1 "k8s.io/api/core/v1"
	"k8s.io/apimachinery/pkg/fields"
	"k8s.io/apimachinery/pkg/util/runtime"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/kubernetes"
	"k8s.io/client-go/tools/cache"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/workqueue"
)

// Controller demonstrates how to implement a controller with client-go.
type Controller struct {
	indexer  cache.Indexer
	queue    workqueue.RateLimitingInterface
	informer cache.Controller
}

// NewController creates a new Controller.
func NewController(queue workqueue.RateLimitingInterface, indexer cache.Indexer, informer cache.Controller) *Controller {
	return &Controller{
		informer: informer,
		indexer:  indexer,
		queue:    queue,
	}
}

func (c *Controller) processNextItem() bool {
	// Wait until there is a new item in the working queue
	key, quit := c.queue.Get()
	if quit {
		return false
	}
	// Tell the queue that we are done with processing this key. 
	defer c.queue.Done(key)

	// Invoke the method containing the business logic
	err := c.syncToStdout(key.(string))
	// Handle the error if something went wrong during the execution of the business logic
	c.handleErr(err, key)
	return true
}

// syncToStdout is the business logic of the controller. In this controller it simply prints
// information about the pod to stdout. In case an error happened, it has to simply return the error.
// The retry logic should not be part of the business logic.
func (c *Controller) syncToStdout(key string) error {
	obj, exists, err := c.indexer.GetByKey(key)
	if err != nil {
		klog.Errorf("Fetching object with key %s from store failed with %v", key, err)
		return err
	}

	if !exists {
		// Below we will warm up our cache with a Pod, so that we will see a delete for one pod
		fmt.Printf("Pod %s does not exist anymore\n", key)
	} else {
		// Note that you also have to check the uid if you have a local controlled resource, which
		// is dependent on the actual instance, to detect that a Pod was recreated with the same name
		fmt.Printf("Sync/Add/Update for Pod %s\n", obj.(*v1.Pod).GetName())
	}
	return nil
}

// handleErr checks if an error happened and makes sure we will retry later.
func (c *Controller) handleErr(err error, key interface{}) {
	if err == nil {
		// Forget about the #AddRateLimited history of the key on every successful synchronization.
		// This ensures that future processing of updates for this key is not delayed because of
		// an outdated error history.
		c.queue.Forget(key)
		return
	}

	// This controller retries 5 times if something goes wrong. After that, it stops trying.
	if c.queue.NumRequeues(key) < 5 {
		klog.Infof("Error syncing pod %v: %v", key, err)

		// Re-enqueue the key rate limited. Based on the rate limiter on the
		// queue and the re-enqueue history, the key will be processed later again.
		c.queue.AddRateLimited(key)
		return
	}

	c.queue.Forget(key)
	// Report to an external entity that, even after several retries, we could not successfully process this key
	runtime.HandleError(err)
	klog.Infof("Dropping pod %q out of the queue: %v", key, err)
}

// Run begins watching and syncing.
func (c *Controller) Run(workers int, stopCh chan struct{}) {
	defer runtime.HandleCrash()

	// Let the workers stop when we are done
	defer c.queue.ShutDown()
	klog.Info("Starting Pod controller")

	go c.informer.Run(stopCh)

	// Wait for all involved caches to be synced, before processing items from the queue is started
	if !cache.WaitForCacheSync(stopCh, c.informer.HasSynced) {
		runtime.HandleError(fmt.Errorf("Timed out waiting for caches to sync"))
		return
	}

	for i := 0; i < workers; i++ {
		go wait.Until(c.runWorker, time.Second, stopCh)
	}

	<-stopCh
	klog.Info("Stopping Pod controller")
}

func (c *Controller) runWorker() {
	for c.processNextItem() {
	}
}

func main() {
	var kubeconfig string
	var master string

	flag.StringVar(&kubeconfig, "kubeconfig", "", "absolute path to the kubeconfig file")
	flag.StringVar(&master, "master", "", "master url")
	flag.Parse()

	// creates the connection
	config, err := clientcmd.BuildConfigFromFlags(master, kubeconfig)
	if err != nil {
		klog.Fatal(err)
	}

	// creates the clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		klog.Fatal(err)
	}

	// create the pod watcher
	podListWatcher := cache.NewListWatchFromClient(clientset.CoreV1().RESTClient(), "pods", v1.NamespaceDefault, fields.Everything())

	// create the workqueue
	queue := workqueue.NewRateLimitingQueue(workqueue.DefaultControllerRateLimiter())

	// Bind the workqueue to a cache with the help of an informer. This way we make sure that
	// whenever the cache is updated, the pod key is added to the workqueue.
	// Note that when we finally process the item from the workqueue, we might see a newer version
	// of the Pod than the version which was responsible for triggering the update.
	indexer, informer := cache.NewIndexerInformer(podListWatcher, &v1.Pod{}, 0, cache.ResourceEventHandlerFuncs{
		AddFunc: func(obj interface{}) {
			key, err := cache.MetaNamespaceKeyFunc(obj)
			if err == nil {
				queue.Add(key)
			}
		},
		UpdateFunc: func(old interface{}, new interface{}) {
			key, err := cache.MetaNamespaceKeyFunc(new)
			if err == nil {
				queue.Add(key)
			}
		},
		DeleteFunc: func(obj interface{}) {
			// IndexerInformer uses a delta queue, therefore for deletes we have to use this
			// key function.
			key, err := cache.DeletionHandlingMetaNamespaceKeyFunc(obj)
			if err == nil {
				queue.Add(key)
			}
		},
	}, cache.Indexers{})

	controller := NewController(queue, indexer, informer)

	// Now let's start the controller
	stop := make(chan struct{})
	defer close(stop)
	go controller.Run(1, stop)

	// Wait forever
	select {}
}
{{< / highlight >}}

# SharedInformer

如果在一个应用中有多处相互独立的业务逻辑都需要监控同一种资源对象，用户会编写多个 Informer 来进行处理。这会导致应用中发起对 K8s API Server 同一资源的多次 ListAndWatch 调用，并且每一个 Informer 中都有一份单独的本地缓存，增加了内存占用。

K8s 在 client go 中基于 Informer 之上再做了一层封装，提供了 SharedInformer 机制。采用 SharedInformer 后，客户端对同一种资源对象只会有一个对 API Server 的 ListAndWatch 调用，多个 Informer 也会共用同一份缓存，减少了对 API Server 的请求，提高了性能。

SharedInformerFactory 中有一个 Informer Map。当应用代码调用 InformerFactory 获取某一资源类型的 Informer 时， SharedInformer 会判断该类型的 Informer 是否存在，如果不存在就新建一个 Informer 并保存到该 Map 中，如果已存在则直接返回该 Informer（参见 SharedInformerFactory 的 [InformerFor](https://github.com/kubernetes/client-go/blob/471f66fb1055201dc7975d416d5889f8e617a4c0/informers/factory.go#L189) 方法）。因此应用中所有从 InformerFactory 中取出的同一类型的 Informer 都是同一个实例。


下面的代码是使用了 SharedInformer 的 Controller 示例。该示例的代码和上一节使用 Informer 的代码大部分是一样的，主要的差别是采用了 ```NewSharedInformerFactory``` 来创建 Informer（参见 158 行）。
我们在使用 SharedInformer 来构建 Controller 时，需要注意下面几点：
* 为了能够共用缓存，同一个 SharedInformerFactory 生成的所有 Informer 只能使用相同的查询过滤条件。
* 在启动 Controller 前需要调用 ``` informerFactory.Start(stop) ``` 方法（参见 195 行）。该方法会调用 factory 中所有 Informer 的 Run 方法。 Informer 会发起向 k8s API Server 的 ListAndWatch 调用，并开始资源事件的监控和消息分发。
* 和直接使用 Informer 相同，在开始对队列中的资源事件进行处理之前，先调用 ```cache.WaitForCacheSync(stopCh, c.informer.HasSynced)``` （参见 121 行），以确保在开始业务处理前，Informer 本地缓存中的资源数据已经和 K8s API Server 进行了同步，数据是一致的。
* 和直接使用 Informer 相同，在对事件进行处理之后，需要调用 ```queue.Done(key)``` 方法将事件从队列中删除，以避免重复处理。
* 和直接使用 Informer 相同， 如果处理时发生异常，可以通过 ```c.queue.AddRateLimited(key)``` 将出错事件的 key 重新加入到队列中。

{{< highlight go "linenos=inline" >}}
package main

import (
	"flag"
	"fmt"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/client-go/informers"
	"time"

	"k8s.io/klog/v2"

	"k8s.io/apimachinery/pkg/util/runtime"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/kubernetes"
	clientv1 "k8s.io/client-go/listers/core/v1"
	"k8s.io/client-go/tools/cache"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/workqueue"
)

// Controller demonstrates how to implement a controller with client-go.
type Controller struct {
	lister   clientv1.PodLister
	queue    workqueue.RateLimitingInterface
	informer cache.Controller
}

// NewController creates a new Controller.
func NewController(queue workqueue.RateLimitingInterface, lister clientv1.PodLister, informer cache.Controller) *Controller {
	return &Controller{
		informer: informer,
		lister:   lister,
		queue:    queue,
	}
}

func (c *Controller) processNextItem() bool {
	// Wait until there is a new item in the working queue
	key, quit := c.queue.Get()
	if quit {
		return false
	}
	// Tell the queue that we are done with processing this key.
	defer c.queue.Done(key)

	// Invoke the method containing the business logic
	err := c.syncToStdout(key.(string))
	// Handle the error if something went wrong during the execution of the business logic
	c.handleErr(err, key)
	return true
}

// syncToStdout is the business logic of the controller. In this controller it simply prints
// information about the pod to stdout. In case an error happened, it has to simply return the error.
// The retry logic should not be part of the business logic.
func (c *Controller) syncToStdout(key string) error {
	namespace, name, err := cache.SplitMetaNamespaceKey(key)
	if err != nil {
		utilruntime.HandleError(fmt.Errorf("invalid resource key: %s", key))
		return nil
	}

	// Get the Foo resource with this namespace/name
	pod, err := c.lister.Pods(namespace).Get(name)
	if err != nil {
		if errors.IsNotFound(err) {
			utilruntime.HandleError(fmt.Errorf("pod '%s' in work queue no longer exists", key))
			return nil
		}

		return err
	}

	// Note that you also have to check the uid if you have a local controlled resource, which
	// is dependent on the actual instance, to detect that a Pod was recreated with the same name
	fmt.Printf("Sync/Add/Update for Pod %s\n", pod.GetName())

	return nil
}

// handleErr checks if an error happened and makes sure we will retry later.
func (c *Controller) handleErr(err error, key interface{}) {
	if err == nil {
		// Forget about the #AddRateLimited history of the key on every successful synchronization.
		// This ensures that future processing of updates for this key is not delayed because of
		// an outdated error history.
		c.queue.Forget(key)
		return
	}

	// This controller retries 5 times if something goes wrong. After that, it stops trying.
	if c.queue.NumRequeues(key) < 5 {
		klog.Infof("Error syncing pod %v: %v", key, err)

		// Re-enqueue the key rate limited. Based on the rate limiter on the
		// queue and the re-enqueue history, the key will be processed later again.
		c.queue.AddRateLimited(key)
		return
	}

	c.queue.Forget(key)
	// Report to an external entity that, even after several retries, we could not successfully process this key
	runtime.HandleError(err)
	klog.Infof("Dropping pod %q out of the queue: %v", key, err)
}

// Run begins watching and syncing.
func (c *Controller) Run(workers int, stopCh chan struct{}) {
	defer runtime.HandleCrash()

	// Let the workers stop when we are done
	defer c.queue.ShutDown()
	klog.Info("Starting Pod controller")

	go c.informer.Run(stopCh)

	// Wait for all involved caches to be synced, before processing items from the queue is started
	if !cache.WaitForCacheSync(stopCh, c.informer.HasSynced) {
		runtime.HandleError(fmt.Errorf("Timed out waiting for caches to sync"))
		return
	}

	for i := 0; i < workers; i++ {
		go wait.Until(c.runWorker, time.Second, stopCh)
	}

	<-stopCh
	klog.Info("Stopping Pod controller")
}

func (c *Controller) runWorker() {
	for c.processNextItem() {
	}
}

func main() {
	var kubeconfig string
	var master string

	flag.StringVar(&kubeconfig, "kubeconfig", "", "absolute path to the kubeconfig file")
	flag.StringVar(&master, "master", "", "master url")
	flag.Parse()

	// creates the connection
	config, err := clientcmd.BuildConfigFromFlags(master, kubeconfig)
	if err != nil {
		klog.Fatal(err)
	}

	// creates the clientset
	clientset, err := kubernetes.NewForConfig(config)
	if err != nil {
		klog.Fatal(err)
	}

	// create an informer factory
	informerFactory := informers.NewSharedInformerFactory(clientset, time.Second*30)

	// create an informer and lister for pods
	informer := informerFactory.Core().V1().Pods()

	// create the workqueue
	queue := workqueue.NewRateLimitingQueue(workqueue.DefaultControllerRateLimiter())

	// register the event handler with the informer
	informer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
		AddFunc: func(obj interface{}) {
			key, err := cache.MetaNamespaceKeyFunc(obj)
			if err == nil {
				queue.Add(key)
			}
		},
		UpdateFunc: func(old interface{}, new interface{}) {
			key, err := cache.MetaNamespaceKeyFunc(new)
			if err == nil {
				queue.Add(key)
			}
		},
		DeleteFunc: func(obj interface{}) {
			// IndexerInformer uses a delta queue, therefore for deletes we have to use this
			// key function.
			key, err := cache.DeletionHandlingMetaNamespaceKeyFunc(obj)
			if err == nil {
				queue.Add(key)
			}
		},
	})

	controller := NewController(queue, informer.Lister(), informer.Informer())

	// Now let's start the controller
	stop := make(chan struct{})
	defer close(stop)
	informerFactory.Start(stop)
	go controller.Run(1, stop)

	// Wait forever
	select {}
}
{{< / highlight >}}

# 采用 Controller 来处理自定义 CRD

在之前的章节中，我们了解到了如何编写一个 Controller 来监控和处理 Kubernetes 中内置的 Pod 资源对象。采用同样的方法，我们也可以编写一个 Controller 来处理自定义的 CRD 资源对象。

我们首先使用下面的 yaml 片段来在 Kubernetes 中创建一个自定义 CRD。该 yaml 文件中定义了名为 Foo 的自定义资源，该资源的 Spec 中有 deployment 和 replica 两个属性，可以看出是对 Deployment 的一个简单封装，即将一个 Deployment 的副本数设置为指定的数量。

```yaml
kubectl apply -f - <<EOF
apiVersion: apiextensions.k8s.io/v1
kind: CustomResourceDefinition
metadata:
  name: foos.samplecontroller.k8s.io
  # for more information on the below annotation, please see
  # https://github.com/kubernetes/enhancements/blob/master/keps/sig-api-machinery/2337-k8s.io-group-protection/README.md
  annotations:
    "api-approved.kubernetes.io": "unapproved, experimental-only; please get an approval from Kubernetes API reviewers if you're trying to develop a CRD in the *.k8s.io or *.kubernetes.io groups"
spec:
  group: samplecontroller.k8s.io
  versions:
    - name: v1alpha1
      served: true
      storage: true
      schema:
        # schema used for validation
        openAPIV3Schema:
          type: object
          properties:
            spec:
              type: object
              properties:
                deploymentName:
                  type: string
                replicas:
                  type: integer
                  minimum: 1
                  maximum: 10
            status:
              type: object
              properties:
                availableReplicas:
                  type: integer
      # subresources for the custom resource
      subresources:
        # enables the status subresource
        status: {}
  names:
    kind: Foo
    plural: foos
  scope: Namespaced
EOF
```

在 Kubernetes 中创建了 Foo 这个 CRD 之后，我们可以采用 kubectl 命令行工具创建/删除/修改该 CRD 对应的资源。例如下面的代码片段将创建一个 名为 ```example-foo``` 的 Foo 资源。该资源要求将 example-foo 这个 Deployment 的副本数设置为5个。

```yaml
apply -f - <<EOF
heredoc> apiVersion: samplecontroller.k8s.io/v1alpha1
kind: Foo
metadata:
  name: example-foo
spec:
  deploymentName: example-foo
  replicas: 5
heredoc> EOF
```

在前面章节的示例中，我们采用 [Inoformer](#informer-机制) 机制来对 Pod 进行监控和调谐；类似地，我们也希望采用类似的方式对新建的该自定义 CRD Foo 进行处理。但是 Kubernetes client go 中只有 Kubernetes 原生的 API 对象相关的接口，并不能处理自定义 CRD。为了对自定义 CRD 进行访问，Kubernetes 提供了 [k8s.io/code-generator](https://github.com/kubernetes/code-generator) 代码生成工具，我们可以使用该工具来生成创建 Informer 需要的相关框架代码，包括 clientset，informers，listers 和 API 对象中相关数据结构的 DeepCopy 方法。

为了使用 go-generator 工具来生成我们需要的 go-client 代码，我们先采用 go 来编写和该 CRD 对应的数据结构。如下面的代码片段所示，CRD 的结构中主要包含下列的内容：

* TypeMeta - CRD 的 Group，Version 和 Kind
* ObjectMeta - 标准的 k8s metadata 字段，包括 name 和 namespace
* Spec - CRD 中的自定义字段
* Status - Spec 对应的状态

```go
/* source code from https://github.com/kubernetes/sample-controller/blob/master/pkg/apis/samplecontroller/v1alpha1/types.go */
package v1alpha1

import (
  metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
)

// +genclient
// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

type Foo struct {
  metav1.TypeMeta   `json:",inline"`
  metav1.ObjectMeta `json:"metadata,omitempty"`

  Spec   FooSpec   `json:"spec"`
  Status FooStatus `json:"status"`
}

type FooSpec struct {
  DeploymentName string `json:"deploymentName"`
  Replicas       *int32 `json:"replicas"`
}

type FooStatus struct {
  AvailableReplicas int32 `json:"availableReplicas"`
}

// +k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object

// FooList is a list of Foo resources
type FooList struct {
  metav1.TypeMeta `json:",inline"`
  metav1.ListMeta `json:"metadata"`

  Items []Foo `json:"items"`
}
```

可以看到，在定义 CRD 的 go 代码中有类似 ```// +...``` 的注释（称为 Tag），go-generator 会根据这些 Tag 来生成 k8s go client 框架代码。

我们需要在 doc.go 文件中使用一个全局 tag ```+k8s:deepcopy-gen=package``` ，来为整个 package 中的所有数据结构生成 DeepCopy 方法。 DeepCopy 方法对数据结构进行深拷贝，当你需要在代码中对该一个对象进行修改，而又不希望影响其他使用到该对象的代码时，可以先对对象进行一次 DeepCopy，拿到该对象的一个副本后再进行操作。


```go
/* source code from https://github.com/kubernetes/sample-controller/blob/master/pkg/apis/samplecontroller/v1alpha1/doc.go */

// +k8s:deepcopy-gen=package
// +groupName=samplecontroller.k8s.io

// Package v1alpha1 is the v1alpha1 version of the API.
package v1alpha1
```

Kubernetes client 要求注册到 Scheme 中的 API 对象必须实现 ```runtime.Object``` 接口。因此除了该全局 Tag 之外，我们可以看到在上面代码片段的 ```Foo``` 和 ```FooList``` 数据结构中，还采用了 ```+k8s:deepcopy-gen:interfaces=k8s.io/apimachinery/pkg/runtime.Object``` 本地 Tag 来告诉 ```deepcoy-gen``` 工具为这两个数据结构生成返回 ```runtime.Objec``` 对象的附加的 ```DeepCopyObject``` 方法。

```+genclient``` 和 ```+groupName=samplecontroller.k8s.io``` 则被 ```client-gen``` 工具用于生成 clientsent。此外，我们还需要使用 ```informer-gen``` 和 ```lister-gen``` 为自定义 CRD 生成 ```informer``` 和 ```lister``` 代码。

为自定义 CRD 生成 go client 代码的脚本在 [hack/update-codegen.sh](https://github.com/zhaohuabing/k8scontrollertutorial/tree/main/hack) 中，生成的代码在本文参考文档的[该链接](https://github.com/zhaohuabing/k8scontrollertutorial/tree/main/pkg/custom)中。

还需要注意的是必须创建一个 [register.go](https://github.com/zhaohuabing/k8scontrollertutorial/blob/main/pkg/custom/apis/foo/v1alpha1/register.go) 文件，在该文件中把自定义 CRD 对应的 golang type 注册到 Scheme 中，否则编译时会报错。

```go
package v1alpha1

import (
	metav1 "k8s.io/apimachinery/pkg/apis/meta/v1"
	"k8s.io/apimachinery/pkg/runtime"
	"k8s.io/apimachinery/pkg/runtime/schema"
)

// GroupName is the group name used in this package
const (
	GroupName = "samplecontroller.k8s.io"
)

// SchemeGroupVersion is group version used to register these objects
var SchemeGroupVersion = schema.GroupVersion{Group: GroupName, Version: "v1alpha1"}

// Kind takes an unqualified kind and returns back a Group qualified GroupKind
func Kind(kind string) schema.GroupKind {
	return SchemeGroupVersion.WithKind(kind).GroupKind()
}

// Resource takes an unqualified resource and returns a Group qualified GroupResource
func Resource(resource string) schema.GroupResource {
	return SchemeGroupVersion.WithResource(resource).GroupResource()
}

var (
	// SchemeBuilder initializes a scheme builder
	SchemeBuilder = runtime.NewSchemeBuilder(addKnownTypes)
	// AddToScheme is a global function that registers this API group & version to a scheme
	AddToScheme = SchemeBuilder.AddToScheme
)

// Adds the list of known types to Scheme.
func addKnownTypes(scheme *runtime.Scheme) error {
	scheme.AddKnownTypes(SchemeGroupVersion,
		&Foo{},
		&FooList{},
	)
	metav1.AddToGroupVersion(scheme, SchemeGroupVersion)
	return nil
}
```

最后我们就可以用生成的代码来编写该自定义 CRD 的 Controller 了，如下面的代码所示。可以看到，该代码和前面章节中通过 Shared Informer 来监控 Pod 的代码几乎一模一样。主要的区别是采用了 go generator 生成的 Foo 这个自定义 CRD 的 clientset，lnformer 和 lister 的相关 package 来替换 Kubernetes go client 自带的 Pod 的相关 package。

```go
package main

import (
	"flag"
	"fmt"
	customscheme "github.com/zhaohuabing/k8scontrollertutorial/pkg/custom/client/clientset/versioned/scheme"
	"k8s.io/client-go/kubernetes/scheme"
	"time"

	customclient "github.com/zhaohuabing/k8scontrollertutorial/pkg/custom/client/clientset/versioned"
	custominformers "github.com/zhaohuabing/k8scontrollertutorial/pkg/custom/client/informers/externalversions"
	customlisters "github.com/zhaohuabing/k8scontrollertutorial/pkg/custom/client/listers/foo/v1alpha1"
	"k8s.io/apimachinery/pkg/api/errors"
	"k8s.io/apimachinery/pkg/util/runtime"
	utilruntime "k8s.io/apimachinery/pkg/util/runtime"
	"k8s.io/apimachinery/pkg/util/wait"
	"k8s.io/client-go/tools/cache"
	"k8s.io/client-go/tools/clientcmd"
	"k8s.io/client-go/util/workqueue"
	"k8s.io/klog/v2"
)

// Controller samplenstrates how to implement a controller with client-go.
type Controller struct {
	lister   customlisters.FooLister
	queue    workqueue.RateLimitingInterface
	informer cache.Controller
}

// NewController creates a new Controller.
func NewController(queue workqueue.RateLimitingInterface, lister customlisters.FooLister,
	informer cache.Controller) *Controller {
	return &Controller{
		informer: informer,
		lister:   lister,
		queue:    queue,
	}
}

func (c *Controller) processNextItem() bool {
	// Wait until there is a new item in the working queue
	key, quit := c.queue.Get()
	if quit {
		return false
	}
	// Tell the queue that we are done with processing this key. This unblocks the key for other workers
	// This allows safe parallel processing because two pods with the same key are never processed in
	// parallel.
	defer c.queue.Done(key)

	// Invoke the method containing the business logic
	err := c.syncToStdout(key.(string))
	// Handle the error if something went wrong during the execution of the business logic
	c.handleErr(err, key)
	return true
}

// syncToStdout is the business logic of the controller. In this controller it simply prints
// information about the pod to stdout. In case an error happened, it has to simply return the error.
// The retry logic should not be part of the business logic.
func (c *Controller) syncToStdout(key string) error {
	namespace, name, err := cache.SplitMetaNamespaceKey(key)
	if err != nil {
		utilruntime.HandleError(fmt.Errorf("invalid resource key: %s", key))
		return nil
	}

	// Get the Foo resource with this namespace/name
	foo, err := c.lister.Foos(namespace).Get(name)
	if err != nil {
		if errors.IsNotFound(err) {
			utilruntime.HandleError(fmt.Errorf("foo '%s' in work queue no longer exists", key))
			return nil
		}

		return err
	}

	// Note that you also have to check the uid if you have a local controlled resource, which
	// is dependent on the actual instance, to detect that a foo was recreated with the same name
	fmt.Printf("Sync/Add/Update for foo %s\n", foo.GetName())

	return nil
}

// handleErr checks if an error happened and makes sure we will retry later.
func (c *Controller) handleErr(err error, key interface{}) {
	if err == nil {
		// Forget about the #AddRateLimited history of the key on every successful synchronization.
		// This ensures that future processing of updates for this key is not delayed because of
		// an outdated error history.
		c.queue.Forget(key)
		return
	}

	// This controller retries 5 times if something goes wrong. After that, it stops trying.
	if c.queue.NumRequeues(key) < 5 {
		klog.Infof("Error syncing foo %v: %v", key, err)

		// Re-enqueue the key rate limited. Based on the rate limiter on the
		// queue and the re-enqueue history, the key will be processed later again.
		c.queue.AddRateLimited(key)
		return
	}

	c.queue.Forget(key)
	// Report to an external entity that, even after several retries, we could not successfully process this key
	runtime.HandleError(err)
	klog.Infof("Dropping foo %q out of the queue: %v", key, err)
}

// Run begins watching and syncing.
func (c *Controller) Run(workers int, stopCh chan struct{}) {
	defer runtime.HandleCrash()

	// Let the workers stop when we are done
	defer c.queue.ShutDown()
	klog.Info("Starting foo controller")

	go c.informer.Run(stopCh)

	// Wait for all involved caches to be synced, before processing items from the queue is started
	if !cache.WaitForCacheSync(stopCh, c.informer.HasSynced) {
		runtime.HandleError(fmt.Errorf("Timed out waiting for caches to sync"))
		return
	}

	for i := 0; i < workers; i++ {
		go wait.Until(c.runWorker, time.Second, stopCh)
	}

	<-stopCh
	klog.Info("Stopping foo controller")
}

func (c *Controller) runWorker() {
	for c.processNextItem() {
	}
}

func main() {
	var kubeconfig string
	var master string

	flag.StringVar(&kubeconfig, "kubeconfig", "", "absolute path to the kubeconfig file")
	flag.StringVar(&master, "master", "", "master url")
	flag.Parse()

	// Add sample-controller types to the default Kubernetes Scheme so Events can be
	// logged for sample-controller types.
	utilruntime.Must(customscheme.AddToScheme(scheme.Scheme))

	// creates the connection
	config, err := clientcmd.BuildConfigFromFlags(master, kubeconfig)
	if err != nil {
		klog.Fatal(err)
	}

	// creates the clientset
	clientset, err := customclient.NewForConfig(config)
	if err != nil {
		klog.Fatal(err)
	}

	// create an informer factory
	informerFactory := custominformers.NewSharedInformerFactory(clientset, time.Second*30)

	// create an informer and lister for foo
	informer := informerFactory.Samplecontroller().V1alpha1().Foos()

	// create the workqueue
	queue := workqueue.NewRateLimitingQueue(workqueue.DefaultControllerRateLimiter())

	// register the event handler with the informer
	informer.Informer().AddEventHandler(cache.ResourceEventHandlerFuncs{
		AddFunc: func(obj interface{}) {
			key, err := cache.MetaNamespaceKeyFunc(obj)
			if err == nil {
				queue.Add(key)
			}
		},
		UpdateFunc: func(old interface{}, new interface{}) {
			key, err := cache.MetaNamespaceKeyFunc(new)
			if err == nil {
				queue.Add(key)
			}
		},
		DeleteFunc: func(obj interface{}) {
			// IndexerInformer uses a delta queue, therefore for deletes we have to use this
			// key function.
			key, err := cache.DeletionHandlingMetaNamespaceKeyFunc(obj)
			if err == nil {
				queue.Add(key)
			}
		},
	})

	controller := NewController(queue, informer.Lister(), informer.Informer())

	// Now let's start the controller
	stop := make(chan struct{})
	defer close(stop)
	informerFactory.Start(stop)
	go controller.Run(1, stop)

	// Wait forever
	select {}
}

```

# Leader Election

在实际部署时，为了保证 Controller 的高可用，我们常常同时运行多个 Controller 实例。在这种情况下，多个 Controller 实例之间需要进行 Leader Election。被选中成为 Leader 的 Controller 实例才执行 Watch 和 Reconcile 逻辑，其余 Controller 处于等待状态。当 Leader 出现问题后，另一个实例会被重新选为 Leader，接替原 Leader 继续执行。

要在应用程序中实现 Leader Election，我们可以部署一个共享 KV 存储系统如 ZooKeeper, etcd 或者 Consul，在其中创建一个用于选主的 kv 节点，KV 存储系统可以保证写操作的原子性，因此多个实例可以通过竞争设置节点的值来实现选主；也可以自己在应用程序中实现选主的算法。为了简化 Controller 的编写，Kubernetes client-go 中提供了 [leaderelection](https://pkg.go.dev/k8s.io/client-go/tools/leaderelection) package。该 package 通过将 Kubernetes 的 lease 资源作为分布式锁来实现了选主逻辑。Kubernetes 为 Controller 的 Leader Election 创建一个 Lease 对象，该对象 spec 中的 holderIdentity 是当前的 Leader，一般会使用 Leader 的 pod name 作为 Identity。leaseDurationSeconds 是锁的租赁时间，renewTime 则是上一次的更新时间。参与选举的实例会判断当前是否存在该 Lease 对象，如果不存在，则会创建一个 Lease 对象，并将 holderIdentity 设为自己，成为 Leader 并执行调谐逻辑。其他实例则会定期检测该 Lease 对象，如果发现租赁过期，则会试图将 holderIdentity 设为自己，成为新的 Leader。

> 备注：Kubernetes client go 曾使用 ConfigMap 和 Endpoint 资源对象来作为分布式锁，并通过资源对象上的 annotation 来记录 Leader Election 信息。不过相对于使用 annotation，lease 资源的 spec 更适用于表示分布式锁的语义。

下面的 yaml 片段是一个 Lease 资源的例子：

```yaml
apiVersion: coordination.k8s.io/v1
kind: Lease
metadata:
  creationTimestamp: "2023-04-02T03:36:42Z"
  name: sample-controller-lock
  namespace: kube-system
  resourceVersion: "1156206"
  uid: bb58f519-ec4b-4e1f-a2d1-923366c33926
spec:
  acquireTime: "2023-04-02T03:36:42.000000Z"
  holderIdentity: sample-controller-5c4497489b-tcfjm
  leaseDurationSeconds: 60
  leaseTransitions: 0
  renewTime: "2023-04-02T05:19:14.533852Z"
```

Kubernetes Client go 已经封装了上面描述的选举逻辑，我们可以直接使用封装后的代码，不必关心 Leader Election 的实现细节。下面是添加了 Leader Election 的代码片段，完整代码参见文后的链接。

```go

func main() {
	.... 略

	controller := NewController(queue, informer.Lister(), informer.Informer())

	// Now let's start the controller
	stop := make(chan struct{})
	defer close(stop)

	kubeclient, err := kubernetes.NewForConfig(config)
	if err != nil {
		klog.Fatal(err)
	}
	rl, err := getResourceLock(kubeclient)
	if err != nil {
		klog.Fatal(err)
	}
	leaderelection.RunOrDie(context.TODO(), leaderelection.LeaderElectionConfig{
		Lock:          rl,
		LeaseDuration: 60 * time.Second,
		RenewDeadline: 15 * time.Second,
		RetryPeriod:   5 * time.Second,
		Callbacks: leaderelection.LeaderCallbacks{
			OnStartedLeading: func(ctx context.Context) {
				informerFactory.Start(stop)
				go controller.Run(1, stop)
			},
			OnStoppedLeading: func() {
				klog.Info("leaderelection lost")
			},
			OnNewLeader: func(identity string) {
				if identity == rl.Identity() {
					klog.Info("leaderelection won")
				}
			},
		},
	})

	// Wait forever
	select {}
}

func getResourceLock(client *kubernetes.Clientset) (resourcelock.Interface, error) {
	lockName := "sample-controller-lock"
	lockNamespace := "kube-system"
	identity, err := os.Hostname()
	if err != nil {
		return nil, err
	}

	return resourcelock.New(
		resourcelock.LeasesResourceLock,
		lockNamespace,
		lockName,
		client.CoreV1(),
		client.CoordinationV1(),
		resourcelock.ResourceLockConfig{
			Identity: identity,
		},
	)
}

```

# 使用 Controller Runtime 和 Kubebuilder

在本文 Pod 和 Foo 的 Controller 示例中，我们采用了 client-go 提供的 Informer 来编写 Controller。但其实我们还可以使用 Controller runtime 或者 kubebuilder 这两个框架来编写 Controller，这两个框架提供了比 Informer 更高层次的抽象，可以进一步简化我们的代码。

下面是采用 Informer，Controller runtime 和 Kubebuilder 来编写 Controller 的区别：

* 直接使用 Informer：直接使用 Informer 编写 Controller 需要编写更多的代码，因为我们需要在代码处理更多的底层细节，例如如何在集群中监视资源，以及如何处理资源变化的通知。但是，使用 Informer 也可以更加自定义和灵活，因为我们可以更细粒度地控制 Controller 的行为。

* Controller runtime：Controller runtime 是基于 Informer 实现的，在 Informer 之上为 Controller 编写提供了高级别的抽象和帮助类，包括 Leader Election、Event Handling 和 Reconcile Loop 等等。使用 Controller runtime，可以更容易地编写和测试 Controller，因为它已经处理了许多底层的细节。

* Kubebuilder：和 Informer 及 Controller runtime 不同，Kubebuilder 并不是一个代码库，而是一个开发框架。Kubebuilder 底层使用了 controller-runtime。Kubebuilder 提供了 CRD 生成器和代码生成器等工具，可以帮助开发者自动生成一些重复性的代码和资源定义，提高开发效率。同时，Kubebuilder 还可以生成 Webhooks，以用于验证自定义资源。

我们将在本系列的后续文章中继续介绍 Controller runtime 和 Kubebuilder 两种机制。

# 参考文档

* [Kubernetes API Concepts: Efficient detection of changes](https://kubernetes.io/docs/reference/using-api/api-concepts/#efficient-detection-of-changes)
* [client-go under the hood](https://github.com/kubernetes/sample-controller/blob/master/docs/controller-client-go.md)
* [Writing Controllers For Kubernetes Resources](https://vivilearns2code.github.io/k8s/2021/03/11/writing-controllers-for-kubernetes-custom-resources.html)
* [Kubernetes sample controller](https://github.com/kubernetes/sample-controller)
* [Kubernetes code generator](https://github.com/kubernetes/code-generator)
* [Groups and Versions and Kinds, oh my!](https://book.kubebuilder.io/cronjob-tutorial/gvks.html#err-but-whats-that-scheme-thing)
* [Leader Election](https://pkg.go.dev/k8s.io/client-go/tools/leaderelection)
* [Leases](https://kubernetes.io/docs/concepts/architecture/leases/)
* [本文中的示例源码](https://github.com/zhaohuabing/k8scontrollertutorial)








