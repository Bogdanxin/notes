# 启动服务

## 创建 Selector 

在 new 一个 EventLoopGroup 时候就会被创建。首先调用 EventLoopGroup 构造器，然后构造器调用 newChild 方法创建子 EventLoopGroup。在创建时，就会调用 openSelector 方法从而创建 Selector。

> Selector（多路复用器） 可以使用一个线程处理多个客户端连接，检测多个注册通道（Channel）上是否有事件发生。如果发生，变获取事件并对事件进行处理。而 NioEventLoop 聚合了 Selector，可以同时并发大量客户端连接。

