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

         channel.read(new ByteBuffer[]{buffer1, buffer2, buffer3});
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

## 文件编程 FileChannel

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

