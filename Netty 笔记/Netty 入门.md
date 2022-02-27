# Netty 入门

## 基本操作

### 服务端

```java
public class HelloServer {
    public static void main(String[] args) {
        new ServerBootstrap()
				.group(new NioEventLoopGroup())
				.channel(NioServerSocketChannel.class)
				.childHandler(new ChannelInitializer<NioSocketChannel>() {
					@Override
					protected void initChannel(NioSocketChannel ch) throws Exception {
						ch.pipeline().addLast(new StringDecoder());
						ch.pipeline().addLast(new ChannelInboundHandlerAdapter() {
							@Override
							public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
								System.out.println(msg);
							}
						});
					}
				})
				.bind(8080);
    }
}
```

1. ServerBootstrap 是启动器，负责 netty 服务器的启动
2. NioEventLoopGroup 代表着 boss 或者 worker 的 group，可以理解为 selector 和 thread 的集合
3. channel 是用来指定这个服务器创建连接使用的是哪种类型的 SocketChannel
4. childHandler 用来指定 worker 的能执行哪些操作（用 handler 执行操作）
5. ChannelInitializer 本质也是一个 handler，不过它的作用是在 initChannel 中将 handler 注册到 channel 上，以后可以执行操作
6. StringDecoder 是 ByteBuf 解析器，将 ByteBuf 解析为 String，ChannelInBoundHandlerAdapter 是自定义 handler

### 客户端

```java
public class HelloClient {

   public static void main(String[] args) throws InterruptedException {

      new Bootstrap()
            .group(new NioEventLoopGroup())
            .channel(NioSocketChannel.class)
            .handler(new ChannelInitializer<NioSocketChannel>() {

               @Override
               protected void initChannel(NioSocketChannel ch) throws Exception {
                  ch.pipeline().addLast(new StringEncoder());
               }
            })
            .connect(new InetSocketAddress("localhost", 8080))
            .sync()
            .channel()
            .writeAndFlush("hello");
   }
}
```

1. 也是创建 Bootstrap，不过这次是客户端的
2. 指定建立连接使用的 channel 类型
3. 添加 handler，声明初始化 handler 的方法，对应 childHandler；对应 StringDecoder 的是 StringEncoder
4. 建立连接，调用`sync`方法，`channel`方法。`sync`方法作用是阻塞客户端，直到成功建立连接，`channel` 方法作用是返回连接建立的 channel 对象。
5.  `writeAndFlush`方法发送数据。发送的数据都要走 handler 处理，在客户端就是 StringEncoder 把hello 字符串转为 ByteBuf，客户端的 handler 会对 ByteBuf 解析



> 一开始需要树立正确的观念
>
> * 把 channel 理解为数据的通道
> * 把 msg 理解为流动的数据，最开始输入是 ByteBuf，但经过 pipeline 的加工，会变成其它类型对象，最后输出又变成 ByteBuf
> * 把 handler 理解为数据的处理工序
>     * 工序有多道，合在一起就是 pipeline，pipeline 负责发布事件（读、读取完成...）传播给每个 handler， handler 对自己感兴趣的事件进行处理（重写了相应事件处理方法）
>     * handler 分 Inbound 和 Outbound 两类，入站和出站
> * 把 eventLoop 理解为处理数据的工人
>     * 工人可以管理多个 channel 的 io 操作，并且一旦工人负责了某个 channel，就要负责到底（绑定），这是为了线程安全。
>     * 工人既可以执行 io 操作，也可以进行任务处理，每位工人有任务队列，队列里可以堆放多个 channel 的待处理任务，任务分为普通任务、定时任务
>     * 工人按照 pipeline 顺序，依次按照 handler 的规划（代码）处理数据，可以为每道工序指定不同的工人

## 组件

### EventLoop 和 EventLoopGroup

#### EventLoop

EventLoop 维护了一个 selector，用来监听事件，另外同时本质就是一个单线程执行器，用来执行建立连接后操作

继承关系：

* 继承自 juc 下的`ScheduledExecutorService`，包含线程池的所有方法，并且可以定时运行
* 同时继承自 netty 自己定义的 `OrderedEventExecutor`
    * 提供 `boolean inEventLoop(Thread thread)` 判断线程是否属于此 eventLoop
    * 提供`parent`方法判断自己属于那个 EventLoopGroup

#### EventLoopGroup

