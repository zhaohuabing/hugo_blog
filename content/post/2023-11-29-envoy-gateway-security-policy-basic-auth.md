---
layout:     post

title:      "Envoy Gateway 安全策略介绍: HTTP Basic Authentication"
subtitle:   ""
description: ""
author: "赵化冰"
date: 2023-11-29
image: "https://gateway.envoyproxy.io/featured-background_hub722101dbe1dbe5596133cb6c8ada6d9_400690_1920x1080_fill_q75_catmullrom_top.jpg"
published: true
tags:
    - Envoy Gateway
categories:
    - Tech
    - Open Source
showtoc: true
---

## 什么是 Envoy Gateway 安全策略？

Envoy Gateway 中的[安全策略 (SecurityPolicy)](https://gateway.envoyproxy.io/v0.6.0/api/extension_types/#securitypolicy) 是 Envoy Gateway 对 Kubernetes Gateway API 的一个扩展资源。SecurityPolicy 采用了 Gateway API 的 [Policy Attachment](https://gateway-api.sigs.k8s.io/geps/gep-713/) 机制来对 Gateway API 进行扩展，为 Envoy Gateway 实现了 CORS，JWT，OIDC，Basic Auth 等强大的安全能力。

## 什么是 HTTP Basic Authentication ?

HTTP Basic Authentication 是一种用于 Web 应用程序的简单用户身份验证协议。在客户端请求访问受保护资源时，服务器会返回 HTTP 401 Unauthorized 响应，并在 WWW-Authenticate头 中指定 Basic 身份验证。客户端接着发送包含 Base64 编码的用户名和密码的 Authorization 头。服务器解码这些凭证，与存储的用户信息进行比较。若匹配成功，服务器允许对资源的访问。一个使用 Basic Authentication 的 HTTP 请求的例子如下：

```
GET /resource/ HTTP/1.1
Host: example.com
Authorization: Basic YWxhZGRpbjpvcGVuc2VzYW1l
```

HTTP Basic Authentication  虽然简单，但是在很多场景下仍然被大量使用，也是网关中的一个常用的场景。但不知为何 Envoy 中之前一直并没有提供 HTTP Basic Authentication 的能力。Envoy Gateway 也因此无法提供 Basic Authentication 能力。为了解决该问题，我前段时间在 Envoy 中实现了 [HTTP Basic Auth Filter](https://github.com/envoyproxy/envoy/pull/30079)，并基于该 Filter 在 Envoy Gateway 中提供了 [HTTP Basic Authentication](https://github.com/envoyproxy/gateway/pull/2224) 的能力。

* Envoy HTTP Basic Auth Filter：https://github.com/envoyproxy/envoy/pull/30079
* Envoy Gateway HTTP Basic Authentication：https://github.com/envoyproxy/gateway/pull/2224

## 如何在 Envoy Gateway 中配置 HTTP Basic Authentication ?

首先参照 [Envoy Gateway Quickstart](https://gateway.envoyproxy.io/v0.6.0/user/quickstart/) 安装 Envoy Gateway 和例子程序。

Envoy Gateway 要求使用 .htpasswd 文件格式来存储用户名和密码。.htpasswd 文件可以通过 htpasswd 命令行工具生成。例如：

```shell
$ htpasswd -cbs .htpasswd foo bar
Adding password for user foo
```

上面的命令会在当前目录下生成一个名为 .htpasswd 的文件，内容如下：

```
foo:{SHA}Ys23Ag/5IOWqZCw9QGaVDdHwH00=
```

其中 foo 是用户名，{SHA}Ys23Ag/5IOWqZCw9QGaVDdHwH00= 是密码的 SHA1 哈希值。可以看到，密码是经过 SHA1 哈希的，不会将密码原文存储在 .htpasswd 文件中。因此，.htpasswd 文件不存在密码泄露的风险。

我们还可以通过 htpasswd 命令行工具来添加继续添加更多的用户名和密码。例如：

```shell
$ htpasswd -bs .htpasswd foo1 bar1
```

这样，.htpasswd 文件中就会有两个用户名和密码了：

```
foo:{SHA}Ys23Ag/5IOWqZCw9QGaVDdHwH00=
foo1:{SHA}djZ11qHY0KOijeymK7aKvYuvhvM=
```

接下来，我们采用刚才生成的 .htpasswd 文件来创建一个 Kubernetes Secret，用于存储用户名和密码。

```shell
$ kubectl create secret generic basic-auth --from-file=.htpasswd
secret
```

查看该 Secrect 的内容如下：

```yaml
apiVersion: v1
data:
  .htpasswd: Zm9vOntTSEF9WXMyM0FnLzVJT1dxWkN3OVFHYVZEZEh3SDAwPQpmb28xOntTSEF9ZGpaMTFxSFkwS09pamV5bUs3YUt2WXV2aHZNPQo=
kind: Secret
metadata:
  creationTimestamp: "2023-11-28T12:24:25Z"
  name: basic-auth
  namespace: default
  resourceVersion: "2227303"
  uid: 0ee724b1-68a8-41c6-bf63-85b75f1e4857
type: Opaque
```

可以看到，.htpasswd 文件中的内容已经被 Base64 编码后存在了 Secret 的 .htpasswd 这个 key 中。这样，我们就可以在 Envoy Gateway 中使用该 Secret 来配置 HTTP Basic Authentication 了。

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: basic-auth-example
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: backend
  basicAuth:
    users:
      name: "basic-auth"
EOF
```

上面的配置会将 HTTP Basic Authentication 应用到名为 backend 的 HTTPRoute 上。这样，当客户端请求访问该 HTTPRoute 时，就需要提供用户名和密码了。除了 HTTPRoute，Envoy Gateway 还支持将  SecurityPolicy 应用到 Gateway 上，只要将 targetRef 指向 Gateway 即可。

尝试不带用户名和密码访问一下该 HTTPRoute：

```shell
curl -v -H "Host: www.example.com" "http://${GATEWAY_HOST}/"
```

可以看到，由于没有认证信息，请求被拒绝了：

```shell
...
< HTTP/1.1 401 Unauthorized
< content-length: 58
< content-type: text/plain
< date: Tue, 28 Nov 2023 12:43:32 GMT
< server: envoy
<
* Connection #0 to host 127.0.0.1 left intact
User authentication failed. Missing username and password.
```

接下来，我们尝试使用正确的用户名和密码访问一下该 HTTPRoute：

```shell
curl -v -H "Host: www.example.com" -u 'foo:bar' "http://${GATEWAY_HOST}/"
```

可以看到，请求被 Envoy Gateway 认证通过，发送到了后端的服务上。

```shell
...
< HTTP/1.1 200 OK
< content-type: application/json
< x-content-type-options: nosniff
< date: Wed, 29 Nov 2023 12:13:28 GMT
< content-length: 556
< x-envoy-upstream-service-time: 0
< server: envoy
...
```

## 总结

本文介绍了 Envoy Gateway 中的安全策略 (SecurityPolicy) 的基本概念，以及如何使用 HTTP Basic Authentication 来保护 HTTPRoute。HTTP Basic Authentication 虽然简单，但是在很多场景下仍然被大量使用，也是网关中的一个常用的场景。支持 HTTP Basic Authentication 也让 Envoy Gateway 可以更好地满足这些场景下的应用。后续文章还会继续介绍 Envoy Gateway 安全策略的其他能力，敬请期待。

## 参考资料

* Envoy HTTP Basic Auth Filter：https://github.com/envoyproxy/envoy/pull/30079
* Envoy Gateway HTTP Basic Authentication：https://github.com/envoyproxy/gateway/pull/2224
* Envoy Gateway Quickstart：https://gateway.envoyproxy.io/v0.6.0/user/quickstart/
* Envoy Gateway Security Policy：https://gateway.envoyproxy.io/v0.6.0/api/extension_types/#securitypolicy


