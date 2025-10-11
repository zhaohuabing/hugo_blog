---
layout:     post
title:      "Envoy Gateway Architecture Diagrams"
subtitle:   ""
excerpt: ""
author:     "赵化冰"
date:       2025-05-12
description: "I put together these diagrams to get a clearer picture of the Envoy Gateway's architecture. If you’re trying to understand how Envoy Gateway works under the hood, you might find them useful too."
showtoc: false
tags:
    - Envoy Gateway
categories:
    - Open Source
---

Oftentimes, I find myself spending a lot of time jumping between different files to understand the codebase while reviewing a PR or
writing a new feature — even when I originally wrote a good chunk of that code myself.

In this sense, human brain feels like an old computer with just 64K of RAM. It's constantly swapping data in and out because
there just isn't enough memory. Before it can do any serious work, it has to reload all the context back into memory — a slow and sometimes frustrating process, especially when you’re doing it over and over.

On the flip side, our brains are really good at understanding the big picture — and that’s where diagrams shine. So I put
these together to help myself quickly get a clearer picture of Envoy Gateway’s architecture whenever I’m reviewing a PR or building something new.

If you’re trying to understand how Envoy Gateway works under the hood, you might find them useful too.

I'll keep updating this post to include more diagrams.

## Overview
![](./envoy-gateway-architecture.png)

## Envoy OAuth Code Flow

```mermaid
sequenceDiagram
    participant U as User (End User)
    participant B as User-Agent (Browser)
    participant E as Envoy
    participant A as Authorization Server
    participant P as Application

    U->>B: Open https://myapp.example.com
    B->>E: HTTP GET / Host: myapp.example.com
    E->>E: validate access and id token in cookie using HMAC
    alt no valid token
        E->>E: generate csrf_token and state
        E->>E: generate code_verifier and code_challenge
        E->>B: HTTP 302 Redirect to Authorization Server with csrf_token and code_challenge in cookies
        B->>A: Authorization request
        A->>B: Redirect to user login page
        U->>B: Submit user credentials
        B->>A: User login request
        alt user authenticated
            A->>B: Redirect to callback with authorization code
            B->>E: Authorization code callback with csrf_token in cookie
            E->>E: validate csrf_token in the state against the one in cookie
            E->>A: Token request with code_verifier
            A->>E: Access token (+ id token + refresh token)
            E->>B: HTTP 302 Redirect to original URL with access and id token in cookies
            B->>E: HTTP GET / Host: myapp.example.com with access and id token in cookies
            E->>P: Forward request with user identity in header
            P-->>E: Response
            E-->>B: Response
        else user not authenticated
            A->>B: Redirect to login page with error
        end
    else valid token
        E->>P: Forward request with user identity in header
        P-->>E: Response
        E-->>B: Response
    end
```

## AI Gateway MCP Auth Flow

Enable centralized access control at the gateway for backend MCP servers that do not natively support the MCP authorization spec:
```mermaid
sequenceDiagram
    participant B as User-Agent (Browser)
    participant C as Client
    participant G as MCP Gateway (Resource Server)
    participant M1 as MCP Server1
    participant M2 as MCP Server2
    participant A as Authorization Server

    C->>G: MCP request without token
    G->>C: HTTP 401 Unauthorized with WWW-Authenticate header
    Note over C: Extract resource_metadata URL from WWW-Authenticate

    C->>G: Request Protected Resource Metadata
    G->>C: Return metadata

    Note over C: Parse metadata and extract authorization server(s)<br/>Client determines AS to use

    C->>A: GET /.well-known/oauth-authorization-server
    A->>C: Authorization server metadata response

    alt Dynamic client registration
        C->>A: POST /register
        A->>C: Client Credentials
    end

    Note over C: Generate PKCE parameters<br/>Include resource parameter
    C->>B: Open browser with authorization URL + code_challenge + resource
    B->>A: Authorization request with resource parameter
    Note over A: User authorizes
    A->>B: Redirect to callback with authorization code
    B->>C: Authorization code callback
    C->>A: Token request + code_verifier + resource
    A->>C: Access token (+ refresh token)
    C->>G: MCP request with access token
    G->>G: verify the access token
    Note over G,G: We can implment fine-grained access control here
    G->>M1: MCP request
    M1-->>G: MCP response
    G-->>C: MCP response
    Note over C,G: MCP communication continues with valid token
    C->>G: MCP request with access token
    G->>M2: MCP request
    M2-->>G: MCP response
    G-->>C: MCP response
    Note over C,G: MCP communication continues with valid token


```