EventLoopGroup 是一组 EventLoop，Channel 一般会调用 `register`方法注册到 group 中的某个 EventLoop 中，并且 channel 之后的所有 io 事件都由此 EventLoop 处理（保证了io 事件处理的线程安全）

继承关系：

* 继承自``EventExecutorGroup``
    * 实现了 Iterable 接口，提供遍历 group 的能力
    * 有 next 方法获取下一个 EventLoop 能力

#### 简单使用方法

```java
@Slf4j
public class TestEventLoop {

	public static void main(String[] args) {
		// 1. 创建事件循环组
		EventLoopGroup group = new NioEventLoopGroup(2);
		// 2. 获取下个事件循环对象
		System.out.println(group.next());
		System.out.println(group.next());
		System.out.println(group.next());
		System.out.println(group.next());

		// 3. 执行普通任务
		group.next().submit(() -> {
			try {
				Thread.sleep(1000);
			} catch (InterruptedException e) {
				e.printStackTrace();
			}
			log.debug("ok");
		});
		

		// 4. 定时任务
		group.next().scheduleAtFixedRate(() -> {
			log.debug("ok");
		}, 0, 1, TimeUnit.SECONDS);

		log.debug("ok");
	}
}

public class EventLoopClient {

	public static void main(String[] args) throws InterruptedException {


		ChannelFuture future = new Bootstrap()
				.group(new NioEventLoopGroup())
				.channel(NioSocketChannel.class)
				.handler(new ChannelInitializer<NioSocketChannel>() {
					@Override
					protected void initChannel(NioSocketChannel ch) throws Exception {
						ch.pipeline().addLast(new StringEncoder());
					}
				})
				.connect(new InetSocketAddress(8080));
		future.sync();
		Channel channel = future.channel();
		channel.writeAndFlush("123");
		System.out.println("");
	}
}

```

#### 细化 group 类型

```java
public class EventLoopServer {

   public static void main(String[] args) {

      EventLoopGroup group = new DefaultEventLoopGroup();

      new ServerBootstrap()
            .group(new NioEventLoopGroup(), new NioEventLoopGroup(2))
            .channel(NioServerSocketChannel.class)
            .childHandler(new ChannelInitializer<NioSocketChannel>() {
               @Override
               protected void initChannel(NioSocketChannel ch) throws Exception {
                  ch.pipeline().addLast("handler1", new ChannelInboundHandlerAdapter() {
                     @Override
                     public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
                        ByteBuf byteBuf = (ByteBuf) msg;
                        log.debug(byteBuf.toString(Charset.defaultCharset()));
                        ctx.fireChannelRead(msg);
                     }
                  });
                  ch.pipeline().addLast(group, "handler", new ChannelInboundHandlerAdapter() {
                     @Override
                     public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
                        ByteBuf byteBuf = (ByteBuf) msg;
                        log.debug(byteBuf.toString(Charset.defaultCharset()));
                     }
                  });
               }
            })
            .bind(8080);
   }
}
```

1. 首先可以将 group 分为两种，一种专门接收 accept 事件，另一种专门接收 read 和 write 事件，在代码中的体现就是在`group`方法中，同时注册两个 group，分为 boss 和 worker
2. 除此之外，还可以将负责 io 的 group 和进一步处理数据的 group 分开，用 DefaultEventLoopGroup 处理 io 之后的操作，代码中体现在 addLast 中。具体的操作，可以通过 handler 添加到 group 中。

#### handler 执行过程中如何切换不同的 group？

比如在上面，首先是 NioEventLoopGroup 的 handler，然后才是 DefaultEventLoopGroup 的 handler。

```java
/**
     * 这个方法用来切换不同 EventLoop 之间 handler，从而使得 handler 能够切换
     * @param next
     */
    static void invokeChannelActive(final AbstractChannelHandlerContext next) {
        // 1. 拿到下一个 EventLoop
        EventExecutor executor = next.executor();
        // 2. 下一个 EventLoop 如果和当前的在一个线程下，就直接递归调用继续执行
        if (executor.inEventLoop()) {
            next.invokeChannelActive();
        } else {
            // 3， 如果不是，将下个EventLoop 的方法包装起来，放到下个EventLoop的线程池中执行
            executor.execute(new Runnable() {
                @Override
                public void run() {
                    next.invokeChannelActive();
                }
            });
        }
    }

```

### Channel

