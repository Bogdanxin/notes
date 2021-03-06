# NIO 基础

## 三大组件

### Channel & Buffer

channel 是读写数据的双向管道，buffer 就是数据的缓存区。可以从 channel 中读取数据写入到 buffer 中，也可以从 buffer 中读取数据写入到 channel 中。

常见的 Channel 有：

* Filechannel 传输文件
* DatagramChannel udp 协议传输
* Socketchannel tcp 协议传输，可以用于服务端和客户端
* ServerSocketchannel tcp 传输，只能用于服务端

常见 buffer 有：

* Byte Buffer
    * MappedByteBuffer
    * DirectByteBuffer
    * HeapByteBuffer
* ShortBuffer
* IntBuffer
* LongBuffer
* FloatBuffer
* DoubleBuffer
* CharBuffer

### Selector 

selector 就是多路复用器，可以根据旧版服务器设计理解

#### 多线程版本设计

<img src="https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/img/202110231920564.png" alt="image-20211023192031507"  />

如图所示，将每个线程对应一个请求，如果没有线程可以处理，就新开线程。

##### 多线程版本的缺点

* 内存占用高
* 线程上下文切换成本高
* 只适合连接少的情况

#### 线程池版本设计

问：为什么不能将线程池版本设计成「非阻塞」模式？

![image-20211023205625642](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/img/202110232056678.png)

##### 线程池版缺点

* 阻塞模式下，线程仅能处理一个 socket 连接。一个连接建立后，只能等完全处理完毕，该线程才能释放去处理其他连接的请求。
* 仅适合短连接模式。因为是阻塞模式，所以短连接就是很必要的了，不然一个连接一直存在会影响吞吐量。

#### selector 版本设计

selector 的作用就是配合一个线程来管理多个 channel，获取这些 channel 上发生的事件，这些 channel 工作在非阻塞模式下，不会让线程吊死在一个 channel 下，适合连接特别多，但是流量低的情况。

![image-20211023210056833](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/img/202110232100873.png)

调用 selector 的 select() 会阻塞到 channel 发生读写就绪事件，这些事件发生，channel 会主动告知 selector，selector 再会将对应的请求交给 thread 线程，线程会对请求处理。

## ByteBuffer

示例代码：

```java
@Slf4j
public class TestByteBuffer {

   public static void main(String[] args) {
      // FileChannel
      // 1. 输入输流 2.RandomAccessFile

      try (FileChannel channel = new FileInputStream("data.txt").getChannel()) {
         // 准备缓冲区
         ByteBuffer buffer = ByteBuffer.allocate(10);
         int len;
         while ((len = channel.read(buffer)) != -1){
            log.debug("读取到的字节数：{}", len);
            // 从 channel 读取数据，向 buffer 写入
            // 打印 buffer 的内容
            // 1. 切换至读模式
            buffer.flip();
            // 2. 从 buffer 中读数据，同时需要不停判断是否还有数据
            while (buffer.hasRemaining()) {
               byte b = buffer.get();
               log.debug("实际字节{}", (char) b);
            }
            // 从 buffer 中读完一次，需要重新设为写模式
            buffer.clear();
         }
      } catch (IOException e) {
      }
   }
}
```

### ByteBuffer 使用方法

1. 向 buffer 中写入数据，例如调用 `channel.read(buffer)`
2. 调用`flip()`方法切换至**读模式**
3. 从 buffer 中读取数据，例如调用 `buffer.get()`方法
4. 读完 buffer 中所有数据后，需要重新切换至**写模式**，`clear()`或者`compact()`
5. 重新进行 1~4 步骤

### ByteBuffer 结构

ByteBuffer 有以下结构：

* capacity Buffer 的容量
* position Buffer 的起始点
* limit 限制



在写模式下，刚刚开始创建好的 buffer 的三个属性，position 指向的是 buffer 数组的起始位置，limit 表示该数组能写入的位置，capacity 表示 buffer 数组的总容量。如图所示：

<img src="https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/img/202110241512966.png" alt="image-20211024151238813" style="zoom: 67%;" />



