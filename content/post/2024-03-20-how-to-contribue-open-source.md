---
layout:     post

title:      "如何为开源项目提交 PR ？"
subtitle:   ""
description: "。"
author: "赵化冰"
date: 2024-03-20
image: "https://gateway.envoyproxy.io/featured-background_hub722101dbe1dbe5596133cb6c8ada6d9_400690_1920x1080_fill_q75_catmullrom_top.jpg"
published: false
tags:
categories:
    - Tech
    - Open Source
showtoc: true
---

提交 PR 是参与开源项目的主要方式。不管是修复一个 bug，添加一个新功能，还是改进文档，我们都需要通过提交 PR 的方式将我们的代码合入到项目的主分支中。然而，对于刚刚开始参与开源项目的开发者来说，如何提交一个好的 PR 并不是一件容易的事情。在这篇文章中，我将分享一些我在参与开源项目中总结的经验，希望能够帮助到更多的开发者。

## PR 之前的准备工作

对于一个刚刚参与某个开源项目的开发者来说，如果在前期没有进行任何交流的情况下直接提交 PR，该 RP 一般会很难通过。可能出于礼貌的原因，项目维护者并不会直接拒绝你的 PR，但该 PR 可能会被长期挂起，缺少关注和反馈。一方面这是因为你在提交 PR 时并不了解项目的代码规范，项目的 PR 流程，以及该 PR 涉及到代码项目模块的一些设计原则等，导致 PR 可能不符合项目的要求。其次，项目的维护者也对你 PR 提交的背景并不了解，难以对 PR 进行评审。

如果是第一次在该项目提交 PR，我们需要了解项目的代码规范，项目的 PR 流程，项目的代码风格等。这些信息一般都可以在项目的 README 中找到。其次，我们需要了解项目的架构，项目的功能，项目的设计理念等。这些信息一般可以在项目的文档中找到。其次，对于 PR 涉及到的修改，建议先通过提交 Issue 的方式进行说明。一般 Issue 分为两种，一种是 bug，一种是 feature。对于 bug，我们需要说明 bug 的现象，复现步骤，以及期望的行为。对于 feature，我们需要说明 feature 的目的，设计思路，以及可能的实现方式。通过提交 Issue 的方式，可以让项目维护者提前了解你的 PR 提交的背景。我们可以在 Issue 中对各种方案进行讨论，得到项目维护者的反馈，在社区中达成初步一致后再提交 PR。

## 如何让我的 PR 更容易被合入？

### 为 PR 添加清晰的描述

PR 的描述非常重要，因为这是项目维护者在处理 PR 时最先查看的内容。一个好的描述可以帮助评审者快速了解该 PR 的背景，理解 PR 中改动的代码，从而让提交者尽快从评审者处得到进反馈，加快 PR 合入项目代码的时间。而一个不好的描述可能会增加评审者理解 PR 的时间，甚至会使得 PR 较长时间无法得到关注。

对于一个开源项目来说，可能有多达几十个 PR 在等待评审，而评审者的时间是有限的，描述清晰的 PR 常常会优先得到处理。以我为例，我一般会在一天中抽出约一小时的时间来评审 PR，在这个时间内，我能够评审的 PR 数量是有限的。因此我会优先处理那些描述清晰的 PR。

那什么样的 PR 描述是好的，什么样的 PR 描述是不好的呢？一个好的 PR 描述中会说明这个 PR 提交的目的，以及为了这个目的做了那些代码修改，并且会提供该 PR 相关的 Issue 的链接。如果该 PR 涉及到多个模块的修改，最好在 PR 描述中简明扼要地说明这些模块的修改。

一个不好的描述可能是这样的：

This PR fix a bug in HTTP Listeners.

该描述过于简单，几乎没有为评审者提供任何可用的信息。

在一个好的描述中，我们应该说明该 PR 处理的是什么 bug，以及如何修复的。例如：

This PR fix the bug xxxx（加上链接）in the HTTP Listeners.
The bug is caused by missing HTTP filters in the filter chain of the HCM(HttpConnectionManager) in the translated xDS when `MergeGateway` option is enabled. To fix it, the missing filters have been patched to the existing HCM.

开源项目一般都会提供一个 PR 描述模版，模版会列出需要填写的内容。例如 Envoy Gateway 的 PR 模版如下：

```
**What type of PR is this?**
<!--
Your PR title should be descriptive, and generally start with type that contains a subsystem name with `()` if necessary 
and summary followed by a colon. format `chore/docs/feat/fix/refactor/style/test: summary`.
Examples:
* "docs: fix grammar error"
* "feat(translator): add new feature"
* "fix: fix xx bug"
* "chore: change ci & build tools etc"
-->

**What this PR does / why we need it**:

**Which issue(s) this PR fixes**:
<!--
*Automatically closes linked issue when PR is merged.
Usage: `Fixes #<issue number>`, or `Fixes (paste link of issue)`.
-->
Fixes #
````

可以看到 Envoy Gateway 的 PR 描述模版中已经包含了一个 PR 描述中需要的所有内容，包括 PR 的类型，PR 的修改内容/目的，以及该 PR 关联的 Issue。只要我们在提交 PR 时按照该模版的要求进行填写，就可以为 PR 提供一个清晰的描述。

### 避免 "巨大" 的 PR

