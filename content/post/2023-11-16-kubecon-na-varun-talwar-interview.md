---
layout:     post

title:      "KubeCon 芝加哥现场报道 - Istio 创始人 Varun Talwar 解密 Istio 开源背后的故事"
subtitle:   ""
description: "前 Goole 产品经理, 硅谷初创企业 Tetrate.io CEO, Istio 创始人 Varun Talwar 解密 Istio 开源背后的故事"
author: "赵化冰"
date: 2023-11-16
image: "https://images.unsplash.com/photo-1597116789352-9ad0fe0cb197?q=80&w=3432&auto=format&fit=crop&ixlib=rb-4.0.3&ixid=M3wxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8fA%3D%3D"
published: true
tags:
    - KubeCon
    - Istio
categories:
    - Tech
    - Open Source
metadata:
    - text: "Bilibili"
      link: "https://www.bilibili.com/video/BV15G411y7hP/"
    - text: "YouTube"
      link: "https://www.youtube.com/watch?v=JtD5wL5WABI"
showtoc: false
---

## Videos

Bilibili
{{< bilibili BV1ZG411S75r >}}

YouTube
{{< youtube JtD5wL5WABI >}}

采访内容(译文):
Huabing：你好， Varun，感谢你接受我们的采访。Varun Talwar 是著名开源项目 Istio 的创始人之一，也是硅谷科技初创公司 Tetrate.io 的联合创始人。那么 Varun，首先能不能给我们简单介绍一下你自己，以及你的背景？

Varun：当然，谢谢 Huabing 的邀请。我叫 Varun，正如 Huabing 说的那样，我是 Tetrate 的联合创始人，现在已经在 Tetra 工作了五年了。在此之前，我在 Google 工作了将近 12 年，先后在 Google 的不同部门工作过，从地图和搜索开始，然后转到 YouTube，再转到云和基础设施。

Huabing：所以你参与了 Google 的很多重要产品？

Varun：是的，很多不同的产品。（和我目前工作）最相关的是最后在 Google 云工作的工作经历。在那里我接触到了整个微服务领域。我通过 GRPC 第一次接触到了微服务。

Huabing：GRPC 是微服务生态系统中非常重要的一部分。每个人都在使用 GRPC 进行微服务服务。

Varun：是的，这就是我如何接触到微服务的。我当时是 GRPC 团队的项目经理。在 1.0 版本时，我们将 GRPC 捐赠给了 CNCF。这对该项目来说是一个重要的里程碑。如你所说，现在 GRPC 已经被广泛使用了。在那之后，我意识到，虽然那些构建新服务的人对 GRPC 感到满意，但是并非所有遗留的服务都能重写。因此我开始寻找基于代理的解决方案，这也最终成为了 Istio。

Huabing：所以你最开始是从新的微服务开始的，但是你发现了遗留服务的问题，我们需要用一种统一的方式来对这些服务进行管理，这是我们需要服务网格的原因。

Varun：是的，这是一个真正的问题，因为大多数运行中的服务都是服务。那么如何将它们现代化并使它们成为云原生生态系统的一部分呢？这就是我开始寻找代理的原因。至于 Istio 的故事，则和 Lyft 和 Matt Klein 相关。Matt Klein 是 envoy 的创始人之一。他们实际上是 GRPC 的用户，这就是我联系上 Matt 的原因。在正式推出 envoy 大约 6，7 个月之前，他告诉我他正在开发 envoy。

OK? So, and it's very hard for Google to accept third party. So why? Because you know, Google always likes to build everything by himself. Yeah, that's why Google is becoming one, do that.

Huabing：所以在推出 Istio 之前，你并没有决定使用 Envoy。

Varun：是的，我们只是在寻找一个足够好的代理，这个代理应该是开源的，应该支持 GRPC 等常用协议。我记得当时很难让 Nginx 支持 HTTP2。即使在一年半之后，Nginx 也没有能支持 HTTP2。我当时在寻找一个理想的代理，这个代理应该是开源的，强大的，动态的，具备丰富的能力，并且支持 GRPC 等常用协议。Envoy 很好地满足了这些要求。