写入 4 个字节的数据后，position 改变位置，即可写入位置，limit 表示最大限制，其他两个不变。

<img src="https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/img/202110241518496.png" alt="image-20211024151825414" style="zoom:67%;" />



调用`flip()`之后进入读模式，开始读取数据，position 又代表了开始读取的位置，limit 代表了可读取的限制位置，capacity 不变

<img src="https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/img/202110241520707.png" alt="image-20211024152057632" style="zoom:67%;" />



读取四个字节后：

<img src="https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/img/202110241522676.png" alt="image-20211024152204604" style="zoom:67%;" />



调`clear()`方法后的状态：

<img src="https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/img/202110241512966.png" alt="image-20211024151238813" style="zoom: 67%;" />

调用``compact()``后的状态：

<img src="https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/img/202110241528620.png" alt="image-20211024152839544" style="zoom:50%;" /> 

### 分散读和集中写

集中写，因为写数据时，buffer 的空间是一定的，所以我们需要多个 buffer 缓存，那么就有两种方式，一种是把所有的 buffer 合到一起，但是这种会导致多次拷贝，另一中就是把 buffer 设置到一个数组中，通过这种集中写，减少拷贝，并且提高写入效率。

```java
public class TestByteBufferGatheringWrite {

   public static void main(String[] args) {
      ByteBuffer buffer1 = StandardCharsets.UTF_8.encode("hello");
      ByteBuffer buffer2 = StandardCharsets.UTF_8.encode("world");
      ByteBuffer buffer3 = StandardCharsets.UTF_8.encode("你好");

      try (FileChannel channel = new RandomAccessFile("words2.txt", "rw").getChannel()) {
         channel.write(new ByteBuffer[]{buffer1, buffer2, buffer3});
      } catch (IOException e) {
      }
   }
}
```



分散读就是集中写的逆版本，设置多个 buffer 接收，而不是统一设置一个大的 buffer 接收。

```java
public class TestScattingReads {

   public static void main(String[] args) {
      try (FileChannel channel = new RandomAccessFile("words.txt", "r").getChannel()) {
         ByteBuffer buffer1 = ByteBuffer.allocate(3);
         ByteBuffer buffer2 = ByteBuffer.allocate(3);
         ByteBuffer buffer3 = ByteBuffer.allocate(4);

         channel.read(new ByteBuffer[]{buffer1, buffer2, buffer3});Cancel changes
         ByteBufferUtil.debugAll(buffer1);
         ByteBufferUtil.debugAll(buffer2);
         ByteBufferUtil.debugAll(buffer3);
      } catch (IOException e) {
      }
   }
}
```

### 粘包、半包

#### 出现原因

粘包是因为在传输过程中，发送端为了提高效率，会将多条消息合并发送，这样就导致多条消息如同黏连在一起一样，半包是由于在发送端和接收端缓存空间是有限的，就有可能出现某条消息发送过程中缓存空间不足，只能发送一部分数据的情况，另一部分需要在下次才能够发送。


## 文件编程

### FileChannel

> FileChannel 只能在阻塞模式下才能工作，所以不能用 selector

### 获取

不能直接对 FileChannel 获取，并且 FileChannel 的读写能力由获取 channel 的 stream 决定。

* 通过 FileInputStream 获取只读 channel  
* 通过 FileOutputStream 获取只写 channel
* 通过 RandomAccessFile 构造，指定读写模式

### 读取

从 channel 读取数据填充 ByteBuffer，返回值表示读取多少字节，-1 代表达到文件末尾

```java
int readByte = channel.read(buffer);
```

### 写入

socketChannel 一般像这样写入，通过 while 调用 channel.write 因为 write 不能保证一次将 buffer 所有内容全都写入到 channel 中。

```java 
ByteBuffer buffer = ...;
buffer.put(...);// 向 buffer 写入数据
buffer.flip(); //切换 buffer 的读模式
while (buffer.hasRemaining()) {
    channel.write(buffer);
}
```

### 关闭

channel 必须要关闭，但是因为流是通过 try-catch-finnally 释放资源，就可以关闭资源

