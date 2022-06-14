# Redis 的缓存模式

[Redis与DB的数据一致性解决方案（史上最全）](https://www.cnblogs.com/crazymakercircle/p/14853622.html)

## 三个经典缓存模式

* Cache-Aside Pattern（旁路缓存模式）
* Read Through/ Write Through
* Write Behind

### Cache Aside Pattern

<center class="half">
    <img src="https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/20210522212436746.png" alt="img"/>
    <img src="https://img-blog.csdnimg.cn/20210522212459467.png" alt="img" style="zoom:150%" />
<center/>



**读流程：** 读的时候，先读缓存，如果没有读取到，再读取数据库，最后将读取到的数据存放到缓存。

**写流程：** 写的时候，先更新数据库，然后删除缓存旧的数据。之后的更新留给读操作。

#### 为什么更新缓存要先更新数据库？

### Write Through/ Read Through

在 Write Through/ Read Through 模式中，服务端把缓存作为主要数据存储。应用程序跟数据库缓存交互，都是通过**抽象缓存层**完成的。

<center class="half">
    <img src="https://img-blog.csdnimg.cn/20210522212527364.png" alt="img" style="zoom:35%;" />
    <img src="https://img-blog.csdnimg.cn/20210522212542188.png" alt="img" style="zoom:45%;" />
<center/>

**读流程：**和 Cache Aside 相似，现读缓存，如果缓存不存在，读数据库。但是这里为应用程序提供一个 Cache Provider 的中间层，为应用程序封装了读数据的操作，实现分层从而解耦。

**写流程：**和Cache Aside 也相似，不过也是通过 Provider 解决。最后的数据更新 cache 是 provider 主动提供的。

### Write behind

![ ](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/watermark%252Ctype_ZmFuZ3poZW5naGVpdGk%252Cshadow_10%252Ctext_aHR0cHM6Ly9ibG9nLmNzZG4ubmV0L3dqMTMxNDI1MA%253D%253D%252Csize_16%252Ccolor_FFFFFF%252Ct_70.png)

读操作和 Read Through 相似。写操作则大不同：Cache Provider 只会将数据更新到 cache，之后的数据库更新执行异步操作。

> 这就不能够保证数据安全性，一旦宕机，没有同步到 db 的数据就会全部消失，适用于写频繁的应用。

### 对比

Cache Aside 实现简单，但是需要同时操作两个数据源；Read/Write Through 需要维护一个 Provider，比较复杂；Write Bind 相对于前两个性能更好，因为只对数据在内存中进行存储，但是问题时不稳定，一旦宕机就会出现数据丢失的问题。

## 多级缓存

![image-20220305082137306](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220305082137306.png)

###  jvm 进程缓存

