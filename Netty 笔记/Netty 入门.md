# Netty 入门

## 基本操作

```java
public class HelloServer {
    public static void main(String[] args) {
        new ServerBootstrap()
				.group(new NioEventLoopGroup())
				.channel(NioServerSocketChannel.class)
				.childHandler(new ChannelInitializer<NioServerSocketChannel>() {
					@Override
					protected void initChannel(NioServerSocketChannel ch) throws Exception {
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
3. channel 是用来指定这个服务器创建连接使用的是哪种类型的 ServerSocketChannel
4. childHandler 用来指定 worker 的能执行哪些操作（用 handler 执行操作）
5. ChannelInitializer 本质也是一个 handler，不过它的作用是在 initChannel 中将 handler 注册到 channel 上，以后可以执行操作
6. StringDecoder 是 ByteBuf 解析器，将 ByteBuf 解析为 String，ChannelInBoundHandlerAdapter 是自定义 handler