### 强制写入

处于系统性能考虑，只是将数据缓存起来，并不是立刻写入磁盘，可以调用 force 方法将文件和数据立刻写入到磁盘中。


### 传输 transferTo()

```java
try (
	FileChannel from = new FileInputStream().getChannel();
    FileChannel to = new FileOutPutStream().getChannel();
) {
    from.transferTo(0, from.size(), to);
} catch (IOException e) {
    e.printStackTrace();
}
```

使用 transferTo 方法效率要高，底层会使用操作系统的零拷贝优化。

#### 缺陷

transferTo 一次传输，最大数据量只有 2g，如果超过 2g，就需要重复此操作

```java
size = from.size();
for (long left = size; left > 0;) {
    left -= from.transferTo(size - left, left, to);
}
```



## 网络编程

### 阻塞 & 非阻塞

阻塞编程就是服务端或者客户端建立连接，或者处理发送消息时，会对对方进行等待，如果一直没有获取到消息或者建立连接，那么对象就会一直处于等待状态，尽管此时的 cpu 没有进行其他的处理，但是 cpu 处于空闲状态，影响效率。

#### 阻塞服务端

1. 创建一个 ServerSocketChannel 作为服务端。
2. channel 绑定端口进行监听
3. 执行 `accept()` 方法等待连接建立（阻塞）
4. 读取数据，进行通信（通过设置 buffer）

#### 阻塞客户端

1. 创建 SocketChannel 
2. 绑定服务端接口
3. 发送数据

#### 非阻塞服务端

基本操作和上面一样，只不过在 `open`建立连接 和 `accept` 读取数据的时候，需调用 `configureBlocking()`方法设为非阻塞形式，这样如果没有建立连接或者没有读取到数据，就会返回 null 或者 0，然后继续执行。

##### 优缺点

优点：能够正确处理多个连接，不会因为一个连接的问题导致其他连接一直等待连接和数据处理

缺点：由于如果没有获取到连接或者没有数据读取，就会进行下一个循环，cpu 一直在空转，导致利用率不高

### 使用 Selector

#### 多路复用

在单线程下，配合 Selector 完成对多个 channel 可读写事件的监控，称之为**多路复用**。在单线程下，如果发生事件，则会进行处理，如果没有发生则会阻塞。



通过 selector 对事件监听，从而既能够保证非阻塞，还能够防止一直接收不到链接或者数据而空转。

```java
@Slf4j
public class Server {

    public static void main(String[] args) throws IOException {
        // 1. 创建 selector, 管理多个 channel
        Selector selector = Selector.open();
        ServerSocketChannel ssc = ServerSocketChannel.open();
        ssc.configureBlocking(false);
        // 2. 建立 selector 和 channel 的联系（注册）
        // SelectionKey 就是将来事件发生后，通过它可以知道事件和哪个channel的事件
        SelectionKey sscKey = ssc.register(selector, 0, null);
        // key 只关注 accept 事件
        sscKey.interestOps(SelectionKey.OP_ACCEPT);
        log.debug("sscKey:{}", sscKey);
        ssc.bind(new InetSocketAddress(8080));
        while (true) {
            // 3. select 方法, 没有事件发生，线程阻塞，有事件，线程才会恢复运行
            // select 在事件未处理时，它不会阻塞, 事件发生后要么处理，要么取消，不能置之不理
            selector.select();
            // 4. 处理事件, selectedKeys 内部包含了所有发生的事件
            Iterator<SelectionKey> iter = selector.selectedKeys().iterator(); // accept, read
            while (iter.hasNext()) {
                SelectionKey key = iter.next();
                // 处理key 时，要从 selectedKeys 集合中删除，否则下次处理就会有问题
                iter.remove();
                log.debug("key: {}", key);
                // 5. 区分事件类型
                if (key.isAcceptable()) { // 如果是 accept
                    ServerSocketChannel channel = (ServerSocketChannel) key.channel();
                    SocketChannel sc = channel.accept();
                    sc.configureBlocking(false);

                    SelectionKey scKey = sc.register(selector, 0, null);
                    scKey.interestOps(SelectionKey.OP_READ);
                    log.debug("{}", sc);
                    log.debug("scKey:{}", scKey);
                } else if (key.isReadable()) { // 如果是 read
                    try {
                        SocketChannel channel = (SocketChannel) key.channel();
                        ByteBuffer buffer = ByteBuffer.allocate(16);
                        channel.read(buffer);
                        ByteBufferUtil.debugRead(buffer);
                    } catch (IOException e) {
                        e.printStackTrace();
                        key.cancel();
                    }
                } 
            }
        }
    }
}

```

