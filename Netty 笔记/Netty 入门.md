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
			public void operationComplete(ChannelFuture future) throws Exception {
				Channel channel = future.channel();
				log.debug("{}", channel);
				channel.writeAndFlush("123");
			}
		});
	}
}
```

1. 在 ChannelFuture 对象调用 `sync`方法，该方法会阻塞当前线程，直到成功建立连接，这时候再获取到的就是建立好连接的 channel
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

