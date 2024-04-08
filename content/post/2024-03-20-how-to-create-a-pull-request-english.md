---
layout:     post

title:      "How to Submit a Pull Request (PR) to Open Source Projects?"
subtitle:   ""
description: "对于开发者来说，提交 PR（Pull Reques）是参与开源项目的主要方式。不管是修复一个故障，添加一个新功能，还是改进文档，我们都需要通过提交 PR 的方式将其合入到项目的主分支中。那么，我们提交的 PR 如何才能尽快地被项目接受呢？"
author: "赵化冰"
date: 2024-03-25
image: "https://images.pexels.com/photos/3861972/pexels-photo-3861972.jpeg?auto=compress&cs=tinysrgb&w=1260&h=750&dpr=2"
published: false
tags:
categories:
    - Tech
    - Open Source
showtoc: true
---

For developers, submitting a pull request (PR) is the primary way to contribute to open source projects. Whether it's fixing a bug, adding a new feature, or improving documentation, we need to submit a PR to get our changes merged into the project's main branch. So, how can we get our submitted PR accepted by the project as soon  as possible?

To get a PR smoothly reviewed and accepted, we need to learn how to submit PRs correctly. A well-written PR can help project maintainers quickly understand the intent of the PR and provide timely feedback. Consequently, the changes in the PR can be merged into the project's main branch as soon as possible.

However, for developers unfamiliar with the open source project contribution process, submitting a good PR is not an easy task. In this article, I will share some tips and experiences I've gained while participating in open source projects. Hopefully, they can be helpful to you.

Preparation Before Submitting Your PR

For a developer who is just starting to participate in a specific open source project, directly submitting a PR without any prior communication is unlikely to be successful. This is because, on the one hand, you may not be familiar with the project's coding standards and design principles for relevant code modules when submitting your PR. As a result, your PR may not meet the project's requirements. On the other hand, without any prior communication, the project maintainers won't understand the context behind your PR submission, making it difficult for them to review it.

In most cases, project maintainers won't directly reject your PR, but it might be left hanging for a long time without much attention or feedback.

Before contributing to an open source project, developers should first learn and understand the relevant knowledge related to the project, including its design philosophy, functionalities, coding style, and compilation process. This information can usually be found in the project's official website documentation and the README file in the code repository. Understanding the project's relevant knowledge can help us better understand the project's code, making it easier to write PRs that meet the project's requirements.

Before formally submitting a PR, it's recommended to first explain the context of the PR by submitting an Issue. Issues are generally divided into two types: bugs (errors found in the project's existing code) and features (new functionalities we want the project to have). For bugs, we need to explain the bug's現象 (xiàn xiàng - phenomenon), reproduction steps, and the expected correct behavior. For features, we need to explain the purpose of the feature, the design思路 (si lu -思路 -思路 - train of thought), and possible implementation approaches. Submitting an Issue allows project maintainers to understand the context behind your PR submission in advance. We can discuss various approaches in the Issue, get feedback from project maintainers, and reach an initial consensus within the community before submitting a PR. PRs submitted after thorough discussion are more likely to be accepted by project maintainers.

Clear PR Description

When submitting a PR, we need to add a clear description for the PR. The PR description is very important. It's the first thing project maintainers look at when processing a PR. A good description allows reviewers to quickly understand the context of the PR, helps them understand the modified code in the PR, and allows the submitter to get feedback from reviewers as soon as possible, speeding up the time it takes for the PR to be merged into the project's code. On the other hand, a bad description can increase the time it takes for reviewers to understand the PR and may even cause the PR to go unnoticed for a long time.

For an open source project, there could be dozens or even hundreds of PRs waiting to be reviewed, and reviewers' time is limited. In this case, PRs with clear descriptions are often prioritized for processing.

For example, in my experience, I can usually only spend about an hour on weekdays reviewing PRs for the Envoy Gateway project. This is because in addition to reviewing PRs, I also need to handle work emails, customer issues, write code for the company's products, and work on other Envoy Gateway tasks. Within this limited time, I want to maximize my output and review as many PRs as possible. Therefore, I will prioritize reviewing PRs with clear descriptions that are easy to understand. For PRs that require a longer time to understand, I will usually put them off until I have more free time.

So, what makes a good PR description and what makes a bad one? A good PR description explains


PR 的理想长度是多少？这个并没有一个固定的答案，但是总的来说，**一个 PR 中包含的内容越多，最终合入主分支的时间也需要得越长**。

我曾经看到过包含了一百多个文件的 PR。我们应该尽量避免提交此类 “巨型”  PR。 首先，一个“巨型” PR 的阅读难度很大，因为评审者需要在大量的代码差异中进行跳转，猜测 PR 作者修改每段代码的意图，评估修改是否合理。其次，一个改动范围很大的 PR 中引入的问题也会增多，评审者在 Review 时可能提出的修改意见也会相应地增加。评审难度的增加和问题修改的交互会导致 PR 需要很长时间的评审，而长时间的评审会增加 PR 合入主分支的难度，因为大量的代码修改和这段时间内主分支的其他改动大大增加了合入代码冲突的可能性。