channel的主要 api 

* `close()`可以关闭 channel
* `closeFuture()`用来处理 channel 的关闭
    * `sync`方法用于同步等待
    * `addListener`用于异步等待
* `pipeline()`方法用于添加处理器handler
* `write()`将数据写入 channel 中
* `writeAndFlush()`将数据写入channel并刷出

### ChannelFuture

在理解 ChannelFuture 之前，先要了解 `connnect` 方法，这个方法由 main 线程调用，但是实际的建立连接的操作并不会在main 线程中执行，而是会在 io 线程中执行。这就是 `connect` 方法返回值为 ChannelFuture 类型的原因。同时，由于当前 main 线程并不会执行 connect 操作，所以之后的操作如果不等待 io 线程，就会导致还没有建立好连接，就已经获取 channel，进而没办法发送数据。

这时候就需要两种方法解决此类现象：

```java
@Slf4j
public class EventLoopClient {

	public static void main(String[] args) throws InterruptedException {

        
		// 带有 future 或者 promise 名称的类，都是配合异步方法使用，用来正确处理结果
		ChannelFuture future = new Bootstrap()
				.group(new NioEventLoopGroup())
				.channel(NioSocketChannel.class)
				.handler(new ChannelInitializer<NioSocketChannel>() {
					@Override
					protected void initChannel(NioSocketChannel ch) throws Exception {
						ch.pipeline().addLast(new StringEncoder());
					}
				})
				.connect(new InetSocketAddress(8080));
		// 使用 sync 方法同步处理结果
		// sync 方法会阻塞住当前线程，直到 nio 线程连接建立完毕
//		future.sync();
//		Channel channel = future.channel();
//		log.debug("{}",channel);
//		channel.writeAndFlush("123");

		future.addListener(new ChannelFutureListener() {
			@Override
            // 在 nio 线程建立好后会调用 operationComplete 方法
			public void operationComplete(ChannelFuture future) throws Exception {
				Channel channel = future.channel();
				log.debug("{}", channel);
				channel.writeAndFlush("123");
			}
		});
	}
}
```

1. 在 ChannelFuture 对象调用 `sync`方法，该方法会阻塞当前线程[main]，直到成功建立连接，这时候再获取到的就是建立好连接的 channel
2. 在 ChannelFuture 对象调用 `addListener`方法，传入一个 `ChannelFutureListener` 回调对象，重写 `operationComplete` 方法，这个方法会异步处理结果，这里的「异步」是将传入的回调方法交给其他线程执行，也就是说，当前线程执行到 `addListener` 方法就会继续执行，而回调方法会在连接建立后被调用


#### 零拷贝

注意，这里的「netty 的零拷贝」不是指的操作系统级别的「零拷贝」，而是 netty 为了减少 ByteBuf 的复制拷贝，特地创建的 api。主要意义就在于对一个 ByteBuf 可以切为（Slice）多个，但是整体引用还在一个，对于多个 ByteBuf，可以「合并」为一个，但是只是逻辑上的合并。

##### slice 方法

```java
ByteBuf buf = ByteBufAllocator.DEFAULT.buffer(10);
buf.writeBytes(new byte[] {'a', 'b', 'c', 'd', 'e','f', 'g', 'h', 'i', 'j'});
log(buf);

ByteBuf buf1 = buf.slice(0, 6);
ByteBuf buf2 = buf.slice(4, 6);
```

> 注意事项：
>
> 1. slice 是对原 ByteBuf 进行切片，所以当对一个 ByteBuf 切片成多个的时候，每个切片都是引用的原有同一个 ByteBuf，这就要注意如果原 ByteBuf 被修改，其他的切片也会有相应影响
> 2. 同上所述，如果几个 ByteBuf 切片有共同区域，那么修改同一个区域也会造成影响。

##### addComponent 方法

```java
ByteBuf buf1 = ByteBufAllocator.DEFAULT.buffer();
buf1.writeBytes(new byte[] {1, 2, 3, 4, 5});
ByteBuf buf2 = ByteBufAllocator.DEFAULT.buffer();
buf2.writeBytes(new byte[] {6, 7, 8, 9, 10});

CompositeByteBuf byteBuf = ByteBufAllocator.DEFAULT.compositeBuffer();
byteBuf.addComponents(true, buf1, buf2);

TestSlice.log(byteBuf);
```

#### CloseFuture