Huabing： Envoy 正好出现在了恰当的时间和地点。

Varun：是的，所以我就把它带到了 Google。我对大家说，我们不需要再重新构建一个代理，Envoy 已经很好了，让我们就用它吧。

Huabing：没有理由再重头编写另一个代理。

Varun：除了我之前提到的那些之外，Envoy 已经开始有了一个生态系统。但 Google 很难接受第三方的东西。Google 总是喜欢自己构建所有的东西。但是我最终说服了所有人，让大家相信直接采用 Envoy 是最好的方式。这是一方面，在同一时间，如你所知，2014 年左右， Kubernetes 刚刚启动。我们旁边就是 Kubernetes 团队。他们告诉了我们一些来自早期 Kubernetes 用户的反馈。我曾总是听到三件事情：第一，用户希望知道在 Kubernetes 中运行的应用服务的情况，而不是只是节点的 CPU 和 Memory。

采访原文：

Hello, Varun, thank you for joining us today. Um Warren Wang, the creator of the famous open source project. Uh sto he's also a co-founder of uh Silicon Valley. Start up the. So Warren to first, can you introduce yourself and give us a little bit uh your background?

Yeah, sure. Thank you, Robin. Thanks for having me. Um Yeah, I have uh my name is Von, as Hing said, uh co-founder for Tetra uh been running the trade for the last five years now. Um And prior to that, I was at uh Google for almost 12 years, a lot uh in different parts of Google uh started with maps and search and then uh and moved to youtube and then moved to cloud and infrastructure.

So you have been involved with so many important products of Google. Yeah, lots of different. Uh So the relevant one is the last stint which was in Google cloud. That's where I got into this whole Microsoft space. Uh My first foray into microservices was actually through GR PC.

Oh, that's very important part of the microservice ecosystem. Everybody just using GR PC uh for the service communication. Yeah, so I was project manager for the GR PC team. Uh And that's how I got into the microservice and uh we got it to one do and donated that to C MC F. So that was a big milestone for that project.

And uh I think now, as you said, it's widely used everywhere, right? So, uh after that, I think what I realized was that people who build new services, like with, they were happy with GR PC. OK. But uh all the existing services that people cannot rewrite. Uh Yeah.

Uh Yeah. So that's when I started looking around for proxy based nonsense and that's how we eventually got to istio. We'll talk more about that. That makes sense. So you start from a new service, but you found a problem.

Are you with your education service? I know you want to relax it two hours together. So that's why we need the. So, yeah. Yeah.

So, yeah, that's the real problem because majority services that like people run are, you know, existing services that they are written. So, so how do you modernize them and make them part of uh the cloud data ecosystem? And uh that started, that's how I started looking for proxies. And uh the story about how sto came about is um uh Lyft and Matt Klein. Matt Klein is one of the creators of envoy.

Uh they were actually GR PC users and uh that's how I was in connection with Matt. Uh and then, you know, about 67 months before formally launching Voy, he told me about Voy that he's working on that. Uh So before you launch the project, actually, you don't think about, we didn't think about it more. Yeah. So we were just thinking about if we needed to find a good proxy that uh you know, that was open, that was supporting GR PC and all these protocols from the start because I was having a really tough time getting uh engine X to support like HTTP.

But uh it took even after like 1, 1.5 years, like nothing happened there, right? Uh So I was looking for proxies and then uh open, powerful, you know, dynamic feature rich supports all these protocols. So although I fit the bill very well and so I just pressed so I brought my into Google and said like, hey, let's not build another proxy. Let's just take this one already there. And besides all the things I talked about it was it already started to have an ecosystem.

