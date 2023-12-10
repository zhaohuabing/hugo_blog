---
layout:     post

title:      "KubeCon 芝加哥现场报道 - Envoy Gateway Maintainer Alice Wasko"
subtitle:   ""
description: "Envoy Gateway 项目 Maintainer Alice Wasko 谈 Envoy Gateway 项目的起源与未来"
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
      link: "https://www.bilibili.com/video/BV1PQ4y1b74N/"
    - text: "YouTube"
      link: "https://www.youtube.com/watch?v=vfLVVE6b9q0"
showtoc: false
---

## Videos

Bilibili
{{< bilibili BV1PQ4y1b74N >}}

YouTube
{{< youtube vfLVVE6b9q0 >}}

采访内容(待整理):

Huabing: I will introduce this interview first in Chinese, because the audience are from China. Envoy Gateway 社区的朋友大家好，我们今天有幸邀请到了 Envoy Gateway 的维护者，来自 Emissary 的 Alice。 Alice 从 Envoy Gateway 创建之初就参与了这个项目，今天很有幸能够在 KubeCon 现场对她进行采访。下面我将用英文对 Alice 进行采访。

Alice, could you please briefly introduce yourself? Where are you from？What are you doing? What got you involved into the Envoy Gateway.

Alice: Thanks. Hi, I'm Alice, I am from Oregon, the United States. So right now I'm mostly working on various ingress projects such as Emissary and Envoy Gateway. What really first got me interested in the Envoy Gateway project was a colleague of mine who works on Emissary, which is another open source Ingress project was getting involved with the Envoy Gateway.

He had come together with a few other individuals from other projects similar to Emissary. And we decided like there's a lot of people that are working on ingress projects. So we decided to get all of that talents together in one room and focus all of our efforts on a single project that everybody could benefit from, and hopefully take some of the learnings of these projects that have been around for a while, and then start create a new project and make it really solid from the ground after taking all of those learnings and lessons from those other projects. 

Huabing: Yeah. That makes a lot of sense because you don't want to  work on the same thing , you know, in multiple countries, multiple organizations.

So, Envoy Gateway is a new open source project. It's quite new. When you started it?

Alice: I think we started just a little bit over a year ago, over a year, very young. So why, why do you think it excels other similar projects, why it's so significant, so different.

Alice: Just the one thing really, there's multiple things. But I think right now, what's most interesting to me about Envoy Gateway is that like I said, we've got a lot of people who worked on the other projects that are coming together and spend their focus on Envoy Gateway.

So right now, I think Envoy Gateway is really the only open source uh free to use in projects that is focused on solving the problem. I think emissary the projects I work on and, and some of the other ones mostly seem to just be kind of stagnating and they're not really moving forward anymore. So a lot of that new innovation seems to be happening right now. And even though it's less mature than the other ones, we've got a lot of that same talent coming forward. So we've been able to push it forward to the project really quickly and achieve a ton in the last year.

So we're very quickly approaching of the project and we hope to continue to evolve the projects task these other more legacy. So you, you want more, you mean there are some feature you want but you can get from other projects. Yeah. So if you were to try on right now, there are tons of features that it has right now that these other projects might not just off the top of my head with UDP support is like basically, yeah, that's a big one. But there might be other features right now because those other projects have the gate.

But I really, we're trying to make sure that for on the gateway, you've been spending like a lot of the previous months focusing on the performance and the sustainability of the liability of it so that you can feel really confident that it's gonna hate what you're expecting. And so reaching that feature varity with these other projects is what's gonna come next. And that should actually be pretty quick because like I said, pretty much all the people who work on those projects can involve one gateway. So just making sure that they do all the same things. Yeah, I think that's a good point and I, I want, I want it.

