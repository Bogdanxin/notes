# Netty 进阶

## 粘包和半包

由于使用的是 TCP/IP 协议，发送过程中，会将应用层发送的数据合并发送，导致发送过程中：1.将两个不同的数据包合并到一个数据流中发送；2.将一个较大的数据包分解发送。从而导致粘包和半包的现象的发生。

### TCP 的滑动窗口

TCP 以一个段（segment）为单位，每发送一个段就进行一次确认应答（ack），但是如果这样做，缺点就是往返的时间较长，所以为了解决此问题，就引入了**滑动窗口**的概念，窗口的大小就**决定了无需等待应答就可以继续发送的数据最大值。**

这样滑动窗口就起到了缓冲区的作用，也能起到流量控制的作用

* 数据处于滑动窗口中，即需要发送的数据，部分发送的数据需要接收相应
* 窗口内的数据才被允许发送，应答未到达前，窗口必须停止滑动
* 如果某个段的若干数据接收到响应，就可以继续向后滑动
* 接收方也需要维护一个窗口，只有落在窗口上的数据才会被接受

### 现象分析

粘包

* 现象，发送 abc def，接收 abcdef
* 原因
    * 应用层：接收方 ByteBuf 设置太大（Netty 默认 1024）
    * 滑动窗口：假设发送方 256 bytes 表示一个完整报文，但由于接收方处理不及时且窗口大小足够大，这 256 bytes 字节就会缓冲在接收方的滑动窗口中，当滑动窗口中缓冲了多个报文就会粘包
    * Nagle 算法：会造成粘包

半包

* 现象，发送 abcdef，接收 abc def
* 原因
    * 应用层：接收方 ByteBuf 小于实际发送数据量
    * 滑动窗口：假设接收方的窗口只剩了 128 bytes，发送方的报文大小是 256 bytes，这时放不下了，只能先发送前 128 bytes，等待 ack 后才能发送剩余部分，这就造成了半包
    * MSS 限制：当发送的数据超过 MSS 限制后，会将数据切分发送，就会造成半包（底层的网卡的限制）

### 解决方案

#### 短连接

发送端每次发送一个消息完毕，就将连接断开，接收端每次接收到的都是单独数据。

在 netty 中的实现就是将接收端的接收区设置的足够大，发送端数据每次发送完毕后断开连接，这样就能保证发送数据不会出现粘包。

但是，短连接不能保证半包问题，因为接收端的缓冲区没办法每次都很大，较大数据接收后，就会出现问题。并且每次发送数据后就断开连接，发送数据时导致反复建立连接，效率上也会很低，所以短连接并不适用。

#### 定长解码器 FixLengthFrameDecoder

`FixLengthFrameDecoder`类，定长解码器，也是一个 handler。

顾名思义，就是将发送端发送的数据长度固定下来，之后发送的所有数据长度都是固定的，同时接收端启用`FixLengthFrameDecoder`设置数据长度，那么之后发送端发送数据时，就必须每条数据固定好长度，之后就不必在意发送时的粘包或者半包现象了，因为都有定长解码器将半包、粘包根据定长解析出来。

```
固定长度 3
[1 2, 3 4 5 5, 6, 7 8 9 10] -> [1 2 3, 4 5 5, 6 7 8, 9 10 <null>]
```

代码演示：

```java
public class Server {

	public static void main(String[] args) {
		NioEventLoopGroup boss = new NioEventLoopGroup();
		NioEventLoopGroup worker = new NioEventLoopGroup();
		try {
			ServerBootstrap server = new ServerBootstrap();
			server.group(boss, worker)
					.channel(NioServerSocketChannel.class)
					.childHandler(new ChannelInitializer<NioSocketChannel>() {
						@Override
						protected void initChannel(NioSocketChannel ch) throws Exception {
                            // 解码器一定要在 loghandler 之前，因为需要先解码后 log 打印
							ch.pipeline().addLast(new FixedLengthFrameDecoder(10));
							ch.pipeline().addLast(new LoggingHandler(LogLevel.DEBUG));
						}
					});
			ChannelFuture sync = server.bind(8080).sync();
			sync.channel().closeFuture().sync();
		} catch (InterruptedException e) {
			e.printStackTrace();
		} finally {
			boss.shutdownGracefully();
			worker.shutdownGracefully();
		}
	}
}


```