所以一般建议不要提交过大的 PR，而是将此类改动拆分为多个较小的 PR 分别进行提交。可以有两种拆分方式：

**按照功能拆分**：一个 PR 中只包含一个功能的修改。和我一样，很多开发者都对代码有“洁癖”，在开发过程中，我们可能会在实现 PR 的时候顺便对代码进行重构，或者顺带修复一个 bug。这是一个非常好的习惯，可以保证代码库的整洁，有利于代码的可读性以及项目的维护。但是，如果这些重构或者 bug 修复和当前 PR 的功能修改无关，建议将其拆分为另一个 PR。

在 PR 中引入和本 PR 无关的改动会让评审者在进行代码 Review 时感到迷惑：某一段代码改动到底为了实现 PR 中描述的功能，还是为了其他目的？这增加了代码阅读的难度。而保持 PR 的独立性则让评审者更容易将代码的修改和 PR 的目的联系起来，从而更快地 Review 代码。

当然，这条并不是绝对的，如果这些重构或者 bug 修复和当前 PR 的功能修改关联紧密，或者改动非常小（例如只是修改了一个拼写错误），建议还是放在一个 PR 中。

**按照模块拆分**：有时候，PR 中修复一个问题或者一个功能涉及到多个模块，则可以按照模块提交修复的PR。以 Envoy Gateway 举例，一个新的功能可能涉及到 API，Gateway API translator，xds translator，e2e test, user docs 等部分的修改。因此理论上最多可以拆分为 5 个 PR。

当然 PR 也不是拆分得越细越好，对于较小的改动，拆分得过细反而会让评审时不容易看到修改的全貌。大部分的情况下，拆分为 API 和 实现 两个 PR 就可以了。如果改动很大，则可以按模块拆分得更细一些。我的建议是 API 一定要拆分的，因为在 API 达成一致前去实现该功能很可能走错方向，导致实现代码在评审后被推翻返工，浪费了你的时间。

## PR 中的社区礼仪

在开源社区的工作中，百分之九十以上的交流都是通过 github，slack，邮件等间接的沟通方式进行的。在这种情况下，荧幕后的另一方无法像面对面交流那样通过你的面部表情、说话的语气、肢体动作等得知我们的情感，因此我们留下的文字就变得特别的重要。在我们的文字表达中，建议尽量使用礼貌，积极的语气，尊重他人的劳动成果和意见，并感谢他人的帮助以及为此付出的时间。

对于国内的开发者来说，英语的表达有可能会有一些小问题。开源社区是一个国际社区，里面的人来自世界各地，开源社区大部分情况下是以英文作为主要工作语言的。作为非英语母语者，我们对于英语的语气可能不太敏感。一些我们自己觉得没有问题的英语表达可能会稍显生硬，甚至有时候会让人感觉不礼貌。对此，我总结了几个我自己在开源社区中交流的小技巧：

* **用积极的语气表达自己的意见**。用负面/消极的说法会让人感觉被指责，从而感觉不快。改用正面/积极的语气表达自己的意见，可以让你的意见更容易被接受。

  例如，可以将这句话：There's a memory leaking problem in the current implemtation.

  改为：We can improve memory consumption by adding a cleanup function.

  修改之后的句子中，我们没有直接指出问题，而是提出了一个改进的方案，这样可以让人感觉更加积极。
  
* **使用情态动词来表示不确定性**。在表达自己的意见时，我们很多时候并不能确保自己的意见是绝对正确的。或者，即使我们认为自己的意见是正确的，我们也应该抱着商量的态度和项目中的其他人讨论，尊重他人的意见。

  在表达自己的意见时，我们可以使用 might, could, may 等情态动词词，表示自己并不假设自己的意见是绝对正确的。
  
  例如，我们可以将这句话：I don't think this is the best way to resolve the issue.
  
  改为： This might not be the best way to resolve the issue.

  在修改之后的句子中，我们使用了 might 这个情态动词，表示自己的意见并不是绝对正确的，语气也不会显得那么生硬。

* **使用疑问句来代替陈述句，尽量避免命令句**。在表达自己的意见时，我们可以使用疑问句，以商量的态度来征求他人的意见，而不是直接命令对方。这样可以让人感觉更加友好。

  例如，我们可以将这句话：We also need to expose the `foo` field in the API since it's widely used in the client code.

  改为：Should we expose the `foo` field in the API? It's widely used in the client code.
  对比这两个句子，是否可以感到修改前的句子语气相对强硬，让人约感不快？ 而在修改后的句子中，我们可以感受到作者的商量的态度，而不是强势的表达自己的意见。  

* **在提出改进意见前，先肯定他人为此付出的工作**。这一点非常重要，因为当我们的工作被别人指出问题时， 大部分人都会有一种自我保护的心态，自然会有对此产生一种抵触情绪。如果在提出改进意见前，先肯定他人的工作，可以有效地缓解这种抵触情绪，让对方从心理上更容易就我们提出的问题进行讨论。

  例如，我们可以将这句话：I have some suggestion. 改为： I think this is a good idea, just have a few suggestions on ...
  
  将这句话：This is wrong. 改为：This is a good start, but I think we could improve it by ...

  在修改之后的句子中，我们先肯定了对方的工作，然后提出了自己的改进意见。这样可以让对方更容易接受我们的意见。