So, but I think eventually I could convince everybody that, yeah, this is a better way to do it. Uh per persuasive I think then uh people, you know, that's so that is one side the right, about the same time, like, or, you know, 2014 is when Kubernetes had just launched. Uh And we were sitting right next to the Kubernetes team, right, the early Kubernetes team. And so they were the ones who were giving us like some of the feedback from users, early feedback of Kubernetes, right? So I used to hear three things all the time from co community and those people uh one um we want to know how our services are doing not or how our, you know CPU and memory of our nodes and uh ports is doing, right?

So first tell us how our services like that. So that was one problem that always used to come. So just care about the uh the computer, the worker, they don't have the application, it was more infrastructure applications work. So that was one second thing was, hey, we cannot do any of these uh L seven features with cup proxy.

这是一个用户总是提到的问题。

Huabing：Kubernetes 本身只关注计算、网络，而不关注应用层面的问题。

Varun：是的，Kubernetes 更多的是关注基础设施，而不是应用层面的问题。第二个问题是，我们无法使用 Kubernetes 代理来实现任何 L7 层面的功能。Kube-Proxy 无法实现流量路由，请求层面的负载均衡等七层能力。第三个问题是，如何加密服务直接的流量？这很难。在将近一年的时间内，我从用户那里持续听到这些问题。

Sure. Right. Uh We can't do like traffic routing request level losing all all of that stuff, right? So, and then the third one was uh around uh how can we encrypt traffic uh between services, right? It's hard.

So almost for one year, I heard these consistently coming from them. 
在

So that's why you uh got inspired to create a to, to solve all these problems. So I basically took what also I had and then added some pieces on top for control plane and uh Spiffy and some of those concepts and then address those three needs and then that's how we took him. So, so just different pieces of reward and compare this project. Yeah.
Huabing： 所以你从这些 Kubernetes 用户的反馈中得到了启发，创建 Istio 来解决这些问题。

Varun： 是的，我基本上是以 Envoy 为基础，然后在此之上添加了一些控制平面的功能，以及 SPIFFE 等概念，来解决了这三个问题，这就是 Istio 的由来。

But, you know, because it was solving like these key problems. I was, I, I knew it will be very, it will take off, it will be popular, right? Uh So the rest of it was just the marketing of Google, right? First of all, some people to accept this. Yeah, we got the whole ecosystem behind it like uh IBM Red Hat uh pivotal at that time, Cloud foundry at that time.
因为 Istio 解决了这些关键问题，所以我知道它会很受欢迎。所以接下来就是一些宣传工作，让 Google 接受这个项目。当时 Istio 项目已经有了很多重要的参与者，包括 IBM、Red Hat、Pivotal、Cloud Foundry 等。然后我们于 2017 年 5 月在 KubeCon 上正式发布了 Istio 项目，当时是 0.1版本。

Uh uh like we got everybody involved to say like you get behind this effort. And uh you know, then after that, we launched it in Glucon in May of 2017. This was a to 0.1. OK. Uh And uh as soon as back in like uh 27 2018, May of 2017.

Huabing: 你记得 Istio 项目发布的那一天吗？

Varun：是的，我记得 2017 年 5 月 23 日。我记得当我们发布了博客文章，我们都在 KubeCon Istio 的发布演讲会场上，人满为患，人们在外面等着，会场里已经没有位置了。这就是 Istio 诞生的故事，这是它的起点。

Yeah, I, I remember that 23rd May 2017. I remember when we published the blog post and I remember that uh we were all at Glucon and uh the introductory, like the launching talk of to was like, it was full, like people were waiting outside, like there was not enough room in the uh in that conference room. Uh Yeah. So that's how it still came about. Uh That's the start of it.

And then of course, you know, from there, it just took off. Yeah. So um it's fascinating to have someone, you know, or how to important role. First, you are a star co founder of the start up uh based on his T and uh also you are very important role play very important role in the creation of STO project. So um what motivated you to create this starup?

Huabing：你身上有两个重要的身份，你既是 Istio 项目的创始人之一，也是硅谷初创科技公司 Tetrate.io 的联合创始人。那么是什么促使你创建 Tetrate.io 这家公司的呢？你希望 Tetrate 为用户解决什么样的问题？

