# Netty 源码分析

## 启动分析

首先走一遍仅仅使用 NIO 启动一个服务端的过程

```java
// 创建 selector，在 netty 中存在于 NioEventLoopGroup 封装线程和 selector
Selector selector = Selector.open();

// 创建 Netty 层面的 Channel，同时初始化相关联的 Channel 以及为原生的 ssc 存储 config
NioServerSocketChannel attachment = new NioServerSocketChannel();

// 创建 NioServerSocketChannel 时，创建了 java 原生的 ServerSocketChannel
ServerSocketChannel serverSocketChannel = ServerSocketChannel.open();
serverSocketChannel.configureBlocking(false);

// 启动 nio boss 线程执行接下来操作
// 注册，仅关联 selector 和 NioServerSocketChannel，未关注事件
serverSocketChannel.register(selector, 0, attachment);

// head -> 初始化器 -> ServerBootstrapAcceptor -> tail， 初始化器只是一次性的，只为了添加 acceptor
// bind 端口
serverSocketChannel.bind(new InetSocketAddress(8080));
// 触发 channel active 事件，在 head 中关注 op_accept事件
selectionKey.interestOps(SelectionKey.OP_ACCEPT);
```

启动步骤，通过代码可以分为三个部分：

```java
AbstractBootstrap#bind() -> AbstractBootstrap#doBind()
private ChannelFuture doBind(final SocketAddress localAddress) {
        // 返回的是 ChannelFuture，说明这个操作是异步初始化的
        // 这个方法集合了创建 channel、初始化 channel、注册 channel 参数
        final ChannelFuture regFuture = initAndRegister();
        final Channel channel = regFuture.channel();
        // 判断 future 的 cause，从而确认是否发生异常，如果有异常直接返回
        if (regFuture.cause() != null) {
            return regFuture;
        }
        // 判断 initAndRegister 是否已经完成
        if (regFuture.isDone()) {
            // 如果已经完成，调用 doBind0 进行 socket 绑定
            // At this point we know that the registration was complete and successful.
            ChannelPromise promise = channel.newPromise();
            doBind0(regFuture, channel, localAddress, promise);
            return promise;
        } else {
            // Registration future is almost always fulfilled already, but just in case it's not.
            // 没有完成（done）
            final PendingRegistrationPromise promise = new PendingRegistrationPromise(channel);
            // 注册监听器，在 future 完成后回调 operationComplete方法
            regFuture.addListener(new ChannelFutureListener() {
                @Override
                public void operationComplete(ChannelFuture future) throws Exception {
                    // 还是要判断是否出现异常，如果有异常就设置 failure，如果没有，就设置 registered，并进行 doBind0
                    Throwable cause = future.cause();
                    if (cause != null) {
                        // Registration on the EventLoop failed so fail the ChannelPromise directly to not cause an
                        // IllegalStateException once we try to access the EventLoop of the Channel.
                        promise.setFailure(cause);
                    } else {
                        // Registration was successful, so set the correct executor to use.
                        // See https://github.com/netty/netty/issues/2586
                        promise.registered();

                        doBind0(regFuture, channel, localAddress, promise);
                    }
                }
            });
            return promise;
        }
    }
```



1. initAndRegister()

    1.1 init <font color=red>mian 线程</font>

    * 创建 NioServerSocketChannel <font color=red>mian 线程</font>

    * 添加 NIOServerSocketChannel 初始化 handler <font color=red>mian 线程</font>

    * 初始化 handler 等待调用 <font color=blue>nio 线程</font>

        向 nio ssc 加入了 acceptorHandler（在 accept 事件发生后建立连接）

    1.2 register

    * 启动 nio boss 线程 <font color=red>mian 线程</font>
    * 原生 ssc 注册至 selector 未关注事件 nio-thread <font color=blue>nio 线程</font>
    * 执行 NioServerSocketChannel 初始化 handler <font color=blue>nio 线程</font>

2. doBind0() 大多数情况存在于 <font color=blue>nio 线程</font>

    * 原生 ServerSocketChannel 绑定 <font color=blue>nio 线程</font>
    * 触发 NioServerSocketChannel active 事件 <font color=blue>nio 线程</font>

