---
layout:     post

title:      "How to Pass the Certified Kubernetes Administrator (CKA) Exam Without Any Stress?"
subtitle:   ""
description: "Some useful tips I used to pass the CKA, which may help you as well"
author: "Huabing Zhao"
date: 2022-02-08
image: "https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1470&q=80"
published: true
tags:
    - CKA
    - CNCF
    - Kubernetes
categories: [ Tech ]
---

The CKA exam is not that hard. You can pass the CKA exam in less than 3 months without any stress if you follow the steps in this post to prepare. You have my word. I’ve tried myself and just successfully get my CKA certificate!

# How much time do I need to prepare for the CKA exam?

It depends, an experienced DevOps engineer could spend much less time than a newbie to prepare, but still get a high score in the exam. In general, I suggest spending 30 minutes to 1 hour to practice each day, and the preparation could last for 3 months if you don’t have much experience in K8s yet, or less if you have already worked with K8s for some time.

3 months, 1 hour each day is a relatively comfortable pace for people who also have a regular daily job to do while preparing for the exam. You won’t feel much stress during the preparation if you adopt this timeline. The key is sticking to the plan, making sure you follow the steps to practice every single day. It’s okay to only practice for 30 minutes on some particular days if you have too much other work to do that day, but one hour a day should be a normal practice time. You could also spend longer time practicing during the weekends to make up for the time during workdays.

Perseverance leads to success. I strongly suggest that you don’t skip a single day, because if you skip one day and make an exception, there’s a good chance that it will be a second time, a third time…, and you’ll fall into a spiral of missing practice and regretting, and this kind of negative emotion does not help pass the exam.

# Know what’s included in the CKA exam

CKA is designed to test if the candidates have enough knowledge and skills to be a K8s administrator. You need to know what skills and abilities the CKA expect the candidates to demonstrate in the exam, so you can align your daily practices with these requirements accordingly during preparation.

Be sure to read the CNCF CKA Exam Curriculum to understand what’s included in the CKA exam. The curriculum may change a little bit along with every K8s release, here is the outline when I take the exam:

* 25% — Cluster Architecture, Installation & Configuration
* 15% — Workloads & Scheduling
* 20% — Services & Networking
* 10% — Storage
* 30% — Troubleshooting

# Get comfortable with the exam environment

Use the exact same operating system and tools when practicing, and get yourself comfortable with those tools during preparation. You won’t want to go through a lengthy manual to find how to use a command-line tool while taking the exam, since the time is quite tight during the exam.
The CKA exam uses the following software:

* Operating system: Ubuntu 18.04
* Shell: bash
* Editor: vim
* Command-line tools: kubectl, jq, tmux, get
* Browser: Chrome

There’s a nice video on the Youtube CNCF channel introducing the CKA exam environment:：https://www.youtube.com/watch?v=9UqkWcdy140

{{< youtube 9UqkWcdy140 >}}

In particular, use those tools and get familiar with the options/settings during practice:

## VIM (Editor)

Vim is a very powerful editing tool and has a lot of commands, but we don’t need to master all of them. Just know how to switch between edit and command modes in vi, and be familiar with a few common commands in the vim editor that you will use on the exam, including delete, cut, copy, paste, page up and down, etc. Note that vim will automatically format the text when pasting YAML, but the default format may be incorrect. You can turn off the auto-formatting with :set paste in the command mode.

Some most-used vim commands:

* Enter edit mode: I
* Enter command mode: Esc
* Save and leave vi : wq
* Move the cursor to the last line: G
* Move the cursor to the first line: gg
* Moves the cursor to aspecified line: nG (n is the line number)

For a detailed introduction to the use of vim and its commands, see this article: https://www.runoob.com/linux/linux-vim.html

## jq(JSON/YAML processing)

When working with K8s resources and kubectl command-line output during the exam, you often need to manipulate Json/Yaml code snippets, such as extracting a specific field in the output. The JSON/YAML command-line tool jq is pre-installed in the exam environment, which is very handy to operate at kubectl output, for example, the following command to get the name of a mirror in a pod.

```bash
$ k get pod busybox -ojson|jq '.spec.containers[0].image'
"busybox"
```