在客户端关闭连接之后，我们需要进行若干操作进行善后工作，但是 `channel.close()`方法是一个异步操作，也就是说，调用这个方法后，关闭连接的操作会交给其他线程操作，那么有可能就会导致善后操作提前于关闭连接，进而导致出现错误。所以我们引入了 **closeFuture**。

`closeFuture()`返回值也是一个 ChannelFuture 类对象，不过他代表的是关闭连接的异步操作。这时候就和上面的处理**建立连接**异步操作的方法一样，要么同步等待关闭连接，要么添加一个 listener 异步等待连接关闭。

```java
ChannelFuture closeFuture = channel.closeFuture();
// 方法一，线程阻塞同步等待
closeFuture.sync();
log.debug("执行关闭连接之后的操作");

// 方法二，新建 listener 异步等待
closeFuture.addListener(new ChannelFutureListener() {
    public void operationComplete(ChannelFuture future) throws Exception {
        log.debug("处理关闭之后的操作");
    }
});
```

### Future & Promise

异步处理时，常需要这两个接口，继承关系如上图所示

* jdk Future 接口只能够同步等待任务结束（成功或者失败）才能够返回结果。
* netty Future 接口可以同步（主线程调用 sync 方法）或者异步（`addListener` 方法）等待任务结束得到结果，但是都还是要等待任务结束
* netty Promise 接口不仅有 netty Future 的功能，而且脱离了任务独立存在，只作为两个线程之间传递结果的容器

> Future 可以理解为线程之间传递结果的容器，future 的结果是由产生结果的线程传递到 future 中，然后其他线程等待 future 获取到结果，再从 future 中获取结果，整个过程 future 是被动的接收。
>
> Promise 则是主动设置结果的容器，可以在线程执行过程中，主动（自己写代码）向 promise 容器中写入数据



```java
@Slf4j
public class TestJdkFuture {

	public static void main(String[] args) throws ExecutionException, InterruptedException {
		ExecutorService service = Executors.newFixedThreadPool(2);
		Future<Integer> fur = service.submit(new Callable<Integer>() {
			@Override
			public Integer call() throws Exception {
				Thread.sleep(1000);
				return 100;
			}
		});

		log.debug("等待结果...");
		log.debug("结果是 {}" , fur.get());
	}
}

@Slf4j
public class TestNettyFuture  {
	public static void main(String[] args) throws ExecutionException, InterruptedException {
		NioEventLoopGroup group = new NioEventLoopGroup();
		EventLoop eventLoop = group.next();
		Future<Integer> future = eventLoop.submit(new Callable<Integer>() {
			@Override
			public Integer call() throws Exception {
				log.debug("执行计算");
				Thread.sleep(1000);
				return 100;
			}
		});

		log.debug("等待结果");
		log.debug("结果为 {}", future.get());
//		future.addListener(new GenericFutureListener<Future<? super Integer>>() {
//			@Override
//			public void operationComplete(Future<? super Integer> future) throws Exception {
//				log.debug("接收结果:{}", future.getNow());
//			}
//		})
	}


}

@Slf4j
public class TestNettyPromise {
	
	public static void main(String[] args) throws ExecutionException, InterruptedException {
		// 1. 准备 EventLoopGroup
		EventLoop eventExecutors = new NioEventLoopGroup().next();

		// 2. 主动创建 promise
		DefaultPromise<Integer> promise = new DefaultPromise<>(eventExecutors);

		new Thread(() -> {
			log.debug("开始计算");
			try {
				Thread.sleep(1000);
				int i = 1 / 0;
				promise.setSuccess(123);
			} catch (Exception e) {
				e.printStackTrace();
				promise.setFailure(e);
			}

		}).start();

		log.debug("等待结果");
		log.debug("结果是 : {}", promise.get());
	}
}
```

### Handler & Pipeline

Handler 作为入站或者出站数据的处理器，是与 Pipeline 结合使用的。Handler 又分为 ChannelInboundHandlerAdpater（入站） 和 ChannelOutboundHandlerAdapter（出站）两种。

