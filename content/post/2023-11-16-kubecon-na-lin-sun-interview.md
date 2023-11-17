---
layout:     post

title:      "KubeCon 芝加哥现场报道 - Istio 技术指导委员会成员 Lin Sun 分享 Istio 项目历史与未来展望"
subtitle:   ""
description: "Istio 技术指导委员会成员, 来自 Solo.io 的 Lin Sun 和我们分享 Isito 项目历史与未来展望"
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
      link: "https://www.bilibili.com/video/BV1Zj411E7wH/"
    - text: "YouTube"
      link: "https://www.youtube.com/watch?v=O-bHqDpStoE"
showtoc: false
---

## Videos

Bilibili
{{< bilibili BV1Zj411E7wH >}}

YouTube
{{< youtube O-bHqDpStoE >}}

采访内容(待整理):

Um OK. Let's just switch the image. OK. Um I think you already give us a little bit of background and interaction on yourself. So I, I think it's fair to say you are one of the founder, etcetera.

So uh maybe tell us um what give you involved in Mr Smith first. Um What inspired you to join and create this community? Yeah. So for Ecoeco was created by A, I was part of the team. I was part of the CTO office in the IBM cloud division.

We actively talking to Google about uh our Omega project which uh does uh traffic shifting in Canary based uh traffic uh you know, resiliency uh based on internet stuff. And then we were trying to figure out, you know, finding the right uh momentum around that project. And we started talking to Google. So, uh my boss, uh back then, Jason started conversation with Google and uh we kind of uh you know, resonate together like Google has uh policy enforcement uh around uh and they are building some project related to policy enforcement, not so much traffic. And IBM Blackman has Omega made that uh policy enforcement basically related to uh traffic management.

So that's when it still us uh to, you know, resonate with IBM and Google and we started uh on history. So before you, you guys start this project, what kind of tool of are you them to managing traffic to solve the problem? You have new uh tool? Yeah. So we have this uh it's an open source project by IBM.

It's called a mega. It's a, it's, it's a collaboration project between IBM research and also the CTO of uh which led by Jason. So we kind of incubate this particular project. We open source it and does traffic management uh through a psych approach using, oh, so you, you already have a control plan. But yeah, we had a control plan we had uh but it's only focused on traffic but for the data plan, you, you were using index, OK.

I I saw the index um I think it was created like uh 15 years ago. So it's a little bit uh uh I mean, the architecture. Uh a little bit old. So it's not right for college instructor. Right.

Yeah, that's a good point. But back then seven years is actually so it's harder to uh tell which one is going to be the winner. So it's not, it's not an easy choice. As today you just pick those people. Yeah.

So, but when you go open source the exercise, the first choice. Uh yeah, the first choice uh we decided, uh I think Google was very influential in that decision is they started to talk to the, to the awe community. They think um we is like the future of the fy it's cognitive and uh they just think it's a better and they were able to convince our team. Um So, yeah, when we first launched it still, it was, I think it's very good to say. OK.

Um um Next question. Um So, um it still, it's about open source. It still has a diverse and active community. So, uh when we go to community, how about how has the community's environment impacted the project growth and success? Yeah.

So I think it still has been growing. And when we first started at Co West Google, there are um meetings where the only people attending was just I, right. So that's 2017 fast forward today, especially now that it's still this part of CNCF. We have seen contributions uh people from Microsoft, uh you know, have dedicated resources, join us uh T Matrix is leading the Microsoft team and he's doing a fantastic job. We've seen uh AWS popping into our MBM meeting often and uh we've seen use the community like, uh I think Salesforce was one of the uh Erickson.

We've seen, you know, tremendous growth, not only from the vendor community, but also from the community. So really, really exciting to see, I think uh having the proper home being CNCF really made a difference. Yeah. And actually we have like four or five wechat group because you, you have number uh the number of member in our wechat group, we have like 500 people, but we have like uh I think three or four groups of the total number would be like over 2000 members in China. Yeah.

So it's very good, very good project for. Yeah, I think it might be more popular. You, you know, um the interesting part when I compare the UK C of how is the uh such have been used in the United States or the Europe uh with how it is used in China. Uh it's very different. I think the most of the major case in the United States with about security, right?

Definitely a lot of people come to Israel looking at secure their communication with the right. Uh so and data security, they are looking at confidential confidentiality, right? They the identity right? Be able to apply policy to the identity, right? They are looking at encryption, right?

Um So these are the common requirements. Uh And we've seen user who kind of do their own diy, this is what we call. Yeah. Do it yourself way where they kind of manage the key and search and figure out how to rotate and in reality they never rotate their key and, and then they kind of try to upgrade their connection using the TRC in the manual way. But uh you know, it it's painful.