```java
@Slf4j
public class Client2 {

   public static void main(String[] args) {
      send();
      System.out.println("finish");
   }

   private static void send() {
      NioEventLoopGroup worker = new NioEventLoopGroup();
      try {
         Bootstrap bootstrap = new Bootstrap();
         bootstrap.channel(NioSocketChannel.class)
               .group(worker)
               .handler(new ChannelInitializer<NioSocketChannel>() {
                  @Override
                  protected void initChannel(NioSocketChannel ch) throws Exception {
                     ch.pipeline().addLast(new LoggingHandler(LogLevel.DEBUG));
                     ch.pipeline().addLast(new ChannelInboundHandlerAdapter() {
                        @Override
                        public void channelActive(ChannelHandlerContext ctx) throws Exception {
                           ByteBuf buf = ctx.alloc().buffer();
                           char c = '0';
                           for (int i = 0; i < 10; i++) {
                              byte[] bytes = fill10Bytes(++c, i + 1);
                              buf.writeBytes(bytes);
                           }
                           ctx.writeAndFlush(buf);
                        }
                     });
                  }
               });
         ChannelFuture future = bootstrap.connect("localhost", 8080).sync();
         future.channel().closeFuture().sync();
      } catch (Exception e) {
         e.printStackTrace();
      } finally {
         worker.shutdownGracefully();
      }
   }

   private static byte[] fill10Bytes(char c, int len) {
      byte[] array = new byte[10];
      for (int i = 0; i < len; i++) {
         array[i] = (byte) c;
      }
      for (int i = len; i < 10; i++) {
         array[i] = '_';
      }
      log.debug("array --> {}", Arrays.toString(array));
      return array;
   }
}
```

缺点：很明显，由于所有的数据都是定长的，那么浪费空间的情况是很常见的。如果发送 1 个字节的数据也要定长 10 个字节，那么很浪费网络资源。

#### 分割符解析器

分别有两种：

LineBaseFrameDecoder：根据换行符进行解析，可以根据'\n' 或者 '\r\n' 两种换行符进行分割

DelimiterBasedFrameDecoder：根据指定的换行符进行分割

要注意的是，两者都是有最大分割长度的，因为不应该出现一直接收数据，但是不进行分割的情况。

