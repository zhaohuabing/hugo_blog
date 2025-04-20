---
layout:     post

title:      "
Envoy Gateway OIDC Authentication & Authorization Demo"
subtitle:   ""
excerpt: ""
author:     "Robin Zhao"
date:       2025-04-20
description: "In this demo, I’ll walk you through how to use Envoy Gateway’s SecurityPolicy to enforce OIDC authentication and authorization, using Amazon Cognito as the identity provider."
image: "https://upload.wikimedia.org/wikipedia/commons/thumb/6/6e/Hell_Gate_Bridge_%2860275p%29.jpg/2560px-Hell_Gate_Bridge_%2860275p%29.jpg"
published: true
tags:
    - Envoy Gateway
    - OIDC
    - Envoy
categories:
    - Tech
metadata:
    - text: "YouTube"
      link: "https://youtu.be/8K_gpQYcbAY"
    - text: "GitHub"
      link: "https://github.com/zhaohuabing/kubecon-envoy-gateway-securitypolicy"
---

In this demo, I’ll walk you through how to use Envoy Gateway’s SecurityPolicy to enforce OIDC authentication and authorization, using Amazon Cognito as the identity provider.

You’ll learn how to:

- Set up Envoy Gateway in your Kubernetes cluster
- Configure a Gateway + HTTPRoute for HTTPS traffic
- Attach a SecurityPolicy to protect backend services
- Validate JWT tokens and apply fine-grained access control

🎯 Everything is handled at the gateway layer — your backend stays clean and simple.

📦 Try the demo yourself in 5 minutes: https://github.com/zhaohuabing/kubecon-envoy-gateway-securitypolicy

📺 Watch the full demo on YouTube:
{{< youtube 8K_gpQYcbAY >}}