Yeah. Yeah. So have you on a plan to automatically uh like replicating this kind of certification is very, very useful for us? Yeah. So how about the uh some more advanced new the uh case like, yeah, I think that's also important, right?

At the end of the day, you're not gonna have one application. So the moment we need to make a change, able to test your change, our downtime, the best way is do launch can upgrade and what is issue provides is you don't have to make any code change to your application. And then you could just rely on to be able to shift that traffic and then progress uh the traffic shift uh as you're comfortable and go through the. So you think the new seven this case are also very important for the user. I think it might be more important actually for common service measures layer, right?

Because uh usually tr it's important, but it's kind of like a statement right. It's basic people are looking at to justify the complexity of the service and the cost they are looking to do something a little bit more so mutual. Uh just a stop for more advance after getting us to like that. OK. Um So, um I think Ambi image uh my law is a very big thing going on in the community and I heard a lot of uh conversation talks around Ambi.

So when do you think I will really go into production? I guess I would say that sometime next year, we had hoped to be sometime this year. But unfortunately, there's uh quite a few challenges we're trying to sort out. So if I take a guess, uh I, I would be really happy if it's the first or second for next, but I wouldn't be surprised if push beyond that. Hopefully not to Yeah, so quickly uh share us.

Uh What kind of, I mean, um major challenge. Yeah. So the first challenge we are facing right now is IA has a tons of features. So uh we are constantly asking ourselves is this feature we need to make uh for the first uh version of the issue, what we call and the production. So, uh the second challenge that we have is right now, the CN I with I, you have a pretty nice integration with us in my layer, you suppose, multiple uh with ambient, we've got to implementation of that CCY components.

For uh IP P or traffic redirect. We also did the EDPF based traffic redirect, but none of the implementation was able to like own a network policy in con in conjunction with is C OS uh policy so that we have to sort out the line expired. Iii I watched some book about this, like they talk from Google Guide. Um and they say that OK, they want to do this thing. I just integrated with everything I with the only thing I and maybe provide a manageable uh solution for that.

So do you think that's the right, the right way to solve this problem? You know, so I've seen solutions that talk about um be able to upgrade the CMIHF with uh with the issue of Z tunnel, I think that could be potentially uh the right solution. But I'm also wondering, you are not only just run one cli I feel like the top with a comical solution, it could be very much focused on what they for their cloud. So I'm a little bit cautious on the users out there that maybe running C on R and they're not using a managed cloud environment because we know a lot of users are not uh are out there. And I'm also cautious uh like people uh AWS cloud, like they're not a big contributor to AC R, however, they are the biggest C provider.

They are, I don't know what's the, some of the chi chi China cloud provider. I know Alibaba is like also this uh because um so I'm not sure what CN I is using. So not everybody is uh saying one particular CN I is doin it right? Like the top provider could have their own cni I think all, all the right. In that case, we require every single car provider CN I to make changes.

I'm not sure if that's the right approach. Yeah. And also it takes time to upgrade to that particular CN I level. I don't know how confident people feels about changing to the latest. Yeah.

Well, they might be more comfortable with moving up to NBA without changing to the CN. I, so um I'm an opportunist. I think I have a bunch of, I'm, I'm looking forward for your answer about this question. Actually, I think it's very critical uh make an image to point to a production. Let's see.

Oh Father, I have like a personal question for you. Um So I know you uh you are worried multiple hearts like you are the fewest member of, of uh you wrote multiple books as in the last few years. Yeah, two books. I wish I could be. And uh I looking for uh profile, you like have more than 200 right?

That's great. That's great. So um looks like you are very, very um efficiency. Um I mean, doing your work, you have some like uh um secret to share with us how to, how to be more that you, well, like I said, more productive, I'm always looking at people who is way more productive. And I ask myself, why am I not so productive?

You are always so good because I'm looking at people like John Howard and I'm looking at people like Christian poster wrote five books. So, you know, it's like you can never be them. But I think my secret is uh try to, you know, plan yourself. It's like I always have in mind what I'm going to eat for the next before work. You know, I kind of planned out.

So I do the same thing for work for career. You know, you always try to be a little bit more purposeful, you try to. So that um the rest, yeah, that, that's a very simple but very powerful strategy. I think I should adopt it. Yeah, it's harder to stay on the course.

But once you find out that you have a pretty clear goal that you may find out that you actually execute a lot. OK. Thank you. Thank you very much for your Yeah, I really appreciate all the love from the Easter community in China on the East project. So, thank you so much.

OK. Well, I, I would just cover this one. OK. Thank you. Are you all right.