### initAndRegister()

```java
AbstractBootstrap#initAndRegister
final ChannelFuture initAndRegister() {
        Channel channel = null;
        try {
            channel = channelFactory.newChannel();

            init(channel);
        } catch (Throwable t) {
           	...
        }
        // 进行 register 操作，将 channel 注册到 boss group 的 EventLoop 的 selector 上，
        ChannelFuture regFuture = config().group().register(channel);
        ...

        return regFuture;
    }
```

如代码所示，``initAndRegister()``方法首先调用`channelFactory.newChannel()`创建一个 channel（Netty），拿到 channel 后；调用`init()`方法初始化 channel，设置channel 的属性，向 channel的 pipeline 中添加 handler；最后通过 `register()`将 channel 注册到 EventLoop 的 selector 中。接下来分析每个方法的具体功能。

#### newChannel()

```java
	ReflectiveChannelFactory#newChannel
	public T newChannel() {
        try {
            return constructor.newInstance();
        } catch (Throwable t) {
            ...
        }
    }
```

如代码所示，通过反射创建 channel，那么是什么时候知道 channel 的类型的？其实是在服务端配置 channel 时候传入 channel 类型的时候

```java
public B channel(Class<? extends C> channelClass) {
    return channelFactory(new ReflectiveChannelFactory<C>(
            ObjectUtil.checkNotNull(channelClass, "channelClass")
    ));
}
```

继续查看如何创建 channel 的，接下来的调用栈比较多，不过可以看出来 channel 的继承关系。

```java
NioServerSocketChannel#NioServerSocketChannel
public NioServerSocketChannel() {
        this(newSocket(DEFAULT_SELECTOR_PROVIDER));
    }
	
NioServerSocketChannel#NioServerSocketChannel
public NioServerSocketChannel(ServerSocketChannel channel) {
        super(null, channel, SelectionKey.OP_ACCEPT);
        config = new NioServerSocketChannelConfig(this, javaChannel().socket());
    }

AbstractNioMessageChannel#AbstractNioMessageChannel
protected AbstractNioMessageChannel(Channel parent, SelectableChannel ch, int readInterestOp) {
        super(parent, ch, readInterestOp);
    }

AbstractNioChannel#AbstractNioChannel
protected AbstractNioChannel(Channel parent, SelectableChannel ch, int readInterestOp) {
        super(parent);
        this.ch = ch;
        // 设置感兴趣的事件
        this.readInterestOp = readInterestOp;
        // 设置为非阻塞模式
        try {
            ch.configureBlocking(false);
        } catch (IOException e) {
            ...
        }
    }

AbstractChannel#AbstractChannel
protected AbstractChannel(Channel parent) {
        this.parent = parent;
        // channel 全局唯一 id
        id = newId();
        // unsafe 操作底层读写
        unsafe = newUnsafe();
        //pipeline 负责处理器连接
        pipeline = newChannelPipeline();
    }
```

由此可见 NioServerSocketChannel 的继承关系：

<img src="https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/img/202112141025563.png" alt="image-20211214102516498" style="zoom:100%;" />

当然每个父类关注的事情不同，实现的功能也不相同：

1. NioServerSocketChannel 类构造方法主要做的是：
    * 创建 channel（Nio）
    * 配置 NioServerSocketChannel 的配置
2. AbstractNioChannel 的构造方法主要做的是：
    * 设置子类传来的 parent 属性
    * 设置感兴趣的事件
    * 设置为非阻塞
3. AbstractChannel 的构造方法主要做的是：
    * 设置 channel 的 id
    * 创建 unsafe 类，用于以后的内存访问等操作。
    * 创建 pipeline 流水线



经过以上的分析，就可以得到`newChannel()`方法的创建流程：是在serverBootstrap配置 channel 的时候，传入 channel 的类型，之后调用 `newChannel` 会通过反射创建。此时，调用 NioServerSocketChannel 的构造方法，进入上面的调用栈。



#### init(channel)

