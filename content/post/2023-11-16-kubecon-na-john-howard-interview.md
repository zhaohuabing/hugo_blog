---
layout:     post

title:      "KubeCon 芝加哥现场报道 - Istio 社区核心维护者 John Howard 分享他高效的秘诀"
subtitle:   ""
description: "Istio 社区核心维护者, 来自 Google 的 John Howard 分享他高效的秘诀"
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
      link: "https://www.youtube.com/watch?v=3sTj5lmoP6c"
showtoc: false
---

## Videos

Bilibili
{{< bilibili BV1j94y1H7ZX >}}

YouTube
{{< youtube 3sTj5lmoP6c >}}

采访内容(待整理):

Huabing: OK, let's welcome our superstar from Istio community. John Howard, Is my pronunciation correct?

John: Yeah, John Howard, I'm John. I'm a software engineer at Google. I've been involved with the Istio community for about the last five years now, kind of all sorts of different roles. I started out mostly working in the networking area on the control plane and more recently joined the technical oversight committee and kind of getting a more broader reach around the project.

Huabing: So John, do you wanna say hi to the Chinese Istio community?

John: Yes, I'm excited to be talking with you all. Hello everyone. And we're so glad that the Istio community is uh you know, so broad and across different countries and everything. So it's great to have this opportunity to speak.

Huabing: Maybe we can check Madarim "你好"

John: 你好

Huabing: Perfect. Perfect. OK. Let's go directly to the question. I think you already answered the first one. So maybe could you tell us how did you get involved in Istio project, I mean, how do you started?

John: When I first joined Istio you know, this was back when Istio had just launched the 1.0 release and back then, I just joined Google. Um and, you know, I was told go work on Istio. Um So, you know, I tried out the docs, went through the getting started, the book info and back then Istio was a lot less mature than it is now, right? We had probably, I think there was maybe 2000 open issues on github. Um, and a lot of critical bugs.

I actually, when I first tried Istio, I tried the book info demo and it didn't work. I assumed it was me, you know, it was my first week on the job. I done something wrong. I went back two months later. I tried it again and it still wasn't working.

Right. It was like, well, ok, now it's not me, maybe something's wrong and it turns out that, you know, even the simple book info wasn't working that way. So for me and is o back then I was just going every day finding a new bug of something trying to understand how it worked, how to fix it. Uh, not every day necessarily, but, you know, as much as possible and just kind of going through all these bugs and fixing them and over time, you know, they keep touching slightly in different areas and start getting experience kind of across the code base. Um, so that was kind of really how I picked up my contributions.

Um, you know, fast forward to today. There is hopefully a lot less low hanging fruit bugs like that back then. Um So it's a bit of a little harder to go through what I did back then. Uh But there's still a lot of areas that uh yeah, I need to work and need a contribution. Yeah, that's uh amazing story.

You know, you start to just pick up some small task at the beginning by law. You are, I think you are the um comment turner of history, right? And you are behind a lot of uh important effort like of me. So it still has to involve significant since in deception. Uh What do you consider the most s significant advancement or changes in these skills development?

And how do you think is benefiting order especially uh in the concept of other services and religious? Yeah, I think I I'll give two answers if that's all right, there's one that's already happened and one that's ongoing. So the the first one wasn't necessarily one event, but uh the formulation of many years of work is that really making or sorry, production, ready and usable for large enterprises that they can depend on, you know, to use without any stability risk at large scale, etc. So like I said, when I first joined was not really there, it was, it was very unstable, it didn't scale very well. But over, you know, there was no one big moment where we fixed all those, but with many years of work for myself and many, many others in the community over time, we made used to what it is today where it's a very stable, reliable, uh you know, product that you can use in community environment.

And we see tons and tons of adoption and success with enterprises deploying ego and using it for their microservices for for various different use cases. Some people use it for security, some people use it for observable, others use it for more traffic control or some use all, you know, all these different aspects. Um So to me that's been really the key thing is taking it from kind of this really cool, awesome new idea to something that's stable and dependable. The other new thing that I'm looking forward to uh for the future is the ambient mes mode, which is kind of the next step in the East Jo's journey. You know, I talked about East becoming something that is kind of adoptable in a real production environment.

