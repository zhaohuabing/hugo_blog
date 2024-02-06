---
layout:     post

title:      "Envoy Gateway：十分钟搞定单点登录（SSO）！"
subtitle:   ""
description: "单点登录（SSO）简化了用户体验，使用户能够在访问多个应用时只需一次登录。Envoy Gateway 在最新版本中的安全策略中提供了 OpenID Connect (OIDC) 的能力，采用 Envoy Gateway，无需对应用做任何修改，即可立刻实现基于 OIDC 的单点登录。"
author: "赵化冰"
date: 2023-12-07
image: "https://images.unsplash.com/photo-1461685265823-f8d5d0b08b9b?q=80&w=3870&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
published: true
tags:
    - Envoy Gateway
categories:
    - Tech
    - Open Source
showtoc: true
---

单点登录（SSO）简化了用户体验，使用户能够在访问多个应用时只需一次登录。这提高了用户满意度，减少了密码遗忘的风险，同时增强了安全性。但是，实现单点登录并不容易，需要应用程序实现和认证服务器的交互逻辑，增加了应用程序的开发工作量。Envoy Gateway 在最新版本中的安全策略中提供了 OpenID Connect (OIDC) 的能力，采用 Envoy Gateway，无需对应用做任何修改，在十分钟内即可立刻实现单点登录。

## 什么是单点登录（SSO） ？

SSO 是 英文 Single Sign-On 的缩写，翻译为中文即为单点登录。当采用单点登录之后，用户只需要登录一次，就可以访问多个应用系统。SSO 通常由一个独立的身份管理系统来完成，该系统为每个用户分配一个全局唯一的标识，用户在登录时，只需要提供一次身份认证，就可以访问所有的应用系统。我们在使用一些网站时，经常会看到“使用微信登录”、“使用 Google 账户登录”等按钮，这些网站就是通过 SSO 来实现的。

采用单点登录有以下几个好处：
* 用户只需要登录一次，就可以访问多个应用系统，不需要为每个应用系统都单独登录。
* 应用系统不需要自己实现用户认证，只需将认证工作交给单点登录系统，可以大大减少应用系统的开发工作量。
![sso](/img/2023-12-07-envoy-gateway-security-policy-oidc/sso.png)

## 什么是 OpenID Connect (OIDC) ？

