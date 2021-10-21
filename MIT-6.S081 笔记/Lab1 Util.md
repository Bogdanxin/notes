# Lab1 Util 笔记

## Sleep 

输入 ``sleep <time>`` 命令，输入命令后，会等待 `time` 时间，需要调用系统调用 `sleep` 函数 。

注意：如果出现错误的命令参数，需要进行报错。

代码：

```c
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

int main(int argc, char* argv[]) {
	if (argc != 2) {
    	fprint(2, "error! usage : sleep time\n");
    	exit(0);
  	}
  
  	int time = atoi(argv[1]);
  	if (time < 0) {
    	fprintf(2, "error!\n");
    	exit(0);
  	}
  
  	sleep(time);
  	exit(0);
}
```

## pingpong

pingpong 需要用到管道，通过管道，父进程向子进程发送 1 byte 数据，子进程接收后，打印 `<pid> received ping`，同时向父进程发送 1 byte 数据，父进程接收到后，打印 `<pid> received pong` 

首先需要了解 `fork()` 函数的作用和使用方法，在了解 `pipe()` 函数的使用方法。

> 只说 `pipe()`函数，其用法就是设置一个管道数组，使用 pipe 函数初始化管道，父子进程分别关闭管道的读端和写端，然后利用 read 和 write 函数将数据从管道读出或者写入。**利用管道 read 数据，如果没有数据可以被读，就会等待直到数据被写入或者所有被指向写段的文件描述符被关闭**

```c
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

#define READEND 0
#define WRITEEND 1

int main(int argc, char* argv[]) {
    if (argc != 1) {
        fprintf(2, "error: usage pingpong\n");
        exit(1);
    }
    
    // 声明管道
    int p[2];
    // 对管道初始化
    pipe(p);
    char buf;
    
    // 开启父子进程
    // 子进程首先读取管道数据，如果没有数据可读，就会被阻塞
    if (fork() == 0) {
        // 首先关闭写管道
        close(p[WRITEEND]);
        // 从读管道中读数据
        read(p[READEND], &buf, 1);
        printf("%d received: ping\n", getpid());
        // 然后关闭管道读端
        close(p[READEND]);
        
        // 之后需要再向父进程发送消息
        write(p[WRITEEND], "1", 1);
        close(p[WRITEEND]);
    } else {
        close(p[WRITEND]);
        write(p[WRITEEND], "1", 1);
        close(p[READEND]);
        // 写完数据后需要等待子进程读完数据，再向管道写数据，直到退出
        wait(0);
        
        read(p[READEND], &buf, 1);
        printf("%d received pong\n", getpid());
        close(p[READEND]);
    }
    
    exit(0);
}
```