That is true and you can use it and many do and you should use it. Uh but it's also somewhat high cost to a dog, right? It's not so easy to just say uh I clicked the button and now I have Easter where I'm getting all these benefits. So with ambient mesh, we really want to take the next step in the evolution and keep that same dependability and stability that is has today, but make it easier to adopt the lower the cost, lower the complexities, increase the compatibility so that we can see is more broadly adopted without organizations taking as much time to adopt it. Yeah, I think, uh, is a significant move for Israel project because to make either a per, to test, uh, it's much more comfortable, uh in the study, uh, pro model.

Um, what do you think, uh, when, when do you think it's the right time for the user to try out uh MS or put end this such match in production? Uh Do you think there are any um obstacle? Uh we can, yeah, I think so. The best time to try it out in a non production environment is today, right? It's uh currently alpha is what the stability level is.

And so it's, it's, it's use, it works enough that you can go try it out in the test environment, try it out with some applications and give us feedback, which is super important because, you know, we, we've been working on ambient with the across the community for, for almost a couple of years now and had all of these sorts of ideas of what users need and what they don't need. But until we actually have users really try this out in real world environments, we don't get the the real world feedback. So the best thing you can do if you're interested is to go try it out today. And give us feedback. Um We're running a user survey right now that you can find the link for or you can just give us a slack to get uh anything to give us some feedback on India.

It's really great. It's currently, like I said, the alpha. So it's not really rated for production quite yet. We have a few steps in the way to get to beta and A G A quality. It's mostly around, not necessarily the features and functionality, but just making sure that it's stable and secure and is not, you know, types of issues like a new pod comes up, maybe we apply the security policies after a few seconds, right?

It won't impact a demo or a prototype, but we don't want that in a production environment. So I think it's actually fairly stable, but Easter has a really high bar of quality now because it's so well adopted across the industry. So if this was five years ago, probably East to ambient would be considered 1.0 at the time. But remember 1.0

had a booking phone not working. So it's, it's kind of the bar has risen as east to as maturity and so ambient mesh, you know, has to meet that same high bar that used to set. So um if we look into the HTOCRD or a bunch of Cr Ds, we allow a lot of H I uh we always, we always support all the H I uh in the uh model and, or we just choose, uh I would say for the most part, yes, not all of them specifically. Like there is some resource like there is a sidecar resource that's very specific to the side model, but things like authorization policy WSM plug in telemetry, these are all things that we intend to a new support in the new API. Um Additionally, there is the new development in the gateway API, which just went to G in the co community, which kind of builds on what we did in with the virtual service in gateway, but moves us into the C core A PS with HDP route, TCP, route and their own what they call gateway API.

So we're adopting that as well in especially ambient mesh, but we will also support the virtual service in gateway for backwards compatibility. So you mean in the future, we will finally move to the data website and virtual service will be, I wouldn't say it would be deprecated because you know, we have hundreds of thousands of organizations using it. There's probably a million virtual services out there in the world. And so, you know, we don't need those to migrate, you can keep using them. But I think it will go if you go to a documentation in the near future, it will probably recommend using the gateway P I for new use cases.

That's true. OK. Um So uh I'm gonna use about ask about some question. So if we are lost, it is it is secret, you can answer it. OK.

So um um but Google use uh we still more inside their own product or just so GEO was in many ways inspired by the internal Google production environment, especially in the early days, you know, Google was one of the founders of GEO, we really in East and similarly, in Tis to some extent, took the learnings that we had from running Google production and wanted to bring them to the broader, you know, open source community. So it's not the same components, but they're kind of a similar ideas with the sidecar architecture service mesh. So it's just some exactly. So internal Google production it's not using, but it's using similar concepts on Google cloud. We do offer a service mesh, of course for our users and some teams like Google do run on Google cloud so they could use but the internal environment is a bit more your way was.

