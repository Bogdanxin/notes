# 基于 Seata 的分布式事务管理



## 理论基础

### CAP 定理

Consistency（一致性）：用户访问分布式系统中的任意节点，得到的数据必须一致

Availability（可用性）：用户访问集群中任意健康节点，必须能得到响应，而不是超时或者拒绝

Partition（分区）：因为网络故障或者其他原因导致分布式系统中的部分节点与其他节点失去连接，形成独立分区。



![image](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220226213322729.png)

为什么 cap 中只能由两个特性共存呢？

首先，分区是一定会产生的，因为分布式系统的特点就决定了如果出现问题就会导致出现分区。那么如果我们需要保证一致性，两个分区之间数据是无法进行交流的，那么只能使所有分区不接受新数据从而保证数据一致性，但是不能接受新数据就表明这个服务是不可用的，所以 AP 是不可以和 C 共存；如果要保证可用性，同理，只能接收数据的读写，分区之间的数据不一致就会出现；如果一定要 CA，那么只能取消掉分区才能保证，那么也就不再是事务了。

### BASE 理论

BASE 理论是对 CAP 的一种解决思路

* Basically Available（基本可用）：分布式系统在出现故障时，允许损失部分可用性，保证核心可用。
* Soft State（软状态）：一定时间内，允许出现中间状态，比如临时不一致状态
* Eventually Consistent（最终一致性）：虽然无法保证强一致性，但在软状态结束后，最终达到数据一致性。

而分布式事务最大的问题是各个子事务的一致性问题，因此可以借鉴CAP定理和BASE理论：

* AP模式：各子事务分别执行和提交，允许出现结果不一致，然后采用弥补措施恢复数据即可，实现最终一致
* CP模式：各个子事务执行后互相等待，同时提交，同时回滚，达成强一致。但事务等待过程中，处于弱可用状态。

为了解决分布式事务，需要各个子系统之间能够感知到彼此的事务状态，才能保证状态一致性，需要一个**事务协调者**来协调事务。子系统事务称为**分支事务**，各个分支事务合并称为**全局事务**

## Seata 架构

Seata 事务管理中有三个重要角色：

* TC（Transaction Coordinator） - 事务协调者：维护全局和分支事务的状态，协调全局事务提交或者回滚
* TM（Transaction Manager）- 事务管理器：定义全局事务范围、开始全局事务、提交或回滚全局事务
* RM（Resource Manager）- 资源管理器：管理分支事务处理的资源，与 TC 交谈以注册分支事务和报告分支事务的状态，并驱动分支事务提交或者回滚。

![image-20220227210858168](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220227210858168.png)

## Seata 四种分布式模式

### XA 模式

**XA 规范**是 X/Open 组织定义的分布式事务处理（DTP，Distributed Transaction Processin）标准，XA 规范描述了全局的 TM与局部的RM之间的接口，几乎所有主流的数据库都对 XA 规范 提供了支持。

![image-20220301104106287](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220301104106287.png)

其实就是利用了数据库自行提供的 XA 规范实现，来实现强一致性分布式事务。     

seata 的实现是在数据库基础上进行简单封装 :

![image-20220301104353053](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220301104353053.png)

XA模式的优点是：

* 事务的强一致性，满足ACID原则。
* 常用数据库都支持，实现简单，并且没有代码侵入

XA模式的缺点是:

* 因为一阶段需要锁定数据库资源，等待二阶段结束才释放，性能较差
* 依赖关系型数据库实现事务

#### 实现 XA 模式

1. 在每个实现分布式事务的服务上配置设置 XA 模式

    ```yaml
    seate:
    	data-source-proxy-mode: XA
    ```

2. 给发起全局事务的入口方法添加 @GlobalTransaction 注解

    ```java
    	@GlobalTransactional
        public Long create(Order order) {
    
            // 创建订单
            orderMapper.insert(order);
           	// 远程调用其他事务
            accountClient.deduct(order.getUserId(), order.getMoney());
            // 远程调用其他事务
            storageClient.deduct(order.getCommodityCode(), order.getCount());
    
            return order.getId();
        }
    ```