PR 的理想长度是多少？这个并没有一个固定的答案，但是总的来说，一个 PR 中包含的内容越多，最终合入主分支的时间也需要得越长。

我曾经看到过的极端情况是包含了一百多个文件的 PR。首先，此类“巨大”的 PR 阅读难度很大，评审者需要在大量的代码差异中进行跳转，分析 PR 作者修改每段代码的意图，以及修改是否合理。在项目 PR 较多的情况下，此类 PR 可能会较长时间无法得到评审者的关注。其次，一个涉及改动很多的 PR 中可能引入的问题也较多，评审者在 Review 时可能提出的问题也很多。长时间的 Review 会增加 PR 合入主分支的难度，因为大量的代码修改和长时间的等待大大增加了合入代码冲突的可能性。

一般建议不要提交过大的 PR，而是将此类改动拆分为多个较小的 PR。可以有两种拆分方式：

按照功能拆分：一个 PR 中只包含一个功能的修改。在开发过程中，我们可能会在实现 PR 的时候顺便对代码进行重构，或者顺带修复一个 bug。如果这些重构或者 bug 修复和当前 PR 的功能修改无关，建议将其拆分为另一个 PR。因为这样可以让评审者更容易将代码的修改和 PR 的目的联系起来，从而更快地 Review 代码。当然，这条并不是绝对的，如果这些重构或者 bug 修复和当前 PR 的功能修改关联紧密，或者改动非常小（例如只是修改了一个拼写错误），建议还是放在一个 PR 中。

按照模块拆分：有时候，PR 中修复一个问题或者一个功能涉及到多个模块，则可以按照模块提交修复的PR。以 Envoy Gateway 举例，一个新的功能可能涉及到 API，Gateway API translator，xds translator，e2e test, user docs 等部分的修改。因此最多可以拆分为 5 个 PR。当然 PR 也不是拆分得越细越好，拆分得过细反而会让评审时不容易看到修改的全貌。对于一些较小的功能，拆分为 API 和 实现 两个 PR 就可以了。我的建议时 API 一定要拆分的，因为在 API 达成一致前去实现该功能很可能导致实现代码在评审后被推翻返工。

## 开源社区的基本礼仪

文字的礼貌和尊重是开源社区的基本礼仪。在开源社区的工作中，交流各方百分之九十九的情况下都是通过 github，slack，邮件等间接的沟通方式进行的。在这种情况下，荧幕后的另一方无法像面对面交流那样通过你的面部表情、说话的语气、肢体动作等得知你的情感，因此你留下的文字就变得特别的重要。在我们的文字表达中，尽量使用礼貌，积极的语气，尊重他人的劳动成果，尊重他人的意见，感谢他人的帮助以及为此付出的时间。

我自己的体会是，在开源社区里面，越是厉害的大牛，对于其他人越是礼貌。和他们合作，有一种如沐春风的感觉。

由于开源社区是一个国际社区，里面的人来自世界各地，英语是开源社区大部分情况下是以英文作为主要工作语言的，作为非英语母语者，我们对于英语的语气并不敏感。一些我们觉得没有问题的英语表达可能会稍显生硬，甚至有时候会让人感觉不礼貌。我总结了几个相关的小技巧：

* 用积极的语气表达自己的意见，例如：
-  There's a memory leaking problem in the current implemtation. -> We can improve memory consumption by ...


* 在表达自己的意见时，使用 might, could, may 等词语，表示自己并不假设自己的意见是绝对正确的，例如：
- I think this is wrong. -> I think this might be wrong.
- This is not a good idea. -> This might not be a good idea.

* 在提出改进意见前，先肯定他人为此付出的工作。这一点尤为重要，因为人性中有一种天生的抵触情绪，当我们的工作被别人指出问题时，我们自然会有一种抵触情绪，对此感到不快。因此在提出改进意见前，先肯定他人的工作，可以有效地缓解这种抵触情绪，例如：
- I have some suggestion. -> I think this is a good idea, just have a few suggestions on ...
- This is wrong. -> This is a good start, but I think we can improve it by ...

* 多使用疑问句，尽量避免使用命令句，例如：
- Please change the code. -> Could you please change the code?
- You should do this. -> Could you consider doing this?

上面只是一些非常简单的例子。作为一个非英语母语者，我也常常遇到对自己的表达不确定的时候。我一般会使用 ChatGPT 或者 Gemini 对自己的表达进行改进。一个简单的 Promot “Please rewrite my sentence and make it polite” 就可以了。

一个很好的示例： https://github.com/kubernetes-sigs/gateway-api/pull/2283

Hey @zhaohuabing, thanks for working on this! If I'm understanding correctly, it looks like you're trying to take on a couple of separate issues:

Adding SectionName to PolicyTargetReference (Update TargetREf in Policy GEP #2147)
Adding Name to Route Rules (GEP: Add Name to HTTPRouteRule and HTTPRouteMatch #995)
I think we mostly have consensus on 1, but we're waiting for #2128 to merge before moving forward. On 2, I don't think we quite have enough consensus to move forward yet. Maybe once #2128 merges you can check in with @arkodg to see if he needs any help with the implementation of #2147.

It may also be helpful to take a look at our documentation for the GEP process. All API changes have to go through that process so we can't start directly with a PR to change the API itself without first having an approved GEP in an "implementable" state.