Uh um you mean to create this uh start up? So what kind of challenges you want to address? Yeah. So continuing the story, right? So as I talked to lots of users after this day was launched, probably 50 to 100 companies, at least, right?

Varun：继续上面的故事，我在 Istio 发布之后，和大量的用户进行了就 Istio 进行了交流。我想这些用户至少涉及到 50 到 100 家公司。

Uh And everyone gave us uh you know, feedback that one. This is great. It's, it's, it's a great concept but we want this to run like we want these capabilities uh wherever we are running and we want them outside where it is as well. Yeah, yeah. So it's uh like uh it's an infrastructure but we, we also good to uh operation were to manage that kind of infrastructure, someone to add room.

每个用户都给了我们类似的反馈：首先，他们认为 Istio 是一个很棒的项目，但是他们希望 Istio 能够在他们自己的环境中运行，他们希望在 Kubernetes 之外的环境中也可以使用 Istio。

Huabing：所以 Istio 是一个基础设施，但是我们也需要运维人员来管理这个基础设施。

And people were very clear that if uh like this is, if it's just within where it is, it's uh it's useful, but that's a very small part of our infrastructure. We also have wash machine, virtual machines or lab does or, you know, just traditional java apps of, you know, like grabbing on uh just bare metal and stuff, right? So, uh yeah, so that is one second, I think um I saw that Google cloud as a cloud provider was uh more inclined to tell people that come to Google and we'll run into search, right? So, so, so uh in all those conversations, like uh people were like, Google would always respond with like, yeah, if you come to Google, we will. So a problem for you don't worry about it.

Varun：人们很清楚，如果 Istio 只能在 Kubernetes 中运行，那么它的价值就很比较有限。因为 Kubernetes 只占基础设施中的一小部分。我吗还有 虚拟机、Lamda、运行在裸金属上的传统 JAVA 应用等等。所以我认为 Google Cloud 作为一个云服务提供商，更倾向于告诉用户，你们可以来使用我们的云服务，我们会帮你们解决这些问题的。

第二个问题是，Google 等云服务提供商更倾向于告诉用户，你们可以来使用我们的云服务，我们会帮你们解决这些问题的。这是有原因的，因为云服务提供商的收入主要来自于计算、存储和网络，而这些服务对于他们来说只是锦上添花，用来吸引用户的。所以他们并不会太关心这些问题。从经济学来说,这个行业就是这么运作的。但是用户希望在不同的云服务提供商上获得相同的体验，无论是在 AWS、Azure、GCP、Red Hat、Rancher、VMware 等等。

We were running it as a service, you know, so our service we care about to, we care about what the problem for you now. So, but and you could, and then there's a reason, right? Because dog providers make money out of uh computer storage networking and for them all these services on top are, are just, are just gravy for attracting people so they can make money then, right? So the economics work that way. Um And um this was something that customers needed uniformly across their different clouds and infrastructure, right?

So they wanted the same experience on Aws, on Azure or GCP on Red Hat on Rancher no matter what it is or VM War, right? So I, I want to have a similar experience of how my services talk to each other, how I monitor them, how I secure them, like how my developers access one service to the other. It should be a consistent way. I do it in a company. Why is it like, I have to teach like 10 different things on 10 different platforms, right?

服务之间的通信、监控、安全、开发者访问等等，用户希望在不同的云服务提供商上获得相同的体验。但是现在的情况是，用户需要在不同的云服务提供商上学习不同的东西，这是非常不方便的。

Uh So I think that there was, it was clear from there that there is a need for some third party company to have a platform which is not tied to any of the cloud providers or a pass provider like Red Hat or a branch or IBM or something, right? So I think uh that was the kind after that, it was just, you know, finding the, the luck of finding all the right people in the community, you know, finding JJ who's uh my co-founder and like aligning of the minds that, you know, those things take uh time. And uh but, you know, once that happens, uh and very rarely in your career you land on something where, like you did something in your job. It is new technology, very promising, you know, the market, you know, the people, you know, the community. So that's a lot to just start, right.