上面只是一些非常简单的例子。其实我也常常遇到对自己的英语表达不确定的时候，这种时候，我一般会使用 ChatGPT 或者 Gemini 对自己的表达进行改进。一个简单的 Prompt “Please rewrite my sentence and make it polite” 就可以了。大家也可以试试。

这些开源社区的礼节并不是“繁文缛节”，而是为了让我们的交流更加顺畅和愉快。我自己的体会是，在开源社区里面，越是厉害的大牛，对于其他人越是礼貌。和他们合作，有一种如沐春风的感觉。

这里有一个很好的示例： https://github.com/kubernetes-sigs/gateway-api/pull/2283 。这是我向 Gateway API 项目提交的一个 PR，PR 本身很简单，只是为一个 API 增加了一个 Envoy Gateway 需要的字段，但是由于 Gateway API 对于这个字段的设计有一些争议，因此 Mantianer 对于这个 PR 进行了很长时间的讨论。在这个讨论中，Mantianer 对于我的 PR 提出了很多意见，但是他们的表达都非常礼貌，整个讨论过程非常愉快。最终，PR 也被合入了主分支。

下面是其中一个 Maintainer 对于我的 PR 的一个评论，可以看到他的表达中采用了上诉提到的一些 PR 礼仪：
 ```
Hey @zhaohuabing, thanks for working on this! If I'm understanding correctly, it looks like you're trying to take on a couple of separate issues:

Adding SectionName to PolicyTargetReference (Update TargetREf in Policy GEP #2147)
Adding Name to Route Rules (GEP: Add Name to HTTPRouteRule and HTTPRouteMatch #995)
I think we mostly have consensus on 1, but we're waiting for #2128 to merge before moving forward. On 2, I don't think we quite have enough consensus to move forward yet. Maybe once #2128 merges you can check in with @arkodg to see if he needs any help with the implementation of #2147.

It may also be helpful to take a look at our documentation for the GEP process. All API changes have to go through that process so we can't start directly with a PR to change the API itself without first having an approved GEP in an "implementable" state.
```

## 什么时候应该私下沟通？

一般情况下，PR 作者和评审者之间会通过 PR 中的评论来进行交流。例如，如果评审者对于 PR 中的某个修改有疑问，或者对 PR 的某个修改有异议，则在 PR 中提出，PR 作者可以选择接受意见进行修改，或者解释自己的修改意图。

通过 PR 评论的这种公开交流方式的好处是可以让 PR 的讨论过程对所有人可见，可以让其他人也了解到 PR 的讨论过程，从而提高项目的透明度。

但是公开讨论其实并不适合所有场景，有时候，私下的点对地交流会更加高效。例如，如果一个问题比较复杂，可能需要多轮的讨论才能澄清问题。这种情况下，如果在 PR 的评论中和评审者就问题进行 “反复拉扯”，讨论很容易变得混乱，而且会让 PR 的讨论气氛变得不那么友好。

这时候我们可以选择私下联系评审者，进行更深入的讨论。我的判断标准是，如果一个问题需要超过 3 个评论才能解决，那么我会选择通过 Slack 私下联系对方，进行更深入的讨论。在就问题的解决方案达成一致后，我们再将讨论的结果总结到 PR 中，以便其他人了解到讨论的结果。

另外，有时候我们的 PR 会被挂起，长时间没有得到评审。这有可能是评审者自身的工作较忙，没有时间对 PR 进行评审，或者是没有注意到 PR。这时候我们也可以选择私下联系评审者，询问 PR 的评审进度。在私下联系时，我们可以礼貌地询问评审者是否有时间对 PR 进行评审，或者询问评审者对于 PR 中的某个修改有什么意见。一般情况下，评审者会很乐意回复你的私信，帮助你解决问题。


## 欢迎大家为 Envoy Gateway 提交 PR

希望这篇文章中的这些小小的经验能够帮助到大家。同时欢迎感兴趣的朋友参与 Envoy Gateway 开源项目。对于初次参加项目的开发者，可以考虑先从文档和一些简单的 bug 修复开始，熟悉项目的代码风格和贡献流程。可以搜索 [Envoy Gateway Github repo 中 带 “help wanted” tag 的issue](https://github.com/envoyproxy/gateway/issues?q=is%3Aopen+is%3Aissue+label%3A%22help+wanted%22)，查找自己感兴趣的贡献点。除此之外，现在 Envoy Gateway 的中文官方网站正在建设中，者对于初次参与项目的同学来说是一个很好的入门机会。我们非常欢迎大家参与其中，为 Envoy Gateway 的中文文档贡献力量。

如果有任何问题，可以在项目的 Issue 中提问，我们会尽力为大家解答。对于 PR 提交者，我们也会尽力为 PR 提交者提供帮助，帮助 PR 尽快合入主分支。