```java
public class Server2 {

	public static void main(String[] args) {
		start();
	}

	private static void start() {
		NioEventLoopGroup boss = new NioEventLoopGroup();
		NioEventLoopGroup worker = new NioEventLoopGroup();
		try {
			ServerBootstrap boot = new ServerBootstrap();
			boot.group(boss, worker)
					.channel(NioServerSocketChannel.class)
					.childHandler(new ChannelInitializer<NioSocketChannel>() {
						@Override
						protected void initChannel(NioSocketChannel ch) throws Exception {
							ch.pipeline().addLast(new LineBasedFrameDecoder(1024));
							ch.pipeline().addLast(new LoggingHandler(LogLevel.DEBUG));
						}
					});

			ChannelFuture future = boot.bind(8080).sync();
			future.channel().closeFuture().sync();
		} catch (InterruptedException e) {
			e.printStackTrace();
		} finally {
			worker.shutdownGracefully();
			boss.shutdownGracefully();
		}
	}
}

public class Client2 {

	public static void main(String[] args) {
		send();
		System.out.println("finish");
	}

	private static StringBuilder makeString(char c, int len) {
		StringBuilder builder = new StringBuilder();
		for (int i = 0; i < len; i++) {
			builder.append(c);
		}
		builder.append('\n');
		return builder;
	}

	private static void send() {
		NioEventLoopGroup worker = new NioEventLoopGroup();
		try {
			Bootstrap boot = new Bootstrap();
			boot.group(worker)
					.channel(NioSocketChannel.class)
					.handler(new ChannelInitializer<NioSocketChannel>() {
						@Override
						protected void initChannel(NioSocketChannel ch) throws Exception {
							ch.pipeline().addLast(new LoggingHandler(LogLevel.DEBUG));
							ch.pipeline().addLast(new ChannelInboundHandlerAdapter() {
								@Override
								public void channelActive(ChannelHandlerContext ctx) throws Exception {
									ByteBuf buffer = ctx.alloc().buffer();
									char c = '0';
									Random random = new Random();
									for (int i = 0; i < 10; i++) {

										StringBuilder str = makeString(++c, random.nextInt(256));
										buffer.writeBytes(str.toString().getBytes(StandardCharsets.UTF_8));
									}

									ctx.writeAndFlush(buffer);
								}
							});
						}
					});

			ChannelFuture future = boot.connect("localhost", 8080).sync();
			future.channel().closeFuture().sync();

		} catch (InterruptedException e) {
			e.printStackTrace();
		} finally {
			worker.shutdownGracefully();
		}
	}
}
```

#### 基于长度字段的解码器 LengthFieldBasedFrameDecoder

主要有四个重要的字段用于解析：

1. lengthFieldOffset：数据的长度字段的偏移量（起始位置）
2. lengthFieldLength：指数据 length 属性的长度
3. lengthAdjustment：需要修正的长度，比如下面的例子，需要修正 length 之后的 HDR2 数据。那么就写入 HDR2 的长度
4. initialBytesToStrip：解析之后，需要去掉的长度。

```
lengthFieldOffset   = 1 (= the length of HDR1)
lengthFieldLength   = 2
lengthAdjustment    = 1 (= the length of HDR2)
initialBytesToStrip = 3 (= the length of HDR1 + LEN)

BEFORE DECODE (16 bytes)                       AFTER DECODE (13 bytes)
+------+--------+------+----------------+      +------+----------------+
| HDR1 | Length | HDR2 | Actual Content |----->| HDR2 | Actual Content |
| 0xCA | 0x000C | 0xFE | "HELLO, WORLD" |      | 0xFE | "HELLO, WORLD" |
+------+--------+------+----------------+      +------+----------------+
```

演示代码：

```java
public class TestLengthFieldDecoder {

	public static void main(String[] args) {
		EmbeddedChannel channel = new EmbeddedChannel(
				new LengthFieldBasedFrameDecoder(1024, 0, 4, 0, 0),
				new LoggingHandler(LogLevel.DEBUG)
		);

		ByteBuf buf = ByteBufAllocator.DEFAULT.buffer();
		writeBuf(buf, "hello, world!");
		writeBuf(buf, "hi!");
		channel.writeInbound(buf);
	}

	private static void writeBuf(ByteBuf buf, String message) {
		byte[] bytes = message.getBytes(StandardCharsets.UTF_8);
		int length = bytes.length;
		buf.writeInt(length);
		buf.writeBytes(bytes);
	}

}
16:03:12 [DEBUG] [main] i.n.h.l.LoggingHandler - [id: 0xembedded, L:embedded - R:embedded] READ: 17B
         +-------------------------------------------------+
         |  0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f |
+--------+-------------------------------------------------+----------------+
|00000000| 00 00 00 0d 68 65 6c 6c 6f 2c 20 77 6f 72 6c 64 |....hello, world|
|00000010| 21                                              |!               |
+--------+-------------------------------------------------+----------------+
16:03:12 [DEBUG] [main] i.n.h.l.LoggingHandler - [id: 0xembedded, L:embedded - R:embedded] READ: 7B
         +-------------------------------------------------+
         |  0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f |
+--------+-------------------------------------------------+----------------+
|00000000| 00 00 00 03 68 69 21                            |....hi!         |
+--------+-------------------------------------------------+----------------+
 
// 如果想要解析后去除掉长度字段，需要改动LengthFieldBasedFrameDecoder 的 initialBytesToStrip 字段
new LengthFieldBasedFrameDecoder(1024, 0, 4, 0, 4)

16:06:05 [DEBUG] [main] i.n.h.l.LoggingHandler - [id: 0xembedded, L:embedded - R:embedded] READ: 13B
         +-------------------------------------------------+
         |  0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f |
+--------+-------------------------------------------------+----------------+
|00000000| 68 65 6c 6c 6f 2c 20 77 6f 72 6c 64 21          |hello, world!   |
+--------+-------------------------------------------------+----------------+
16:06:05 [DEBUG] [main] i.n.h.l.LoggingHandler - [id: 0xembedded, L:embedded - R:embedded] READ: 3B
         +-------------------------------------------------+
         |  0  1  2  3  4  5  6  7  8  9  a  b  c  d  e  f |
+--------+-------------------------------------------------+----------------+
|00000000| 68 69 21                                        |hi!             |
+--------+-------------------------------------------------+----------------+
```