Yeah, kind of start up. So you already knew, I understand you have a lot of people. So, so everything was not. So it was uh like if not now, then when it was a, it was a very perfectly set up situation, a large state for you too. And I was in Silicon Valley.

So like, you know, this investors started to knock at the door. So they urge you to quit this. So even before we started, like after launch of to, they started coming into Google, like you wanna leave and that's an interesting story. So uh we have this amazing T three start up and I have some um promising products. Um So how are, how are the adoption of uh your salesy product in the market?

And uh do you have any sixties uh story or case study? Uh when uh you can share with us?

Yeah, I mean, it's been five years, there's lots of, lots of case studies now. Uh So people are, um lots of companies have found a lot of success in uh encryption of all the easiest and cheapest way to get encryption done. And so, so the security and encryption is the most significant case. It's the most, the most widely used use case. And the biggest thing that people ask for and the biggest value they get because it's really hard to do other like either, you know, using libraries or, you know, using other ways it's a disaster.

You know, if you have sounds or like poets, you want to uh do the certificate, you want the rotation, certificate, certificate, rotation with like dynamic containers going up and down and all that. So it's, it's, and that is becoming very, very important. The more we are doing microservices, the more we are doing distributed uh applications, it's becoming more important because uh you know, traffic is going out into different crossing the network bartering right. There is no way we can accomplish this manually. You can have some ex system used to you.

Yeah. So I think that's so many companies have found like value uh there. That's like probably the number one. Uh we uh I think re is another like just uh from our, you know, enterprise platforms. Like people have found uh this to be uh I mean, our enterprise platform is, is, is a lot more than just a deal.

It's uh so how, what's like your uh uh it just like, yeah, so we have uh our, our product portfolio is uh in like uh progression, right? So if you are just coming in for mesh Anteo, we have an te distribution with, you know, hip burs and arm bes and longer support and all that. So that's the steroid distribution business. Uh Similarly, you're involved in, we are doing the same approach in on gateway, right? So it's, it's getting there.

Uh So just today, uh yesterday we announced the, yeah, the trade enterprise on gateway, which is basically the same concept but applied to one by gateway. So you want just a front gateway then uh and you want to support and distribution of on by gateway, then you can do it. So that's one side of the business. Uh the other side is the full enterprise platform, which is like, what if you have, you know, lots of clusters, lots of teams, lots of business units like large banks, large insurance companies and uh then you want to manage all this centrally like what the vision was, right? Like if it's Aws, Azure VM, whatever it is, right, I can bring you all this infrastructure and get on board to some platform and every application team can do what they need to do.

Platform team can manage the all the fleet of OS and envoys and gateways and security gets visibility, operations can do the operations part. So it's a big effort for a company to like bring, you know, get this in and get this operationalized. So we've had, you know, multiple large financial institutions and uh defense companies and SAS companies go through this. Um And uh one of the biggest things like one of the other biggest ones I I say ingress is uh because the, what I'm saying is that uh with co a lot people are developing with microservices, people are developing microservices faster with communities, they are deploying faster. The last step in agility is, can you give it access to people faster?

Right? People could be, your team could be end user, could be partners or whatever. And that is the place where the bottle like this, right? Because oh I it's not secure to give it. How do I give it?

Because so English is, for example, I have to, the only way I expose is through opening the, you know, filing a ticket on the front F five load balancer and letting people come in and F five is not aware of any of your, you know, co community services or the new deployment, right? It doesn't know anything about that. So, so you, you make these changes, but now you have to file a ticket to the F five team which is a networking team sitting somewhere. It's like a bathroom for all this whole system. Yeah, so that starts to become a bottle link.