注意事项：

* 一个 selector 会管理注册的多个 channel，如果 channel 发生事件，则会主动选择这个 channel
* selector 是非阻塞的，但是如果没有建立连接，就会将其阻塞，从而提高 cpu 利用率
* 这里有两个集合，一个是 channel 执行 register 后，selector 注册的 channel 集合。这个集合是用来存放所有向这个 selector 中注册的 channel；另一个是 channel 注册后关注的事件发生后，会将对应的 selectionKey 存放到一个集合中，这个集合只要发生时间就往里面放，所以需要删除（见下面的注释）。
* 注册 selector 时候，需要将 channel 设置为非阻塞才可以
* 需要对 iter 中访问到的 SelectionKey 进行 remove
* 绑定事件类型有四种：
    * connect - 客户端连接成功时触发
    * accept - 服务器成功接收连接时触发
    * read - 数据可读入时触发，有因为接受能力弱，数据暂不能读入的情况
    * write - 数据可写出时触发，有因为发送能力弱，数据暂不能写出的情况

####  为何要 remove()

> 因为 select 在事件发生后，就会将相关的 key 放入 selectedKeys 集合，但不会在处理完后从 selectedKeys 集合中移除，需要我们自己编码删除。例如
>
> * 第一次触发了 ssckey 上的 accept 事件，没有移除 ssckey 
> * 第二次触发了 sckey 上的 read 事件，但这时 selectedKeys 中还有上次的 ssckey ，在处理时因为没有真正的 serverSocket 连上了，就会导致空指针异常

#### 处理消息边界

![image-20211102211322917](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/img/202111022113623.png)



* 一种思路是固定消息长度，数据包大小相同，服务器按照预定长度读取，缺点是浪费带宽
* 另一种思路是按照分隔符拆分，需要多次复制、移动数据，效率低
* TLV 模式，即 Type 类型、Length 长度、Value 数据，类型和长度已知的情况下，可以方便的获取消息大小，分配合适的 buffer，缺点是 buffer 需要提前分配，内容过大会影响 server 的容量。

##### 处理方法

按照方法二进行处理

1. 因为如果出现一个 buffer 存放不完的情况，那么我们需要对这个 buffer 进行扩容，但是我们也不能将这个 buffer 共享给所有的 channel。所以我们要在 selector 注册 channel 时候，``register(channel, 事件, buffer);`` 这样就能够保证每个 channel 独占一个 buffer。
2. 如果一次读取过程中，没有完整的数据被读取出来，说明数据量是大于 buffer 大小的，`compact()`方法压缩后的 position == limit ，那么需要进行扩容

#### 可读事件

当a向b发送数据时，不一定能够保证接收端马上接收到，这时候如果一直在等待可写，或者循环尝试写入，都是浪费效率的，所以就引入了**可写事件**，当没有触发可写事件，a 就可以执行其他的操作，直到触发可写事件，然后就可以对数据进一步写入了。

### 多线程优化

原因：

1. 单线程对多核 CPU 的利用率不高
2. 单线程最怕一直处理某个数据，从而将后续的数据阻塞

#### 模型

设置两组 selector ，一组一个 boss，一组多个 worker，boss 处理 accept 事件，worker 处理 read、write 事件。