Huabing: I gave a talk in September in KubeCon Shanghai, talking about why Envoy Gateway is the right choice for cloud-native applications. the same, the two different designs uh itself is made for when people create the guy who Boer play more. Um It has this man so it's great for all application because it can be like it can be configured dynamicly from the control plane through XDS. So this kind of thing, I think only Envoy can do So if you look into like Nginx which was like was created 15 years ago, um It's perfect to serve as edge proxy for like applications right now. There are a lot of things going on inside your applications, your pods come and go The configuration changes very, very quickly.

So you can't do that with Nginx I think it's also pretty important, right? I think another big benefit on the Envoy Gateway right now is we've spent a lot of time training communities and people that are interested in it all over. And people who are interested in me, the big weakness that a lot of these other projects have is they're mostly maintained by a single company. And so those other projects like contour and MS A can really only advance as far as that company that maintains it is interested in supporting it whereas Envoy Gateway is mostly built from community power. So we've got a whole bunch of people that are working together and they're trying to make one single project that it works for everyone's needs, instead of just working for the needs of whatever, you know, case projects are built in companies.

Yeah. If you choose an open source project, you always want to uh get support from community. So if only one big company behind it then you'll be worried. So what what if the company decide to let it go? But Envoy Gateway uh has multiple companies behind it, so you don't need to worry about it.

So um I know 0.6 version just come on. Come on. Are there any exciting feature in that version? So like I was just mentioning, we know that there are some features, we still need the support that are really for people to be able to support every new space that is really in demand.

And so Envoy Gateway mostly configured right now using the gateway API and that gets us a pretty far way as we are able to do stuff like UDP, TCP ,TLS, all the good stuff like that. But for those extra features that are mostly Envoy Gateway specific and all the interesting little dials and nos we've introduced these three new resources that are native to the gateway project, we call them the back end traffic policy, the client traffic policy and a security policy. And so these are kind of meant to just three new custom resources where you can add any of these extra features that we don't yet have and we designed them in a way where many different people can be working on them at the same time. And so if there's a future right now that Envoy Gateway doesn't have that we want to support these two sorts of noises and it's really easy to add for super quickly. So it's taken us while to get here.

But now we're at a really solid place to just add in those last remaining features. You know, as more people check out the project, they can let us know what their needs are and we can support this. Yeah, this is what I um I, I joined the EnvoyCon uh yesterday I noticed that there're two or three sessions about Envoy Gateway. So that's a lot. Um OK.

Um How do you envision the future of Envoy Gateway? And what are your long term goals for the project? I think right now, the future and vision for envoy gateways, hopefully just trying to get it in the hands of as many people as possible. I feel like projects are the most successful when they focus first on what the users are. So that's really where I'd like to go is I don't think developers always necessarily know exactly what's best for the project, but when you fit it in the house, people let them try it out and then they say, hey, I really like this about your project, but I don't like this or I need this and the project doesn't have it.

Those are the areas where we can kind of gather all that feedback on and reflect on it and say, OK, there's a big need for this other feature we don't support yet or this, you know, maybe a change to some of the core systems that would make it even better for other people to use so that you can configure it or whatever kind of use case. I just want it to be like a really powerful but generic API where use it exactly as it is or even you have systems built inside of it that you can allow you to even further and build your own stuff on top of it. So I wanna get away the power for support and uh many many users started to experiment it and start to use it. But when do you expect it will be like production ready. When , I think we're really close to being ready.

One of the talks just here at threat model security review and overall it was very positive, it's a very secure project by default in a couple of areas that we identify we've already to address. So from the security and stability perspective, I feel like we're already in a really good spot. I think the steps we have are mostly just about supporting all the possible use chances. I'd say it's probably ready now for some people to run information and it already has all the features that you need. If it doesn't have all the features that you need, then I'd say just let us know what, what, what is a blocker for you if you want to use on the I, I just need like this one extra feature then let us know and we'd love to add support for it super quickly.

But I think that's really the last a couple more features than a lot of people. And then it sort of goes to me. Yeah, I think the, the case that if you are the ruler of the work, if you have any issue, if you have any requirements, just raise an issue in the Github repo, let the mantainers know that so they can work on that. Thank you, Alice.