So I think we have seen a lot of companies introduce like a more like a better re for these container applications and then they can just expose, remove that last bottle neck because, you know, we have an aging gateway which is like aware of all the services and you can just like it's automatic. So, so the most important part is the re comes over. That's why TG that's why, yeah, that's why because we saw that with so many banks, we, we said, OK, this needs to be like done properly with the standardized gateway API in the open, which is why, you know, on my GMT G. Uh So I think those are some big ones. Um But of course, in our website, it has like so many of the, you can always go to our oversight to take a look at it our product by.

Uh so uh last question. Uh and so you are the uh co-founder of the uh the start up and you are also, you are in this amazing gene of the open source uh project. So, uh I mean, what's the most challenging part for you, I mean, this and what's the most rewarding aspect in this year for you? It's a good question. Um So challenging part is just the daily up and out of running a company because Terry is a full distributed company.

So I guess, I guess that's part of the challenge because if you were to coordinate so many people um give effort across the company. So that would take a lot of effort, I think. Uh but you know, there are benefits of uh the company, you know, somebody sitting in China, you can join and we have, we have so many other people in China as well. But uh yeah, I mean, it wasn't like it was a choice by design, right? Like to get in today's time, especially in open source world.

I think talent is everywhere. There's so much talent in China, there's so much talent in, you know, all parts of the world. So if you want to build, get the best dialect, you must be, you must be distributed, right? It has to be a distributed complex, right? That's true.

So, but there is a management overhead of that. Yeah, but for the management is uh it's like a difficulty. So, so everyone, so how do you handle this? Yeah, that's a whole other podcast. So many tips and tricks there and you know, so many that we also need to learn.

But you know, like just how you do all the daily communications active use of slack, everything being written like there's so much that happens there. I think that's one big challenge of like just but I think that also I've, I've like gotten OK with, it's just the one start up itself is dynamic. Like you go through a lot of up and down. The other part is you are a start up in cloud native which is very rapidly changing. So it's a very fast changing.

It's a very fast changing environment. So every day there is like new stuff happening here, news happening there, right? So there always something interesting and exciting. Yeah. Come, come in.

Yeah, so there's no dull day. It's so that's like that's good as well as what's challenging. Uh The rewarding part is to uh see people uh come in and do like good work and be happy with like the work they have done, right? So I we, I would like, I would like Tetra to be the place where people remember as like they did their best work of the period here for all. I enjoyed this experience.

Uh I joined like six months ago. Uh To be honest before, I'm a little bit worried because it's my first time working in motor, but everyone was so nice to me and uh I'm very happy I can contribute to my own part to this company to make it successful. Yeah. So that, that part is rewarding. Yeah.

Yeah. A part of that part is rewarding. So you know, seeing people come in and do their good work and be happy with it and grow. I think that's, that's very rewarding. OK.

Ok, Warren. Thank you for sharing all this valuable perspective. Yeah. Thank you. Thank you all.

Thank you.










@guydc Good catch!  This is intended because I want to avoid duplicating clusters. I believe different policies shouldn't have different TLS settings for the same host+port combination now? But we may need to revisit this when we support client certificates.

Welcome @ari to chim in on this.

By the way, if it's ok, may I ask access to the EG meeting recordings? I can reach out to the LF staff if it may take you too much time on it. 

The reason I ask this is that I want to get a better understanding of the previous discussion and the context so I can get more involved in the future discussions in the meetings.

ASAIK, the design goal of TVS is for the vulnerability scanning of the istio deployment, not for individual images. Do we want to extend the scope of TVS to cover individual images like `docker scout sves` does?

@V please chime in for more discussion.

Thanks @zack for the heads up. 

GRPC and 


This PR does the following:
* External Authorization implementation
* Add Indexer and Watch for Services and EndpointSlices referenced by SecurityPolicy External Authorization HTTP/GRPC services
* Clean up the code
  * Move all the Indexers to a separate file to shrink the huge `controller.go`
  * Unify the request timeout for external services(JWT, oauth2, ext auth)
  * Add SNI for UpstreamTLSSocket

The BackendObjectReference validation and Cluster creation could be optimized and combined into these of the xRoutes. 
I prefer to improve it in a follow-up PR because this PR is already big enough.
