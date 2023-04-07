---
layout:     post

title:      "Kubernetes Controller 机制详解（二）"
subtitle:   "Controller Runtime 和 Kubebuilder"
description: "Kubernetes(简称K8s) 是一套容器编排和管理系统，可以帮助我们部署、扩展和管理容器化应用程序。在 K8s 中，Controller 是一个重要的组件，它可以根据我们的期望状态和实际状态来进行调谐，以确保我们的应用程序始终处于所需的状态。本系列文章将解析 K8s Controller 的实现机制，并介绍如何编写一个 Controller。"
author: "赵化冰"
date: 2023-04-04
image: "https://images.unsplash.com/photo-1432821596592-e2c18b78144f?ixlib=rb-4.0.3&ixid=MnwxMjA3fDB8MHxwaG90by1wYWdlfHx8fGVufDB8fHx8&auto=format&fit=crop&w=2370&q=80"
published: true
tags:
    - Kubernetes
categories:
    - Tech
showtoc: true
---

在上一篇文章 [Kubernetes Controller 机制详解（一）](https://www.zhaohuabing.com/post/2023-03-09-how-to-create-a-k8s-controller/)中，我们学习了 Kubernetes API List/Watch 机制，以及如何采用 Kubernetes client-go 中的 Informer 机制来创建 Controller。该方法需要用户了解 Kubernetes client-go 的实现原理，并在 Controller 的编码中处理较多 Informer 实现相关的细节。包括启动 InformerFactory，将 Watch 到的消息加入到队列，重试等等逻辑。如果有多个副本，还需要加入 Leader Election 的相关代码。如果需如果你创建了自定义的 CRD，可能还希望在创建资源时采用 webhook 对资源进行校验。这些功能都需要用户编写较多的代码。

在大部分情况下，上面提到的这些功能相关的代码都是类似的，如果没有非常灵活的定制要求，我们完全可以忽略这些底层细节，采用 Controller runtime 来简化 Controller 的编写。

# Controller runtime

下面的代码片段采用了 [Controller runtime]((https://github.com/kubernetes-sigs/controller-runtime)) 来重写上一篇文章中的 [sample controller](https://www.zhaohuabing.com/post/2023-03-09-how-to-create-a-k8s-controller/)。可以看到代码相当简洁，相对于采用 Informer 的版本，代码行数从 260 行缩减到 80 行，代码量较少了三分之二还多。而且采用 Controller runtime 的版本功能更强，在原版本功能之外还实现了 validation webhook 和 mutation webhook，支持采用 webhook 对自定义 foo 资源的增、删、改操作进行校验和设置字段缺省值。

下面是对代码中关键部分的介绍：

* Mananger：Controller runtime 中引入了 Manager 组件。在一个进程中可以有多个 Controller，每个 Controller 负责对一种资源进行调谐。Manager 则用来统一管理这些 Controller 的生命周期。
* Controller：采用 controller-runtime package 的 ```NewControllerManagedBy``` 方法来创建一个 controller 并将其加入之前创建的 Manager 中。该方法只需要两个参数：watch 的 CRD 资源类型，以及实现 ```Reconciler``` 接口的一个对象。
* Webhook：采用 controller-runtime package 的 ```NewWebhookManagedBy``` 方法来创建一个 webhook 并将其加入到之前创建的 Manager 中。

可以看到，controller runtime 已经封装了 Informer 机制中大部分的模板代码，用户在编写 controller 时真正需要编写的基本只有 Reconcile 方法中的业务逻辑。  

{{< highlight go "linenos=inline" >}}
package main

import (
	"context"
	"fmt"
	api "github.com/zhaohuabing/k8scontrollertutorial/pkg/custom/apis/foo/v1alpha1"
	_ "k8s.io/client-go/plugin/pkg/client/auth/gcp"
	"os"
	ctrl "sigs.k8s.io/controller-runtime"
	"sigs.k8s.io/controller-runtime/pkg/client"
	"sigs.k8s.io/controller-runtime/pkg/log"
	"sigs.k8s.io/controller-runtime/pkg/log/zap"
)

var (
	setupLog = ctrl.Log.WithName("setup")
)

type reconciler struct {
	client.Client
}
// 对 foo 进行调谐的方法
func (r *reconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	log := log.FromContext(ctx).WithValues("foo", req.NamespacedName)
	log.V(1).Info("reconciling foo")

	var foo api.Foo
	if err := r.Get(ctx, req.NamespacedName, &foo); err != nil {
		log.Error(err, "unable to get foo")
		return ctrl.Result{}, err
	}

	fmt.Printf("Sync/Add/Update for foo %s\n", foo.GetName())
	return ctrl.Result{}, nil
}

func main() {
	ctrl.SetLogger(zap.New())
	// 创建 Manager，创建时设置 Leader Election 相关的参数
	mgr, err := ctrl.NewManager(ctrl.GetConfigOrDie(), ctrl.Options{
		LeaderElection:          true,
		LeaderElectionID:        "sample-controller",
		LeaderElectionNamespace: "kube-system",
	})
	if err != nil {
		setupLog.Error(err, "unable to start manager")
		os.Exit(1)
	}

	// in a real controller, we'd create a new scheme for this
	err = api.AddToScheme(mgr.GetScheme())
	if err != nil {
		setupLog.Error(err, "unable to add scheme")
		os.Exit(1)
	}
    // 创建对 foo 进行调谐的 controller
	err = ctrl.NewControllerManagedBy(mgr).
		For(&api.Foo{}).
		Complete(&reconciler{
			Client: mgr.GetClient(),
		})
	if err != nil {
		setupLog.Error(err, "unable to create controller")
		os.Exit(1)
	}
    // 创建用于校验 foo 的 webhook
	err = ctrl.NewWebhookManagedBy(mgr).
		For(&api.Foo{}).
		Complete()
	if err != nil {
		setupLog.Error(err, "unable to create webhook")
		os.Exit(1)
	}
	// 启动 Manager，Manager 将启动其管理的所有 controller 以及 webhook server
	setupLog.Info("starting manager") 
	if err := mgr.Start(ctrl.SetupSignalHandler()); err != nil {
		setupLog.Error(err, "problem running manager")
		os.Exit(1)
	}
}
{{< / highlight >}}

前面的代码片段中只有调谐的逻辑，那么 webhook 是如何实现的呢？在调用 ```mgr.Start``` 方法后，Controller runtime 框架会检查 CRD 对应的 go struct 是否实现了 实现 ```Validator``` 和 ```Defaulter``` 两个 Interface 中的相关方法。如果实现了，就会替该 CRD 自动创建 webhook HTTP server。

```go
// 实现 Validation Webhook 逻辑
func (f *Foo) ValidateCreate() error {
	if f.Spec.Replicas != nil && *f.Spec.Replicas < 0 {
		return fmt.Errorf("replicas should be non-negative")
	}
	return nil
}
func (f *Foo) ValidateUpdate(old runtime.Object) error {
	if f.Spec.Replicas != nil && *f.Spec.Replicas < 0 {
		return fmt.Errorf("replicas should be non-negative")
	}
	return nil
}
func (f *Foo) ValidateDelete() error {
	return nil
}

// 实现 Mutation Webhook 逻辑
func (f *Foo) Default() {
	if f.Spec.Replicas == nil {
		f.Spec.Replicas = new(int32)
		*f.Spec.Replicas = 1
	}
}
```

我们还需要创建对应的 ```ValidatingWebhookConfiguration``` 和 ```MutationWebhookConfiguration```，以告知 Kubernetes API Server 在收到对 Foo 资源的操作请求时调用 sample controller 中的 webhook server 对资源进行修改和校验。

```yaml
apiVersion: admissionregistration.k8s.io/v1
kind: ValidatingWebhookConfiguration
metadata:
  name: foo
webhooks:
  - name: foo.samplecontroller.k8s.io
    clientConfig:
      service:
        namespace: default
        name: sample-controller-webhook-server
        path: /validate-samplecontroller-k8s-io-v1alpha1-foo
    rules:
      - apiGroups: ["samplecontroller.k8s.io"]
        apiVersions: ["v1alpha1"]
        resources: ["foos"]
        operations: ["CREATE", "UPDATE", "DELETE"]
        scope: Namespaced
    sideEffects: None
    admissionReviewVersions: ["v1"]
---
apiVersion: admissionregistration.k8s.io/v1
kind: MutatingWebhookConfiguration
metadata:
  name: foo
webhooks:
  - name: foo.samplecontroller.k8s.io
    clientConfig:
      service:
        namespace: default
        name: sample-controller-webhook-server
        path: /validate-samplecontroller-k8s-io-v1alpha1-foo
    rules:
      - apiGroups: [ "samplecontroller.k8s.io" ]
        apiVersions: [ "v1alpha1" ]
        resources: [ "foos" ]
        operations: ["CREATE"]
        scope: Namespaced
    sideEffects: None
    admissionReviewVersions: ["v1"]
```

完整的代码参见：https://github.com/zhaohuabing/k8scontrollertutorial/tree/main/pkg/custom/controller_runtime

# Kubebuilder

采用 Controller runtime 来构建自定义的 Controller 很大程度简化了 Controller 的编码。但除了编写 Controller 的调谐代码之外，我们还有其他一些需要手动完成的工作，包括：
* 创建一个合理的项目目录结构
* 编写自定义 CRD 的 yaml 定义
* 使用 go-generator 工具来生成自定义 CRD 的 go client 代码
* 编写构建镜像的 Dockerfile 和构建项目的脚本
* 编写部署 Controller 需要的相关 manifest，包括 Role，ServiceAccount，Rolebinding，Ddeployment，Service 等

Kubebuilder 是一个 “project generator”。Kubebuilder 可以为我们创建项目的目录结构，并生成相关的框架代码和 yaml 文件。 Kubebuilder 会采用 Controller runtime 库来生成 Controller 代码。通过采用 Kubebuilder 来开发自定义 CRD 和 Controller，开发者无需手动编写项目中的大部分文件，只需要在 Kubebuilder 生成的文件中添加业务逻辑即可。

安装 Kubebuilder 命令行工具后，执行 ```kubebuilder init``` 命令，就可以生成项目。

```bash
kubebuilder init --project-name kubebuilderexample --domain zhaohuabing.com --repo github.com/zhaohuabing/kubebuilderexample
```
其中 domain 是自定义 CRD group 的 domain 后缀，repo 是对应的 go module 名。
执行命令后，可以看到 Kubebuilder 生成了项目的相关目录，Manager 代码，用于部署的 Kubernetes 配置文件。

```bash
tree ./
./
├── Dockerfile
├── Makefile
├── PROJECT
├── README.md
├── config
│   ├── default
│   │   ├── kustomization.yaml
│   │   ├── manager_auth_proxy_patch.yaml
│   │   └── manager_config_patch.yaml
│   ├── manager
│   │   ├── kustomization.yaml
│   │   └── manager.yaml
│   ├── prometheus
│   │   ├── kustomization.yaml
│   │   └── monitor.yaml
│   └── rbac
│       ├── auth_proxy_client_clusterrole.yaml
│       ├── auth_proxy_role.yaml
│       ├── auth_proxy_role_binding.yaml
│       ├── auth_proxy_service.yaml
│       ├── kustomization.yaml
│       ├── leader_election_role.yaml
│       ├── leader_election_role_binding.yaml
│       ├── role_binding.yaml
│       └── service_account.yaml
├── go.mod
├── go.sum
├── hack
│   └── boilerplate.go.txt
└── main.go
```

在生成项目的目录和初始文件后，可以采用 ```kubebuilder create api``` 命令来创建自定义的 CRD 和其 Controller。

```bash
kubebuilder create api --group samplecontroller --version v1alpha1 --kind Foo
```

执行该命令后，我们需要修改生成的 ```api/v1alpha1/foo_types.go``` 文件，在其中加入 Foo 资源的相关属性。

```go
// FooSpec defines the desired state of Foo
type FooSpec struct {
        // INSERT ADDITIONAL SPEC FIELDS - desired state of cluster
        // Important: Run "make" to regenerate code after modifying this file

        DeploymentName string `json:"deploymentName"`
        Replicas       *int32 `json:"replicas"`
}

// FooStatus defines the observed state of Foo
type FooStatus struct {
        // INSERT ADDITIONAL STATUS FIELD - define observed state of cluster
        // Important: Run "make" to regenerate code after modifying this file
        AvailableReplicas int32 `json:"availableReplicas"`
}
```

然后再生成 CRD 的 Kubernetes yaml 定义文件。

```bash
make manifests
```

通过下面的命令将自定义 CRD Foo 安装到 Kubernetes 集群中。

```bash
make install
```

该脚本会安装 kustomize ，执行过程中如果遇到 ```Github rate-limiter failed the request``` 错误，可以到 https://github.com/settings/tokens 创建一个 token，将该 token 设置到环境变量 GITHUB_TOKEN 中，再执行 make install。

```bash
export GITHUB_TOKEN=ghp_RgtZXEDrZPMlf4tzieW8fbZw8QW0A0XBGrU
```

创建一个 foo 资源。

```bash
kubectl apply -f config/samples/samplecontroller_v1alpha1_foo.yaml
```

修改 ```controllers/foo_controller.go``` 代码，在其中加入调谐逻辑。本示例中我们只是简单地把 Foo 资源的名称打印出来：

```go
func (r *FooReconciler) Reconcile(ctx context.Context, req ctrl.Request) (ctrl.Result, error) {
	_ = log.FromContext(ctx)

	// TODO(user): your logic here
	fmt.Println("reconcile foo " + req.Name)
 
	return ctrl.Result{}, nil
}
```

构建镜像。
```bash
make docker-build docker-push IMG=zhaohuabing/sample-controller:kubebuilder
```

使用构建的镜像在集群中部署 Controller。 

```bash
make deploy IMG=zhaohuabing/sample-controller:kubebuilder
```

查看部署的 Controller 日志，可以看到对 Foo 资源的处理记录。

```bash
k -n kubebuilderexample-system logs deployments/kubebuilderexample-controller-manager
2023-04-07T06:57:46Z	INFO	controller-runtime.metrics	Metrics server is starting to listen	{"addr": "127.0.0.1:8080"}
2023-04-07T06:57:46Z	INFO	setup	starting manager
2023-04-07T06:57:46Z	INFO	Starting server	{"path": "/metrics", "kind": "metrics", "addr": "127.0.0.1:8080"}
2023-04-07T06:57:46Z	INFO	Starting server	{"kind": "health probe", "addr": "[::]:8081"}
I0407 06:57:46.661418       1 leaderelection.go:248] attempting to acquire leader lease kubebuilderexample-system/b5a87b6b.zhaohuabing.com...
I0407 06:58:10.744397       1 leaderelection.go:258] successfully acquired lease kubebuilderexample-system/b5a87b6b.zhaohuabing.com
2023-04-07T06:58:10Z	DEBUG	events	kubebuilderexample-controller-manager-5dd6674747-lp2tr_1138657a-0d3c-4232-87f6-588d7c771011 became leader	{"type": "Normal", "object": {"kind":"Lease","namespace":"kubebuilderexample-system","name":"b5a87b6b.zhaohuabing.com","uid":"7258ce1a-6007-4147-936f-4630e9350362","apiVersion":"coordination.k8s.io/v1","resourceVersion":"1687"}, "reason": "LeaderElection"}
2023-04-07T06:58:10Z	INFO	Starting EventSource	{"controller": "foo", "controllerGroup": "samplecontroller.zhaohuabing.com", "controllerKind": "Foo", "source": "kind source: *v1alpha1.Foo"}
2023-04-07T06:58:10Z	INFO	Starting Controller	{"controller": "foo", "controllerGroup": "samplecontroller.zhaohuabing.com", "controllerKind": "Foo"}
2023-04-07T06:58:10Z	INFO	Starting workers	{"controller": "foo", "controllerGroup": "samplecontroller.zhaohuabing.com", "controllerKind": "Foo", "worker count": 1}
reconcile foo foo-sampl
```
完整的代码参见：https://github.com/zhaohuabing/kubebuilderexample

# 小结
在本系列文章中，我们介绍了 Kubernetes List/Watch API 的原理，以及基于该 API 编写自定义 Controller 的几种方法。我们可以采用 Informer，Controller runtime，Kubebuilder 来编写 Controller。其中 Informer 和 Controller 是 Kubernetes 提供的代码库，而 Kubebuilder 则是一个快速生成 Controller 项目的脚手架工具。其实这些方法说到底都是对 Kubernetes List/Watch 机制的封装。对于开发者的友好程度而言，Informer，Controller runtime，Kubebuilder 依次增加；而代码定制的灵活度则依次降低。在具体使用时，可以根据业务需求的具体情况选择其中的一种方式。


# 参考文档

* [Kubernetes controller-runtime](https://github.com/kubernetes-sigs/controller-runtime)
* [kubebuilder quick start](https://book.kubebuilder.io/quick-start.html)
* [采用 Controller runtime 的源代码](https://github.com/zhaohuabing/k8scontrollertutorial/tree/main/pkg/custom/controller_runtime)
* [采用 Kubebuilder 的源代码](https://github.com/zhaohuabing/kubebuilderexample)