Yeah, thank you. So um next question, what advice do you have for developer operator and localization? Looking for ad t for the microservice structure? Are there any best qualities or resources you? Yeah, I would say one of the one of the challenges people run into is they say is complicated, right?

And the thing is has a lot of stuff, right? If you go look at the website, it's there's a long list of pages all these features, all these different areas, right. Security, observable traffic management and within that there's like huge list of stuff. Right. Sure.

So the thing that I think gets some people is they look at all this and think, man, how am I going to understand all this and how am I going to use all this stuff in production or they even worse, they try to do it all at once and they get stuck because they're trying to do too much at once. I recommend that people just find the one thing they care most about and just get that working first. Let it sit in production for three months, six months, maybe a year and then start exploring. Oh, maybe I can add, you know, better tracing integration to get some more visibility in my services and you know, start working on what that or maybe I want to start doing some more sophisticated area rollouts or something, but keep it small, keep it simple and kind of focus on what you really need. Uh Just because E two has the functionality doesn't mean you have to use it, right?

Um So that's, that's the biggest thing I see people get, get hung up on um in terms of resources and stuff to learn, there's lots of stuff out there. I'm probably not the best source of resources. I mean, there's of course, the Easter documentation, I know there's all sorts of videos, training platforms and books, there's a new eto certified administrator, I believe it's called certification, which I believe has a training program as well. So there's all sorts of avenues depending on how you like to learn. Um, yeah, in general, keep it small and then you can just gradually build up over time.

Uh It's the same with contributing really to, you know, contributors come in like these, go, what do I do? And it's just, well, don't think about all of these, right? Find the one thing you need to fix what you want to work on and, and learn that and then over time you'll start working on more and more things in different areas and over time to build up knowledge, right? I've been working on east to it for five years. Like I said, it was probably two years in or maybe even three years in.

I barely knew what M two S was, which is a core part of these two, of course. And, you know, I had been working on it full time for, for two years and eventually I came across the bug that needed some work in M two S. So I started kind of expanding the scope and learning more about it. I think, um you know, it's not realistic to expect to understand all of these two and everything you can do in a short time. It, it's good to start small and yeah, I think it's a great strategy to start small and pick whatever, like a small issue documentation I can take and uh begin to understand the, we still testing you.

I need to find any issue or, but you can fix, you just do it, you know that. So the final question uh is a little bit of personal. OK. Um So um I think you, you are the like superstar in the community. Uh You are behind a lot of uh important efforts.

Uh uh I mean, like MBI of MA like the uh R version of the T and we also work a lot of work on and we will um at uh good way. I and also create this. So it only have 24 hours, right? So I do sleep. II, I, I'm gonna ask you what, what's the secret to make you so productive?

Um Yeah, I don't know, I have a, a secret really. I mean, the, the one thing that helps quite a bit that is um quite hard to get is that, you know, I have someone on Google that, that pays me to work eight hours a day, five days a week for, for the past five years. Um So that helps quite a bit, you know, over time, you know, when I first joined, I was, I was not productive at all. I had no idea what I was doing. Um But I had so much time to spend and just gradually grow my knowledge, like I said, um that, at this point I've been working, you know, every, almost, you know, every work day for five years now, that's over 1,000,000 days of work at Ego.

And now I know, you know, that like the back of my hand and I'm very familiar with it, but it's kind of a slow process. Um, so I don't know, no secrets. Really. Just a lot of work over a lot of time and kind of adds up, I should say maybe for assistance for five years. And I've been fortunate enough to be able to focus on that, you know, a lot of other people, even if they have worked in east to at some point and were paid to do so, maybe they also get pulled into some internal stuff or on to some other projects and they kind of have half time, which is fine, but it can be tricky to, you know, do all that context switching and whatnot.

I've been really fortunate to be able to focus on the same thing for quite a while which I don't think many other people have ended up taking that opportunity. So I'm pretty thankful of, you know what I've been able to do. Ok. Thank you for sharing all this. Yeah, it's been been great talking with you.

Ok, bye bye.