Read this article, “My jq Cheatsheet” (https://medium.com/geekculture/my-jq-cheatsheet-34054df5b650), to learn more about how to use jq.

## tmux(Terminal multiplexer )

Only one terminal can be opened during the exam, but we may need to perform multiple tasks at the same time, or we may want to compare something in two windows. You can use a terminal multiplexing tool to achieve that. Tmux is pre-installed in the exam environment, which can be used to open multiple windows in one terminal. Some tmux commands may be useful during the exam:

* Split pane with horizontal layout: Ctrl+b %
* Split pane with vertical layout: Ctrl+b ”
* Switch to pane to the direction: Ctrl+b + arrow key

For more information on how to use tmux, please refer to the tmux cheat sheet (https://tmuxcheatsheet.com).

# Some tips for the exam

The CKA exam is two hours long. The examinee needs to solve 17 questions during the exam. In each question, there is a given scenario and a problem to solve. Most questions are not so straightforward, and the candidate often needs 3 or 4 steps to finish one question. So the time is quite tight. You need to use the time smartly and effectively, without wasting time waiting, searching, or any things not directly related to problem-solving.

We can use the following tips to save time and complete as many questions as possible within the exam time.

## Define aliases for the most frequently used kubectl commands:

I use the following aliases in the exam:

```bash
alias k=kubectl
alias kgp="k get pod"
alias kgd="k get deploy"
alias kgs="k get svc"
alias kgn="k get nodes"
alias kd="k describe"
alias kge="k get events --sort-by='.metadata.creationTimestamp' |tail -8"
```

## Enable kubectl auto-completion:

```bash
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

## Use the short name of K8s Resources instead of the full name:

|Short name|Full name|
|----------|---------|
|cm	|configmaps|
|ds	|daemonsets|
|deploy	|deployments|
|ep	|endpoints|
|ev	|events||
hpa   |   	horizontalpodautoscalers|
|ing|	ingresses|
|limits	|limitranges|
|ns	|namespaces|
|no	|nodes|
|pvc|	persistentvolumeclaims|
|pv	|persistentvolumes|
|po	|pods|
|rs	|replicasets|
|rc	|replicationcontrollers|
|quota	|resourcequotas|
|sa	|serviceaccounts|
|svc	|services|

## Use dry run to generate yaml:

During the exam, candidates will be asked to create some K8s resources such as pods, deployments, services, and so on. Writing yaml files for these resources from scratch is not only time consuming, but it is also difficult to remember the entire structure of a resource. You can use dry run to generate a basic yaml file, then make any necessary changes on that file, and then use the modified file to create the required resources.

For example, this question: Create an nginx pod, set the request memory to 1M and the CPU to 500m can be solved with the following commands:

```bash
k run nginx --image=nginx --dry-run=client -oyaml > pod.yaml
vi pod.yaml //添加 resource limit 设置
k create -f pod.yaml
```

To save the input time, we can define a shell variable for the -dry-run=client -oyamloption:

```bash
export do="--dry-run=client -o yaml"
```

Then we can use the defined variable like this:

```bash
k run nginx --image=nginx $do > pod.yaml
```

## Delet pods without waiting

Oftentimes we need to delete pods during CKA exams. k8s delete pods gracefully, which means that the kubectl command will wait until the relevant resources have been cleaned up, sometimes causing kubectl hang for a few minutes. So to minimize the wait time for deletion, we can force delete pods.

```bash
export now="--force --grace-period 0"

k delete pod test $now
```

## Use kubectl help to view examples of creating resources

The output of the ```kubectl command --help``` provides a number of common examples that can be copied and used in the exam with only minor modifications. Using this command saves you a great amount of time searching through the enormous k8s online documentation.

For example, the output of ```kubectl run --help ``` contains a dozen of useful examples for creating pods.

```bash
kubectl run --help
Create and run a particular image in a pod.

Examples:
  # Start a nginx pod.
  kubectl run nginx --image=nginx

  # Start a hazelcast pod and let the container expose port 5701.
  kubectl run hazelcast --image=hazelcast/hazelcast --port=5701

  # Start a hazelcast pod and set environment variables "DNS_DOMAIN=cluster" and "POD_NAMESPACE=default" in the
container.
  kubectl run hazelcast --image=hazelcast/hazelcast --env="DNS_DOMAIN=cluster" --env="POD_NAMESPACE=default"

  # Start a hazelcast pod and set labels "app=hazelcast" and "env=prod" in the container.
  kubectl run hazelcast --image=hazelcast/hazelcast --labels="app=hazelcast,env=prod"

  # Dry run. Print the corresponding API objects without creating them.
  kubectl run nginx --image=nginx --dry-run=client

  # Start a nginx pod, but overload the spec with a partial set of values parsed from JSON.
  kubectl run nginx --image=nginx --overrides='{ "apiVersion": "v1", "spec": { ... } }'

  # Start a busybox pod and keep it in the foreground, don't restart it if it exits.
  kubectl run -i -t busybox --image=busybox --restart=Never

  # Start the nginx pod using the default command, but use custom arguments (arg1 .. argN) for that command.
  kubectl run nginx --image=nginx -- <arg1> <arg2> ... <argN>

  # Start the nginx pod using a different command and custom arguments.
  kubectl run nginx --image=nginx --command -- <cmd> <arg1> ... <argN>
  ```

## Use kubectl explain to view the definition of a resource

The kubectl help command gives you examples of how to create a resource, but the help command only shows some common options and does not provide a complete structure for that resource. If we need to see the definition of a k8s resource, one way is to search in the k8s online documentation, but the search function in the K8s documentation is not very user-friendly and you may need to click multiple times, jump from pages to find the correct link. A more effecitve way is to use the kubectl explain command.

For example, if you want to know how to set the resource limit for a container, but cannot remember the structure of the pod yaml, you can use kubectl explain to explore the pod structure like this:

``` bash
k explain pod.spec //View the pod spec definition
k explain pod.spec.containers //View the containers definition
k explain pod.spec.containers.resources //View the container resources definition
k explain pod.spec.containers.resources.limits //View the containter resources limits definition
```

## Create a temporary pod for testing

The exam often asks candidates to create some temporary pods for testing. For example, create a busybox pod, run wget command in it to test a k8s service created in the previous step.

The testings pods can be created using kubectl run with the — rm option. The — rm option means that the pod will be deleted immediately after running the specified command. This trick allows us to quickly create a temporary pod that can execute commands like wget, curl, etc. The pod will be deleted automatically after the command has been executed, so we don’t have to clean it up manually. This technique is also quite useful when troubleshooting applications running in K8s.

```bash
➜  ~ kubectl -it  run busybox --rm --image=busybox -- sh
If you don't see a command prompt, try pressing enter.
/ # wget -O- 172.17.254.255
```

# Bookmark frequently used k8s documents

You can view k8s online documents during the exam, so you can add the links you may use during the exam to the bookmarks in advance to avoid wasting time searching for them during the exam. To make it easier to find, it’s also a good idea to organize the the links and put them in different folders. Below is the screenshot of Chrome bookmarks I had when taking the exam, just for your reference:

![](/img/2022-02-08-how-to-prepare-cka/bookmarks.png)

Some links I found useful：

* https://kubernetes.io/docs/reference/kubectl/cheatsheet/
* https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/
* https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker
* https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/#steps-for-the-first-control-plane-node
* https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
* https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#snapshot-using-etcdctl-options
* https://kubernetes.io/docs/tasks/debug-application-cluster/debug-cluster/
* https://github.com/kubernetes/ingress-nginx/blob/main/docs/deploy/index.md

Please note that access to documents other than https://helm.sh/docs/, https://kubernetes.io/docs/, https://github.com/kubernetes/, https://kubernetes.io/blog/ is not allowed in the exam, so be careful not to click on external links in the k8s documentation, such as those on the cni addon and docker websites.

# Practice, practice, and practice

The CKA exams requires candidates to solve the given k8s problems within a given time frame, which requires an good understanding of K8s concepts and skills with the kubectl command line. There are some resources on Github that you can use for practicing.

* [CKA Practice Exercises](https://github.com/alijahnas/CKA-practice-exercises)
* [Kubernetes Certified Administration](https://github.com/walidshaari/Kubernetes-Certified-Administrator)
* [K8s Practice Training](https://github.com/StenlyTU/K8s-training-official)
* [Awesome Kubernetes](https://github.com/ramitsurana/awesome-kubernetes)

As I mentioned, It is recommended that you create a practice plan and stick to it. The plan I followed was to start practicing three months before the exam, taking half an hour every morning before work from Monday to Friday. The weekends are more flexible and I would spend about 2 hours practicing on Saturday and Sunday. Remember the longer you practice, the more familiar you will be with the kubectl command line, and the more confident you will be about the upcoming exam, and the better your chances of passing the exam.

After purchasing the CKA exam, you will be given two simulation exams on killer.sh. The simulation exams cover all the content you’ll have in the actual exam, but are slightly more difficult. After practicing the above exercises for a while, you can take the first simulation exam; then, you can review the questions you get wrong and practice more, and then take the simulation exam again. During this process, you basically build confidence about what you will have in the CKA exam, and you can decide when to finally take the official exam when you fell comfortable.

Following the above approach during preparation, I successfully passed the CKA exam. I wish you all success in passing the exam too!

![](/img/2022-02-08-how-to-prepare-cka/cka.png)

