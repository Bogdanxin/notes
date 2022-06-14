# Nacos 底层分析

## Nacos 的注册表结构

nacos 的注册表结构如下图所示：

![image-20220301203249670](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220301203249670.png)

对应在 Nacos 源代码中，是 map:

```
 在ServiceManager 类： Map<String, Map<String, Service>> --> Map(namespace, Map(group::serviceName, Service))
Service 类：Map<String, Cluster> --> Map(clusterName, Cluster)
Cluster 类：Set<Instance> persistentInstances 和 Set<Instance> ephemeralInstances 分别代表持久化实例和非持久化实例
```

Nacos采用了数据的分级存储模型，最外层是Namespace，用来隔离环境。然后是Group，用来对服务分组。接下来就是服务（Service）了，一个服务包含多个实例，但是可能处于不同机房，因此Service下有多个集群（Cluster），Cluster下是不同的实例（Instance）。

## 服务的注册

nacos 如何支撑数十万的服务注册服务？

1. 利用 nacos 集群，一同抗衡
2. 利用异步处理的方式：Nacos 内部接收到临时节点的注册请求后，进行服务的注册，并且将最耗费时间和性能的「发布注册服务到其他的服务」、「将注册的服务同步到其他的 nacos 服务器」这两个过程交给两个阻塞队列，通过其他线程异步从阻塞队列中取出任务并执行。

## nacos 避免并发读写冲突

并发读写：Nacos 在解决并发读写冲突时，利用了 CopyOnWrite 技术，首先会将原来旧的注册列表拷贝一份，然后在此基础上进行写操作（进行注册操作），其他执行读操作的「服务」还是读取的旧的注册表，当注册完毕后，会将修改好的注册列表覆盖到旧的注册列表。这样就保证不会出现读写冲突了。

并发写：Nacos 在对同一个服务进行写操作的时候，会对「服务」对象加锁，保证同一个服务的不同实例在 nacos 中进行注册时，串行化执行；同时，不同服务之间的注册时互不影响的，所以不会出现冲突。





## Nacos 与 Eureka 共同点和区别

Nacos与Eureka有相同点，也有不同之处，可以从以下几点来描述：

* 接口方式：Nacos与Eureka都对外暴露了Rest风格的API接口，用来实现服务注册、发现等功能
* 实例类型：Nacos的实例有永久和临时 实例之分；而Eureka只支持临时实例
* 健康检测：Nacos对临时实例采用 client 发送心跳模式检测，对永久实例采用nacos 服务端主动请求来做心跳检测；Eureka只支持心跳模式
* 服务发现：Nacos支持定时拉取和订阅推送两种模式；Eureka只支持定时拉取模式

定时拉取和订阅推送分别在 client 端和 server 端进行。client 端先从本地缓存拉取服务列表，如果没有然后再向服务端定时拉取。server 端除了响应 client 端的请求，也做了异步操作，在服务列表发生修改时，向订阅的服务push 服务列表，可以关注 ApplicationEvent 接口。

> 基于 udp 的发送，为什么？
>
> 1. 因为我们的 nacos 属于集群，面对的服务端也是多台机器，udp 更符合我们的需求
> 2. udp 头只有 8字节，数据消耗少，我们发送的信息数据也不多，使用 tcp 可能头就比数据量大
> 3. udp 不保证安全性，但是在我们应用上层对 udp 进行了安全性检测保证了能够可靠的接收