## 协议的设计和解析

### Redis 设计协议

`set name zhangsan`命令，

1. 首先向服务端发送数组元素个数：*3
2. 第一个元素(set字符串)的长度：$3，然后发送字符串 set  
3. 第二个元素(name字符串)长度：$4，然后发送字符串 name
4. 最后一个元素(zhangsan字符串)长度：$8，然后发送字符串 zhangsan

同时，每个元素之间需要换行符'\n'进行分割。

```java
public static void main(String[] args) {
   final byte[] LINE = {13, 10};
   NioEventLoopGroup worker = new NioEventLoopGroup();
   try {
      Bootstrap boot = new Bootstrap();
      boot.group(worker)
            .channel(NioSocketChannel.class)
            .handler(new ChannelInitializer<NioSocketChannel>() {
               @Override
               protected void initChannel(NioSocketChannel ch) throws Exception {
                  ch.pipeline().addLast(new LoggingHandler());
                  ch.pipeline().addLast(new ChannelInboundHandlerAdapter() {
                     @Override
                     public void channelActive(ChannelHandlerContext ctx) throws Exception {
                        ByteBuf buff = ctx.alloc().buffer();
                        buff.writeBytes("*3".getBytes());
                        buff.writeBytes(LINE);
                        buff.writeBytes("$3".getBytes());
                        buff.writeBytes(LINE);
                        buff.writeBytes("set".getBytes());
                        buff.writeBytes(LINE);
                        buff.writeBytes("$4".getBytes());
                        buff.writeBytes(LINE);
                        buff.writeBytes("name".getBytes());
                        buff.writeBytes(LINE);
                        buff.writeBytes("$8".getBytes());
                        buff.writeBytes(LINE);
                        buff.writeBytes("zhangsan".getBytes());
                        buff.writeBytes(LINE);
                        ctx.writeAndFlush(buff);
                     }

                     @Override
                     public void channelRead(ChannelHandlerContext ctx, Object msg) throws Exception {
                        ByteBuf buf = (ByteBuf) msg;
                        log.debug("{}", buf.toString(StandardCharsets.UTF_8));
                     }
                  });
               }
            });
      ChannelFuture future = boot.connect("localhost", 6379).sync();
      future.channel().closeFuture().sync();
   } catch (InterruptedException e) {
      e.printStackTrace();
   } finally {
      worker.shutdownGracefully();
   }
}
```



### HTTP解析器

使用`HTTPServerCodec`类，作为 handler 在服务端解析 http 请求。只需要在 bootstrap 中添加一个这样的 handler 即可。

`HttpServerCodec`解码器会将请求解析成为两部分：HttpRequest 和 HttpContent，前者表示 http 请求的请求行和请求头，后者表示请求的请求体