* 入站 handler 用于处理入站的数据，多重写 channelRead 方法

  注意点有：

  * 入站 handler 要想形成调用链，必须在每个 handler 重写的 channelRead 方法中调用 `super.channelRead` 方法或者调用`ctx.fireChannelRead`方法，这样才能够将每个 handler 处理的数据传递给下一个 handler。
  * 有些情况下，需要将数据处理完毕后发送给客户端，需要调用 `writeAndFlush` 方法发送给 outboundhandler。这里有两种发送方式，一种是调用 `initChannel` 方法入参的 channel 对象的 `writeAndFlush` 方法，另一种是调用 `channelRead`入参中 ctx 的`writeAndFlush` 方法。两种不同点是：
    * 前者会将所有的 InboundHandler 执行完，再反过来执行 OutboundHandler。也就是说，所有的入站出站 handler 都会走一遍。
    * 后者只会执行调用 `ctx.writeAndFlush`方法之前的 outboundHandler。也就是说，会遍历所有的 InboundHandler，OutBoundHandler 只会遍历调用之前的。

* 出站 handler 用于处理出站的数据，多重写 write 方法 



这里对 pipeline 的 InboundHandler 和 OutBoundHandler 的调用顺序以及 `writeAndFlush` 方法的区别测试狠详尽了

```java
@Slf4j
public class TestPipeline {
	public static void main(String[] args) {
		new ServerBootstrap()
				.group(new NioEventLoopGroup())
				.channel(NioServerSocketChannel.class)
				.childHandler(new ChannelInitializer<NioSocketChannel>() {
					@Override
					protected void initChannel(NioSocketChannel ch) throws Exception {
						// 1. 通过 channel 获取 pipeline
						ChannelPipeline pipeline = ch.pipeline();
						// 2. 添加处理器   head -> addHandler() -> tail
						pipeline.addLast("h1", new ChannelInboundHandlerAdapter() {
							@Override
							public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
								log.debug("1");
//								// super.channelRead 方法会将当前结果传递给下一个 handler
//								// 如果不调用，入站链会断开
								super.channelRead(ctx, msg);
								ctx.writeAndFlush(ctx.alloc().buffer().writeBytes("hello".getBytes()));
							}
						});
						pipeline.addLast("h4", new ChannelOutboundHandlerAdapter() {
							@Override
							public void write(ChannelHandlerContext ctx, Object msg, ChannelPromise promise) throws Exception {
								log.debug("4");
								super.write(ctx, msg, promise);
							}
						});
						pipeline.addLast("h2", new ChannelInboundHandlerAdapter() {
							@Override
							public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
								log.debug("2");
								super.channelRead(ctx, msg);

							}
						});


						pipeline.addLast("h5", new ChannelOutboundHandlerAdapter() {
							@Override
							public void write(ChannelHandlerContext ctx, Object msg, ChannelPromise promise) throws Exception {
								log.debug("5");
								super.write(ctx, msg, promise);
							}
						});
						pipeline.addLast("h3", new ChannelInboundHandlerAdapter() {
							@Override
							public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
								log.debug("3");
								super.channelRead(ctx, msg);
//								ctx.writeAndFlush(ctx.alloc().buffer().writeBytes("server...".getBytes()));
								ctx.writeAndFlush(ctx.alloc().buffer().writeBytes("server...".getBytes()));
							}
						});



						pipeline.addLast("h6", new ChannelOutboundHandlerAdapter() {
							@Override
							public void write(ChannelHandlerContext ctx, Object msg, ChannelPromise promise) throws Exception {
								log.debug("6");
								super.write(ctx, msg, promise);
							}
						});
					}
				})
				.bind(8080);
	}

}

```

### ByteBuf

#### 直接内存&堆内存

堆内存创建 ByteBuf

`ByteBuf buffer = ByteBufAllocator.DEFAULT.heapBuffer(10);`

直接内存创建 ByteBuf

`ByteBuf buffer = ByteBufAllocator.DEFAULT.directBuffer(10);`

* 直接内存创建销毁代价比较高，但是读写性能高（少一次内存复制），适合配合池化功能一起用
* 直接内存对 GC 压力小，因为不受 jvm 内存管理，但是也需要使用完毕后释放

#### 池化 & 非池化

池化的意义在于可以重用 ByteBuf，有以下优点：

* 没有池化，每次都得创建新的 ByteBuf 对象，操作对直接内存很昂贵，对堆内存gc 也不友好
* 有了池化会对 ByteBuf 重用，采用 jemalloc 的内存分配提高分配效率
* 高并发时，池化功能更减少内存消耗，降低内存溢出的风险

#### 扩容

扩容规则是：

