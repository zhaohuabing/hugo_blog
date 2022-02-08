---
layout:     post

title:      "如何成功通过 CKA 考试？"
subtitle:   ""
description: "帮助你顺利通过 CKA 考试的一些技巧。"
author: "赵化冰"
date: 2022-02-08
image: "https://images.unsplash.com/photo-1568605117036-5fe5e7bab0b7?ixlib=rb-1.2.1&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=1470&q=80"
published: true
tags:
    - CKA
    - CNCF
    - Kubernetes
categories: [ Tech ]
---

# 了解 CKA 考察的内容

在开始准备考试前一定要阅读[CNCF 官方考试大纲](https://github.com/cncf/curriculum)，了解 CKA 考察考生的主要内容，以在备考时做到知己知彼，有的放矢，根据该考试大纲进行针对性的准备和练习。该大纲会根据 K8s 的版本进行更新，但每个版本中涉及的考试内容变化不大，下面是我准备考试时的版本（v1.22）要求的主要内容：

* 25% - Cluster Architecture, Installation & Configuration
* 15% - Workloads & Scheduling
* 20% - Services & Networking
* 10% - Storage
* 30% - Troubleshooting

# 熟悉考试的软件环境

CKA 考试的软件环境如下，确保在考试前的练习中采用相同的软件环境，以提前熟悉考试环境：

* 操作系统：Ubuntu 18.04
* Shell：bash
* 编辑器：vi
* 命令行工具：kubectl jq tmux curl wget
* 浏览器 chrome


YouTube 上有一个 Linux 基金会录制的 CKA 考试环境的视频，大家可以看一下，对考试环境有一个基本的了解：https://www.youtube.com/watch?v=9UqkWcdy140

{{< youtube 9UqkWcdy140 >}}

建议在准备考试时充分练习并熟悉下面的工具：

## 编辑器 vi

vi 是一个非常强大的编辑软件，命令也非常多，但我们不需要掌握所有的命令。了解如何在 vi 的编辑和命令模式之间切换，并熟悉在考试中会使用到的几个 vi 编辑器的常用命令即可，包括删除、剪切、拷贝、粘贴、上下翻页等。注意 vi 在粘贴 yaml 时的自动格式化处理可能会不正确。可以通过 `:set paste` 取消 vi 的自动格式化。常用的 vi 命令：

* 进入编辑模式 i
* 进入命令模式 Esc
* 储存后离开 vi :wq
* 光标移动最后一行 G
* 光标移动到第一行 gg
* 光标移动到指定 nG （n为行数）

vi 的使用方法和命令介绍参见这篇文章：https://www.runoob.com/linux/linux-vim.html

## Josn/yaml 处理 jq

在对 K8s crd 和 kubectl 命令行输出进行操作时需要对 Json/Yaml 代码片段进行操作，例如截取或者修改输出中某个特定的字段。考试环境中预装了 Json/Yaml 的命令行工具 jq。在练习时要熟悉该命令的使用方法，例如下面的命令可以获取 pod 中的镜像名称：
```bash
$ k get pod busybox -ojson|jq '.spec.containers[0].image'
"busybox"
```
阅读这篇文章《My jq Cheatsheet》(https://medium.com/geekculture/my-jq-cheatsheet-34054df5b650)，了解更多 jq 的使用方法。

## 终端复用器 tmux 

考试时只能打开一个终端，但在考试时我们可能需要同时执行多个任务，或者在多个终端之间进行对比查看、复制粘贴。可以使用考试环境中预装的终端复用工具 tmux 来打开多个终端。在考试中会可能使用到的常用 tmux 命令：

  * Ctrl+b %：划分左右两个窗格。
  * Ctrl+b "：划分上下两个窗格。
  * Ctrl+b <arrow key>：光标切换到其他窗格。<arrow key> 是指向要切换到的窗格的方向键，比如切换到下方窗格，就按方向键↓。

关于 tmux 的更多使用方法，可以参考 阮一峰 老师的 [《Tmux 使用教程》](https://www.ruanyifeng.com/blog/2019/10/tmux.html)。

# 考试的一些技巧

CKA 考试一共两个小时，时间是比较紧张的，可能会出现时间不够用的情况。可以采用下面的技巧来加快做题的速度，在考试时间内完成尽量多的试题。

## 为常用的 kubectl 命令定义 alias
你可以根据自己的习惯来设置 alias，如下：

```bash
alias k=kubectl
alias kgp="k get pod"
alias kgd="k get deploy"
alias kgs="k get svc"
alias kgn="k get nodes"
alias kd="k describe"
alias kge="k get events --sort-by='.metadata.creationTimestamp' |tail -8"
```

## 使用 kubectl 的自动补全功能

```bash
source <(kubectl completion bash)
echo "source <(kubectl completion bash)" >> ~/.bashrc
```

## 使用 K8s Resource 的缩写名而不是全称

熟练使用常见 K8s Resource 名称的缩写：

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

## 采用 dry run 来生成 yaml

考生会被要求创建一些 K8s 资源，例如 pod，deployment，service 等等。从头编写这些资源的 yaml 文件不仅耗时，而且我们也很难记住某个资源的整个结构。可以使用 dry run 来生成一个基础的 yaml 文件，然后基于该文件进行修改，最后再采用修改后的文件来创建资源。

例如这道题：创建一个 nginx pod，将 request 的 memory 设置为 1M, CPU 设置为 500m

```bash
k run nginx --image=nginx --dry-run=client -oyaml > pod.yaml
vi pod.yaml //添加 resource limit 设置
k create -f pod.yaml
```

由于在考试中会频繁使用到 ```--dry-run=client -oyaml``` 选项来生成 k8s 对象的 yaml 文件，我们可以采用 export 来定义一个变量 do，以节省输入时间。

```bash
export do="--dry-run=client -o yaml"
```

定义 do 变量后，就可以像下面这样使用：

```bash
k run nginx --image=nginx $do > pod.yaml
```

## 快速删除 pod

CKA 考试中有时候需要删除 pod，k8s 缺省采用优雅删除的方式，这意味着 kubectl 命令行会被挂起等待较长的时间，等相关资源被清理后再返回。这个时间可能会长达 10 多秒。CKA 考试时间相对比较紧张，为了尽可能减少删除时的等待时间，我们可以采用强制删除的方式快速删除 pod。

```bash
export now="--force --grace-period 0"
```

定义 now 变量后，可以像下面这样快速删除一个 pod：

```bash
k delete pod test $now
```

## 利用 kubectl command help 查看创建资源示例

```kubectl command --help``` 命令的输出中提供了很多常用例子，将这些例子拷贝出来稍加修改就可以在考试中使用。采用该命令可以节约在 k8s 在线文档中查找搜寻相关示例的时间。

例如 ```kubectl run --help``` 的输出中有大量创建 pod 的示例：

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

## 采用 kubectl explain 来查看 resource 的定义

通过 ```kubectl command --help``` 命令可以查看创建资源的示例，但 help 命令中只显示了常用的选项，并不会提供完整的资源定义。如果在考试中我们需要查看某个 k8s 资源的定义，一个方法到在 k8s 在线文档中去搜索该资源的 API，但在 K8s 文档的搜索功能并不是很方便使用，你可能需要点击多次才能找到正确的链接。另一个更方便的方法是采用 kubectl explain 命令来查看资源定义。kubectl explain 的好处是可以层层递进查看，例如需要查看 pod 中容器的 limit 如何定义，但记不清楚 pod yaml 的结构层次，则可以这样查询：

``` bash
k explain pod.spec //查看 pod 的 spec
k explain pod.spec.containers //进一步查看 pod spec 中 containers 部分的定义
k explain pod.spec.containers.resources //进一步查看 resources 部分的定义
k explain pod.spec.containers.resources.limits //进一步查看 limits 部分的定义
```

## 创建临时 Pod 来进行测试

考试时经常会让考生创建临时 pod 来测试某些功能，例如创建一个临时的 busybox pod ，在该 pod 中通过 wget 命令来测试上一个步骤中 expose 的某个 k8s service。可以采用 ``` kubectl run ``` 加上 ``` --rm ``` 选项来创建该 pod，``` --rm ``` 选项表示运行指定的命令后该 pod 将会被立即删除掉。该技巧可以让我们快速创建一个可以执行 wget， curl 等命令的临时 pod，命令执行后 pod 会被自动删除掉，无需手动清理。 该技巧在平时对 K8s 中运行的应用程序进行排错时也很有用。

```bash
➜  ~ kubectl -it  run busybox --rm --image=busybox -- sh
If you don't see a command prompt, try pressing enter.
/ # wget -O- 172.17.254.255
```

# 安装 k8s 集群的一些注意事项

安装前首先采用 ```sudo -i``` 命令切换到 root 用户。

我们只需要了解安装需要的相关工具和大致步骤，并不需要记住安装的相关命令。考试时打开 K8s 官网中的 [Bootstrapping clusters with kubeadm](https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/) 文档，跟随文档中的步骤进行安装即可。

## 安装 Docker

Docker 官网的安装手册中有较多步骤，而在考试中不允许访问 Docker 官网。建议使用一键安装脚本来安装 Docker。Docker 一键安装脚本的地址 ```get.docker.com``` 很容易记住。

```bash
bash <(wget -O- get.docker.com)
```

注意需要设置 systemd 为 docker 的 cgroup driver，参见 https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker

## 初始化 master 节点

如果节点上有多个网卡，注意通过 ```--apiserver-advertise-address``` 参数设置 apiserver 的监听地址，该地址应为和 worker 节点同一个局域网上的地址。

如果使用了 flannel 插件，需要在 kubeadm 命令中加入 pod cidr 参数， ```kubeadm init --pod-network-cidr=10.244.0.0/16```，cidr 和 https://raw.githubusercontent.com/coreos/flannel/master/Documentation/kube-flannel.yml 中配置的 CIDR 一致。

## 安装 CNI 插件

采用 kubeadm 初始化集群后，需要通过 ``` kubectl apply -f <add-on.yaml> ``` 安装  CNI addon，否则加入集群的节点会一直处于 NotReady 状态。平时安装时我们会通过 k8s 在线文档导航到一个外部的 CNI 网站上，找到该 addon 的 yaml 文件。在考试时不允许访问 CNI 的网站，在下面的 K8s 文档中有安装 CNI 插件的例子，可以将网页地址加入浏览器收藏夹中。
https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/#steps-for-the-first-control-plane-node

# 收藏常用 k8s 文档

考试时可以查看 k8s 在线文档，因此可以提前将考试中可能会用到的 k8s 文档加入 chrome 收藏夹，避免考试时临时搜索浪费时间。
你可以根据练习判断需要收藏哪些 K8s 文档，并按分类整理文件夹，下图是我收藏的文档：
![](/img/2022-02-08-how-to-prepare-cka/bookmarks.png)

一些有用的文档链接：

* kubectl 命令参考：https://kubernetes.io/docs/reference/kubectl/cheatsheet/
* 使用 kubeadm 安装 K8s 集群 Kubernetes API：https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/
* 设置 Docker：https://kubernetes.io/docs/setup/production-environment/container-runtimes/#docker
* 安装 K8s CNI addon：https://kubernetes.io/docs/setup/production-environment/tools/kubeadm/high-availability/#steps-for-the-first-control-plane-node
* 升级 K8s Cluster: https://kubernetes.io/docs/tasks/administer-cluster/kubeadm/kubeadm-upgrade/
* 备份 etcd ：https://kubernetes.io/docs/tasks/administer-cluster/configure-upgrade-etcd/#snapshot-using-etcdctl-options
* K8s Cluster 排错：https://kubernetes.io/docs/tasks/debug-application-cluster/debug-cluster/
* Nginx ingress controller 安装：https://github.com/kubernetes/ingress-nginx/blob/main/docs/deploy/index.md

注意：考试中不允许访问 https://helm.sh/docs/, https://kubernetes.io/docs/, https://github.com/kubernetes/,  https://kubernetes.io/blog/ 之外的其他文档，因此注意不要点击 k8s 文档中的外链，例如 cni addon 和 docker 网站的外链。

# 练习，练习，练习

CKA 要求考生在规定时间内完成对 K8s 的指定管理任务，这要求考生理解 K8s 的相关概念，并非常熟悉 kubectl 命令行的相关操作。而熟悉 kubectl 命令行的方法就是不断的重复练习。Github 上有一些很好的资源，可以在准备考试时参照进行练习：

* [CKA Practice Exercises](https://github.com/alijahnas/CKA-practice-exercises)
* [Kubernetes Certified Administration](https://github.com/walidshaari/Kubernetes-Certified-Administrator)
* [K8s Practice Training](https://github.com/StenlyTU/K8s-training-official)
* [Awesome Kubernetes](https://github.com/ramitsurana/awesome-kubernetes)

建议在考试前制定一个练习计划，并坚持按照该计划进行练习。我遵循的计划是考试前三个月开始练习，周一到周五每天早上上班前抽半小时时间。周末的时间比较灵活，周六和周日会花2小时左右练习。你练习的时间越长，对 kubectl 命令行的操作越熟悉，对即将到来的考试越有信心，顺利通过考试的几率则越大。

购买 CKA 考试后会赠送两次 killer.sh 的模拟考试，模拟考试的难度稍大于实际考试。在练习一段时间上面的习题后，可以参加第一次模拟考试；然后根据模拟考试的结果再进行查漏补缺，对第一次考试中的错题进行分析和加强练习，然后再进行第二次模拟考试。做完两次模拟考试，并掌握了模拟考试中所有试题的知识点后，你心里基本上就对考试的内容有较大的底气，可以参加正式考试了。

按照上面的方法进行准备，我成功通过了 CKA 的考试。也祝大家顺利通过考试！

![](/img/2022-02-08-how-to-prepare-cka/cka.png)