```java
@Slf4j
public class TestHttp {

   public static void main(String[] args) {
      NioEventLoopGroup boss = new NioEventLoopGroup();
      NioEventLoopGroup worker = new NioEventLoopGroup();

      try {
         ServerBootstrap bootstrap = new ServerBootstrap();
         ChannelFuture fu = bootstrap.group(boss, worker)
               .channel(NioServerSocketChannel.class)
               .childHandler(new ChannelInitializer<NioSocketChannel>() {
                  @Override
                  protected void initChannel(NioSocketChannel ch) throws Exception {
                     ch.pipeline().addLast(new LoggingHandler());
                     ch.pipeline().addLast(new HttpServerCodec());
                     ch.pipeline().addLast(new SimpleChannelInboundHandler<HttpRequest>() {
                        @Override
                        protected void channelRead0(ChannelHandlerContext ctx, HttpRequest msg) throws Exception {
                           // 1. 接收相应
                           log.debug("{}", msg.uri());
                           // 2. 返回响应，写入数据时候，主要表明数据长度，不然浏览器会一直进行请求
                           byte[] bytes = "<h1>hello, world!".getBytes(StandardCharsets.UTF_8);
                           DefaultFullHttpResponse response = new DefaultFullHttpResponse(msg.protocolVersion(), HttpResponseStatus.OK);
                           response.headers().setInt(CONTENT_LENGTH, bytes.length);
                           response.content().writeBytes(bytes);
                           // 3. 相应写入 channel
                           ctx.writeAndFlush(response);
                        }
                     });
                  }
               })
               .bind(8080).sync();
         fu.channel().closeFuture().sync();
      } catch (InterruptedException e) {
         e.printStackTrace();
      } finally {
         boss.shutdownGracefully();
         worker.shutdownGracefully();
      }
   }
}
```

如代码所示，服务端相应 http 请求时候，首先获取 request 请求，再然后创建一个 response 类，作为相应，填写好响应的头和状态码，写入响应的内容和响应的长度（防止浏览器一直继续等待接收数据），最后将 response 写回服务端。

### 自定义协议

#### 自定义协议的要素

* 魔数，用来第一时间判定是否是无效数据包
* 版本号，可以支持协议的升级
* 序列化算法，消息正文采取的序列化和反序列化的方式，例如：json、protobuf、hessian、jdk 等
* 指令类型，登录、注册、单聊、群聊...
* 请求序号，为了双工通讯，提高异步能力
* 正文长度
* 消息正文

> 首先我们需要确定自定义协议的内容。通过类的形式进行封装。然后需要确定消息发送的编解码，也就是说需要把消息类和 ByteBuf 类双向转换。最后，为了保证不出现粘包半包的问题，还需要一个解决粘包半包的解析器 LengthFieldFrameDecoder，根据自定义协议的要素自行设置相关参数。

```java
public class TestMessageCodec {

	public static void main(String[] args) throws Exception {
		EmbeddedChannel channel = new EmbeddedChannel(
            // 通过解码器解决粘包半包问题
				new LengthFieldBasedFrameDecoder(1024, 12, 4, 0,0),
				new LoggingHandler(),
				new MessageCodec()
		);

		ChatRequestMessage message = new ChatRequestMessage("hello", "zhangsan", "lisi");
//		channel.writeOutbound(message);

		ByteBuf buf = ByteBufAllocator.DEFAULT.buffer();
		new MessageCodec().encode(null, message, buf);

		ByteBuf buf1 = buf.slice(0, 100);
		ByteBuf buf2 = buf.slice(100, buf.readableBytes() - 100);
		buf1.retain();
        // 如果出现半包，由于使用 LengthFieldBasedFrameDecoder 解码，所以即使只接受到半包，也会等待下次发送的数据，一直到成功解析出一个包
		channel.writeInbound(buf1);
//		channel.writeInbound(buf2);

	}

}
```