> 注意:
>
> 当 selector 已经执行 `select` 方法时候，其他线程即使执行 `register` 方法，将 channel 注册到 selector 上，也会被 `select` 方法阻塞。必须等到 `select` 方法执行，也就是有事件触发时，才可以继续执行。
>
> 这时候，我们可以使用 selector 的 `wakeup` 方法，如果出现阻塞，但是没有注册事件，``wakeup` 就会将`select`终止阻塞，从而保证能够一定注册到事件。



```java
@Slf4j
public class MultiThreadServer {

   public static void main(String[] args) throws IOException {
      Thread.currentThread().setName("boss");

      ServerSocketChannel ssc = ServerSocketChannel.open();
      ssc.configureBlocking(false);
      Selector boss = Selector.open();
      ssc.register(boss, SelectionKey.OP_ACCEPT, null);
      ssc.bind(new InetSocketAddress(8080));

      // 创建固定数量的 worker

      Worker[] workers = new Worker[2];
      for (int i = 0; i < 2; i++) {
         workers[i] = new Worker("worker-" + i);
      }

      AtomicInteger index = new AtomicInteger();
      while (true) {
         boss.select();
         Iterator<SelectionKey> iterator = boss.selectedKeys().iterator();
         while (iterator.hasNext()) {
            SelectionKey key = iterator.next();
            iterator.remove();
            if (key.isAcceptable()) {
               ServerSocketChannel serverSocketChannel = (ServerSocketChannel) key.channel();
               SocketChannel sc = serverSocketChannel.accept();
               sc.configureBlocking(false);
               log.debug("connected ... {}", sc.getRemoteAddress());
               log.debug("before register ... {}", sc.getRemoteAddress());
               workers[index.getAndIncrement() % workers.length].register(sc);

               log.debug("after register ... {}", sc.getRemoteAddress());
            }
         }
      }
   }

   static class Worker implements Runnable{
      private Thread thread;
      private Selector selector;
      private String name;
      private volatile boolean start = false;
      private ConcurrentLinkedQueue<Runnable> queue = new ConcurrentLinkedQueue<>();

      public Worker(String name) {
         this.name = name;
      }

      /**
       * 初始化线程和 selector
       */
      public void register(SocketChannel sc) throws IOException {
         if (!start){
            thread = new Thread(this, name);
            selector = Selector.open();
            thread.start();
            start = true;
         }

         // 分析一下为什么要这么做：
         // 在我们 boss 线程调用 register 方法时候，这个方法还是在 boss 线程执行的，
         // 所以执行 register 时候还是与 selector 方法并行，不能够保证顺序问题，
         // 于是会出现多个客户端连接时没法执行 register 方法的现象
         // 所以我们需要将这个方法传递到 worker 线程中，在 worker 线程中执行从而保证顺序 。
         // 这时候就需要 queue 传递 runnable 接口，实现 run 方法
         selector.wakeup();
         sc.register(selector, SelectionKey.OP_READ, null);

      }

      @Override
      public void run() {
         while (true) {
            try {
               selector.select();
               Runnable task = queue.poll();
               if (task != null) {
                  task.run();
               }
//             selector.select(); 不再这里调用 select 方法的原因是，
//             我们在并行操作时候，queue 中添加 task 时，selector 也在执行 select 方法
//             （poll 的 task 为空，还是并行的）所以 select 还是被阻塞住了，同时还没有 read 事件的注册，
//             加了 wakeup 后，就能够保证即使 task 为空，select 也会被 wakeup 终止，从而将事件注册
               // 其实就是需要一个 wakeup 就能解决

               Iterator<SelectionKey> iterator = selector.selectedKeys().iterator();
               while (iterator.hasNext()) {
                  SelectionKey key = iterator.next();
                  iterator.remove();
                  if (key.isReadable()) {
                     SocketChannel channel = (SocketChannel) key.channel();
                     ByteBuffer buffer = ByteBuffer.allocate(16);
//                   ByteBuffer buffer = (ByteBuffer) key.attachment();
                     log.debug("read ... {}", channel.getRemoteAddress());
                     channel.read(buffer);
                     buffer.flip();
                     ByteBufferUtil.debugAll(buffer);
                  }
               }
            } catch (IOException e) {
               e.printStackTrace();
            }

         }
      }
   }
}
```