* 如果写入数据小于 512，扩容容量为下一个 16 的倍数
* 如果写入数据大于 512，扩容容量为下一个 2^n
* 扩容容量不得超过最大容量

#### 读取

例如读了 4 次，每次一个字节

```java
System.out.println(buffer.readByte());
System.out.println(buffer.readByte());
System.out.println(buffer.readByte());
System.out.println(buffer.readByte());
log(buffer);
```

读过的内容，就属于废弃部分了，再读只能读那些尚未读取的部分

```
1
2
3
4
read index:4 write index:12 capacity:16
         +-------------------------------------------------+
         |  0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f |
+--------+-------------------------------------------------+----------------+
|00000000| 00 00 00 05 00 00 00 06                         |........        |
+--------+-------------------------------------------------+----------------+
```

如果需要重复读取 int 整数 5，怎么办？

可以在 read 前先做个标记 mark

```java
buffer.markReaderIndex();
System.out.println(buffer.readInt());
log(buffer);
```

结果

```
5
read index:8 write index:12 capacity:16
         +-------------------------------------------------+
         |  0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f |
+--------+-------------------------------------------------+----------------+
|00000000| 00 00 00 06                                     |....            |
+--------+-------------------------------------------------+----------------+
```

这时要重复读取的话，重置到标记位置 reset

```java
buffer.resetReaderIndex();
log(buffer);
```

这时

```
read index:4 write index:12 capacity:16
         +-------------------------------------------------+
         |  0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f |
+--------+-------------------------------------------------+----------------+
|00000000| 00 00 00 05 00 00 00 06                         |........        |
+--------+-------------------------------------------------+----------------+
```

还有种办法是采用 get 开头的一系列方法，这些方法不会改变 read index

#### 释放

由于 Netty 中有堆外内存的 ByteBuf 实现，堆外内存最好是手动来释放，而不是等 GC 垃圾回收。

* UnpooledHeapByteBuf 使用的是 JVM 内存，只需等 GC 回收内存即可
* UnpooledDirectByteBuf 使用的就是直接内存了，需要特殊的方法来回收内存
* PooledByteBuf 和它的子类使用了池化机制，需要更复杂的规则来回收内存

Netty 这里采用了引用计数法来控制回收内存，每个 ByteBuf 都实现了 ReferenceCounted 接口

* 每个 ByteBuf 对象的初始计数为 1
* 调用 release 方法计数减 1，如果计数为 0，ByteBuf 内存被回收
* 调用 retain 方法计数加 1，表示调用者没用完之前，其它 handler 即使调用了 release 也不会造成回收
* 当计数为 0 时，底层内存会被回收，这时即使 ByteBuf 对象还在，其各个方法均无法正常使用

##### release 的时机？

一般情况下，不能够直接通过 try-catch-finally 直接释放，因为 pipeline 上有多个 handler，每个 handler 都有可能获取上一个传递过来的 ByteBuf，这时候如果前一个 handler 释放了 ByteBuf，后一个 handler 就没有可用的 ByteBuf，从而导致出现异常。所以负责释放 ByteBuf 的时机很重要。

基本规则是：谁最后使用，谁负责释放。

> * 起点，对于 NIO 实现来讲，在 io.netty.channel.nio.AbstractNioByteChannel.NioByteUnsafe#read 方法中首次创建 ByteBuf 放入 pipeline（line 163 pipeline.fireChannelRead(byteBuf)）
> * 入站 ByteBuf 处理原则
>   * 对原始 ByteBuf 不做处理，调用 ctx.fireChannelRead(msg) 向后传递，这时无须 release
>   * 将原始 ByteBuf 转换为其它类型的 Java 对象，这时 ByteBuf 就没用了，必须 release
>   * 如果不调用 ctx.fireChannelRead(msg) 向后传递，那么也必须 release
>   * 注意各种异常，如果 ByteBuf 没有成功传递到下一个 ChannelHandler，必须 release
>   * **假设消息一直向后传，那么 TailContext 会负责释放未处理消息（原始的 ByteBuf）**
> * 出站 ByteBuf 处理原则
>   * **出站消息最终都会转为 ByteBuf 输出，一直向前传，由 HeadContext flush 后 release**
> * 异常处理原则
>   * 有时候不清楚 ByteBuf 被引用了多少次，但又必须彻底释放，可以循环调用 release 直到返回 true