```java
ServerBootstrap#init
void init(Channel channel) {
	// 设置若干配置...省略
	...
	ChannelPipeline p = channel.pipeline();
    p.addLast(new ChannelInitializer<Channel>() {
        @Override
        public void initChannel(final Channel ch) {
            final ChannelPipeline pipeline = ch.pipeline();
            ChannelHandler handler = config.handler();
            if (handler != null) {
                pipeline.addLast(handler);
            }
            ch.eventLoop().execute(new Runnable() {
                @Override
                public void run() {
                    pipeline.addLast(new ServerBootstrapAcceptor(
                            ch, currentChildGroup, currentChildHandler, currentChildOptions, currentChildAttrs));
                }
            });
        }
    });
}
```

如代码所示，`init()`方法首先会将 channel 的若干配置以及Bootstrap 的配置一并设置好，然后向 channel 的 pipeline 上添加一个 handler，这个 handler 用于在 channel 的初始化，一旦使用过一次，就会被移除，具体的实现需要之后才能看到。

可以先看一下 `initChannel` 的代码，先从 config 拿出 handler 添加到channel 的 pipeline，然后再向 pipeline 异步添加一个 ServerBoostrapAcceptor，用于建立连接。

#### register(channel)

`register(channel)`方法作用是将创建好的 NioServerSocketChannel 注册到 boss 的 selector 上，监听事件。

```java
MultithreadEventLoopGroup#register(io.netty.channel.Channel)
public ChannelFuture register(Channel channel) {
    return next().register(channel);
}

SingleThreadEventLoop#register(io.netty.channel.Channel)
public ChannelFuture register(Channel channel) {
        // 将 channel 和当前的 EventLoop(Executor) 封装到一个 Promise 中
        return register(new DefaultChannelPromise(channel, this));
    }

SingleThreadEventLoop#register(io.netty.channel.ChannelPromise)
public ChannelFuture register(final ChannelPromise promise) {
        ObjectUtil.checkNotNull(promise, "promise");
        // 通过 promise 中 channel 的 unsafe 类进行真正的注册操作
        promise.channel().unsafe().register(this, promise);
        return promise;
}
```

从中可以看出，`register(channel)`方法调用栈也是很复杂的。从 bootstrap 到 group 再到 loop 最后到 loop 的 channel。整个调用链突出一个从大到小。最后查看 channel 的 register 方法

```java
public final void register(EventLoop eventLoop, final ChannelPromise promise) {
    // 省略不重要的验证代码
    ...
    
    AbstractChannel.this.eventLoop = eventLoop;
    
    if (eventLoop.inEventLoop()) {
        register0(promise);
    } else {
        try { // execute 方法会在第一次执行的时候启动线程，相当于一种懒加载的行为
            eventLoop.execute(new Runnable() {
                @Override
                public void run() {
                    register0(promise);
                }
            });
        } catch (Throwable t) {
            ...
        }
    }
}
```

`register0`方法就是最终要调用的方法，在此之前，我们发现有一个 `eventLoop.inEventLoop()` 的判断，这个是用来判断当前执行的线程是否和 EventLoop 的线程相同。如果不同，则进入到 EventLoop 的线程执行 register。所以说，`register0()`方法要向执行，必须要在 Nio 的线程中（EventLoop 线程）执行。

由于之前所有的方法都是在 main 方法中执行，所以需要跳转到 `execute` 方法中执行，先关注`register()`方法。`execute` 方法之后一起说。

```java
private void register0(ChannelPromise promise) {
    try {
        
        doRegister();
        
        pipeline.invokeHandlerAddedIfNeeded();
        
        safeSetSuccess(promise);
        pipeline.fireChannelRegistered();
        
        if (isActive()) { 
            if (firstRegistration) {
                pipeline.fireChannelActive();
            } else if (config().isAutoRead()) {
                beginRead();
            }
        }
    } catch (Throwable t) {
        
    }
}
```

省略不重要代码后，`register0()`方法就可以分为这几个重要方法了，由于 if 判断块的代码一般用于 NioSocketChannel，所以可以先不关注。