SSO 通常是通过 [OpenID Connect (OIDC) ¹](https://openid.net/specs/openid-connect-core-1_0.html) 来实现的。OIDC 是一个基于 [OAuth 2.0 ²](https://datatracker.ietf.org/doc/html/rfc6749) 协议之上的身份认证协议。

OAuth 2.0 协议本身是一个授权协议，OAuth 2.0 协议中的授权服务器（Authorization Server）负责对用户进行身份认证，认证成功后，授权服务器会向客户端颁发一个访问令牌（Access Token），客户端可以使用该令牌来访问该用户的受保护的资源。例如用户可以通过 OAuth 2.0 授权一个第三方应用访问其 Github 账号下的代码库。Access Token 是一个透明的字符串，只有授权服务器才知道如何解读。客户端会在访问受保护资源时带上 Acces Token，授权服务器根据 Access Token 来判断该请求是否有访问指定资源的权限。Access Token 只用于对资源访问进行授权，其中并没有用户身份信息。

OIDC 通过在 OAuth 2.0 协议之上增加了一个 ID Token 来实现身份认证。OIDC 的认证过程和 OAuth 2.0 的认证过程是一样的，只是认证服务器在对用户认证后向客户端颁发的是一个 ID Token 而不是 Access Token。ID Token 是一个 [JSON Web Token (JWT) ³](https://jwt.io/)，JWT Token 是一个标准的格式，其中包含了用户的身份信息，例如用户的唯一标识，用户名，邮箱等，并且可以通过认证服务器的公钥进行验证，因此可以代表登录的用户身份。OIDC 通过 ID Token 来实现身份认证，从而实现了单点登录。

备注：由于篇幅有限，本文对 OAuth 2.0 只做简单介绍，如果感兴趣的话，可以移步阮一峰老师的 [OAuth 2.0 介绍 ⁴](https://www.ruanyifeng.com/blog/2019/04/oauth_design.html) 系列文章进一步了解协议的原理。

### Envoy Gateway OIDC 认证过程

Envoy Gateway 在最新版本中的安全策略中提供了 OIDC 的能力，可以通过 OIDC 来实现单点登录。OIDC 标准支持通过 OAuth 2.0 中的 Authorization Code Flow，Implicit Flow，Hybrid Flow 三种方式来进行身份认证。Envoy Gateway 采用了其中最安全，也是最常用的 [Authorization Code Flow ⁵](https://datatracker.ietf.org/doc/html/rfc6749#section-4.1)。下图展示了 Envoy Gateway OIDC 的认证过程。

![](/img/2023-12-07-envoy-gateway-security-policy-oidc/oidc.png)

* 当用户访问一个需要进行 OIDC 认证的 HTTPRoute 时，Envoy Gateway 会检查请求中是否有代表用户身份的 ID Token，如果没有，或者 Token 已经过期，则会将请求重定向到 OIDC Provider 的认证页面。
* 用户在 OIDC Provider 的认证页面输入用户名和密码等身份信息进行认证。认证成功后，OIDC Provider 会将用户重定向到 Envoy Gateway 的回调地址，并且带上一个 Authorization Code。
* Envoy Gateway 收到 OIDC Provider 的回调请求后，会将 Authorization Code 发送给 OIDC Provider，OIDC Provider 根据 Authorization Code 生成一个 ID Token，并将 ID Token 返回给 Envoy Gateway。
* Envoy Gateway 收到 ID Token 后，会将 ID Token 保存在一个 Cookie 中，并将请求重定向到原来的 HTTPRoute。
* 当用户再次访问该 HTTPRoute 时，Envoy Gateway 会从 Cookie 中获取 ID Token，验证该 ID Token 合法，并且未过期后，Envoy Gateway 会将请求转发给后端服务。

从图中可以看到，虽然 OIDC 单点登录的过程比较复杂，但都是由 Envoy Gateway 来完成的。对于应用程序来说，这个过程其实是无感知的，应用程序无需修改任何代码，就可以实现单点登录。

## 采用 Envoy Gateway 为应用实现单点登录

采用 Envoy Gateway 可以简化应用关于用户登录的实现，应用程序无需在代码中实现和 OIDC Provicer 交互的相关逻辑，只需要在 Envoy Gateway 的安全策略中配置 OIDC 的相关参数，在十分钟内可实现应用的 OIDC SSO。下面我们通过一个例子来演示如何在 Envoy Gateway 中配置 OIDC。

### 配置 OIDC Provider

Envoy Gateway 支持所有实现了 OIDC 标准的 Identify Provider，包括 Google、微软、Auth0、Okta、微信、微博等等。下面我们以 Google 账户登录为例介绍如何为 Envoy Gateway 配置 OIDC SSO。

首先需要参照 [Google 的 OpenID Connect 文档 ⁶](https://developers.google.com/identity/openid-connect/openid-connect) Google Cloud Platform 中创建一个 OAuth Client ID。

打开 Google Cloud Console 的 [Credentials 界面](https://console.cloud.google.com/apis/credentials)，点击 Create Credentials -> OAuth client ID，然后选择 Web application，输入应用的名称，设置 Authorized redirect URLs 为 `https://www.example.com/oauth2/callback`，然后点击 Create 按钮创建 OAuth Client ID。
![](/img/2023-12-07-envoy-gateway-security-policy-oidc/oauth-client.png)

备注： Envoy Gateway 采用 `%REQ(x-forwarded-proto)%://%REQ(:authority)%/oauth2/callback` 作为默认的 OIDC 回调地址，因此需要将 Authorized redirect URLs 设置为 `https://www.example.com/oauth2/callback`。

创建成功后，会弹出一个页面显示创建的 OAuth client 的信息，记录下其中的 Client ID 和 Client Secret，这两个值将会用于后面的 Envoy Gateway 安全策略配置中。
![](/img/2023-12-07-envoy-gateway-security-policy-oidc/oauth-client-info.png)

### 配置 Envoy Gateway 安全策略

首先参照 [Envoy Gateway Quickstart ⁷](https://gateway.envoyproxy.io/latest/user/quickstart/) 安装 Envoy Gateway 和例子程序。根据 OIDC 规范的建议，Envoy Gateway 要求配置 OIDC 的 Listener 采用 HTTPS 协议，因此前参照 [Secure Gateway ⁸](https://gateway.envoyproxy.io/latest/user/secure-gateways/)为 Envoy Gateway 配置 HTTPS。

创建一个 Kubernetes Secret，用于存储 OAuth Client 的 Client Secret。

注意将 ${CLIENT_SECRET} 替换为上面创建的 OAuth Client 的 Client Secret。

```yaml
$ kubectl create secret generic my-app-client-secret --from-literal=client-secret=${CLIENT_SECRET}
secret "my-app-client-secret" created
```

然后在 Envoy Gateway 中配置 OIDC SSO，首先需要在 Envoy Gateway 中配置一个安全策略，该安全策略用于配置 OIDC SSO 的相关参数。

注意将 ${CLIENT_ID} 替换为上面创建的 OAuth Client 的 Client ID。

```yaml
cat <<EOF | kubectl apply -f -
apiVersion: gateway.envoyproxy.io/v1alpha1
kind: SecurityPolicy
metadata:
  name: oidc-example
spec:
  targetRef:
    group: gateway.networking.k8s.io
    kind: HTTPRoute
    name: backend
  oidc:
    provider:
      issuer: "https://accounts.google.com"
    clientID: "${CLIENT_ID}.apps.googleusercontent.com"
    clientSecret:
      name: "my-app-client-secret"
EOF
```

上面短短十来行配置就会将 OIDC SSO 应用到名为 backend 的 HTTPRoute 上。这样，当客户端请求访问该 HTTPRoute 时，就会被重定向到 Google 页面进行用户验证 。除了 HTTPRoute，Envoy Gateway 还支持将  SecurityPolicy 应用到 Gateway 上，只要将 targetRef 指向 Gateway 即可。

### 验证单点登录

如果集群有对外暴露的 LoadBalancer，可以直接通过 LoadBalancer 的地址访问 Envoy Gateway。如果集群没有对外暴露的 LoadBalancer，可以通过 Port-Forward 的方式将 Gateway 的端口映射到本地，例如：

```shell
export ENVOY_SERVICE=$(kubectl get svc -n envoy-gateway-system --selector=gateway.envoyproxy.io/owning-gateway-namespace=default,gateway.envoyproxy.io/owning-gateway-name=eg -o jsonpath='{.items[0].metadata.name}')

sudo kubectl -n envoy-gateway-system port-forward service/${ENVOY_SERVICE} 443:443
```

将 Envoy Gateway 的地址配置到 DNS 中，例如将 www.example.com 配置到 Envoy Gateway 的地址。

```
127.0.0.1 www.example.com
```

首先在浏览器中访问 Envoy Gateway 的地址，例如 https://www.example.com，Envoy Gateway 会根据 OIDC 的配置引导用户进行登录。浏览器会跳转到 Google 的登录页面。
![](/img/2023-12-07-envoy-gateway-security-policy-oidc/google.png)

输入 Google 账户的用户名和密码，登录成功后，会跳转到应用的首页。
![](/img/2023-12-07-envoy-gateway-security-policy-oidc/backend.png)


## 总结

单点登录（SSO）简化了用户体验，使用户能够在访问多个应用时只需一次登录。但是，实现单点登录并不容易，需要应用程序实现和认证服务器的交互逻辑，增加了应用程序的开发工作量。Envoy Gateway 在最新版本中的安全策略中提供了 OpenID Connect (OIDC) 的能力，采用 Envoy Gateway 的安全策略，让应用程序无需修改任何代码即可轻松实现基于 OIDC 的单点登录（SSO）。


## 参考链接
1. [OpenID Connect (OIDC) ¹](https://openid.net/specs/openid-connect-core-1_0.html)：https://openid.net/specs/openid-connect-core-1_0.html
2. [OAuth 2.0 ²](https://datatracker.ietf.org/doc/html/rfc6749)：https://datatracker.ietf.org/doc/html/rfc6749
3. [JSON Web Token (JWT)³](https://jwt.io/)： https://jwt.io
4. [阮一峰： OAuth 2.0 介绍⁴](https://www.ruanyifeng.com/blog/2019/04/oauth_design.html)： https://www.ruanyifeng.com/blog/2019/04/oauth_design.html
5. [Authorization Code Flow ⁵](https://datatracker.ietf.org/doc/html/rfc6749#section-4.1) ：https://datatracker.ietf.org/doc/html/rfc6749#section-4.1
3. [Google OpenID Connect 文档 ⁶](https://developers.google.com/identity/openid-connect/openid-connect)：https://developers.google.com/identity/openid-connect/openid-connect
4. [Envoy Gateway Quickstart ⁷](https://gateway.envoyproxy.io/latest/user/quickstart/) ：https://gateway.envoyproxy.io/latest/user/quickstart
5. [Secure Gateway ⁸](https://gateway.envoyproxy.io/latest/user/secure-gateways/)：https://gateway.envoyproxy.io/latest/user/secure-gateways