### AT 模式

#### 介绍

AT 模式同样是分阶段提交的事务模型，不过弥补了 XA 模型中资源锁定周期过长的缺陷，利用快照进行事务的回滚。

阶段一：

* 注册分支事务
* 记录 undo-log（数据快照)
* 执行业务 sql 并提交
* 报告事务状态给 TC

阶段二，进行提交时的工作：

* 删除 undo-log 即可工作

阶段二，回滚时进行的工作：

* 根据 undo-log 恢复数据，然后再删除 undo-log

![image-20220301132939586](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220301132939586.png)

简述AT模式与XA模式最大的区别是什么？

* XA模式一阶段不提交事务，锁定资源；AT模式一阶段直接提交，不锁定资源。
* XA模式依赖数据库机制实现回滚；AT模式利用数据快照实现数据回滚。
* XA模式强一致；AT模式最终一致



> AT 如何解决脏写和全局锁的死锁问题，重新看[视频](https://www.bilibili.com/video/BV1LQ4y127n4?p=149&t=1382.7)

AT模式的优点：

* 一阶段完成直接提交事务，释放数据库资源，性能比较好
* 利用全局锁实现读写隔离
* 没有代码侵入，框架自动完成回滚和提交

AT模式的缺点：

* 两阶段之间属于软状态，属于最终一致
* 框架的快照功能会影响性能，但比XA模式要好很多

#### 使用方法

需要在 TC 服务新建一张表 lock_table，在每个微服务数据库中新建一张 redo_log 的表。

### TCC 模式

TCC 模式与 AT 模式很相似，每个阶段都是独立事务，不同的是 TCC 通过人工编码来实现数据恢复，实现最终一致：

* Try：资源的监测和预留
* Confirm：完成资源的操作业务；要求 Try 成功那么 Confirm 一定成功
* Cancel：预留资源释放，可以理解为 try 的反向操作

![image-20220301140159095](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220301140159095.png)

特点：

1. 在一致性上，由于整个事务是不加锁的，所以在一阶段是没有办法保证事务的一致性的，只有在二阶段进行提交或者回滚才能够保证
2. 在隔离性上，由于每个事务操作的数据都是按照冻结金额进行控制，所以事务之间是相互隔离的。而 AT 模式需要通过设置锁来保证阶段一和阶段二能够一并执行不受其他事务影响。所以性能上 TCC 会优于 AT

TCC 的执行流程：

![image-20220301141358953](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220301141358953.png)

#### 优缺点：

TCC的优点是什么？

* 一阶段完成直接提交事务，释放数据库资源，性能好
* 相比AT模型，无需生成快照，无需使用全局锁，性能最强不依赖数据库事务，而是依赖补偿操作，可以用于非事务型数据库

TCC的缺点是什么？

* 有代码侵入，需要人为编写try、Confirm和Cancel接口，太麻烦
* 软状态，事务是最终一致
* 需要考虑Confirm和Cancel的失败情况，做好幂等处理

#### TCC 的空回滚和业务悬挂 

![image-20220301141937382](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220301141937382.png)

所以如果实现 TCC 模式，需要自己编写相关的逻辑，实现 TRY CONFIRM、CANCEL 逻辑，还要保证避免空回滚和业务悬挂

### Saga 模式

Saga模式是SEATA提供的长事务解决方案。也分为两个阶段：

* 一阶段：直接提交本地事务
* 二阶段：成功则什么都不做；失败则通过编写补偿业务来回滚

优点：

* 事务参与者可以基于事件驱动实现异步调用，吞吐高
* 一阶段直接提交事务，无锁，性能好
* 不用编写TCC中的三个阶段，实现简单

缺点：

* 软状态持续时间不确定，时效性差
* 没有锁，没有事务隔离，会有脏写



### 总结

![image-20220301144657551](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220301144657551.png)