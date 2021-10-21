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

## primes 

依据为：[Bell Labs and CSP Threads](https://swtch.com/~rsc/thread/)

利用多线程和管道实现素数筛。这里有个细节，当我们拿到一个素数a时候，将剩下的数除以a，如果不能够整除，说明这个数可以进一步判断是否为素数。下一步就是将这个数写入到管道中，进一步进行判断。同时，我们也可以知道，第一个没法被整除的数，就是素数。

>  例如：2 3 4 5 中，我们拿到素数 2，之后的数整除判断，3 没法整除，并且是第一个，说明他就是素数。

```c
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"

#define READEND 0
#define WRITEEND 1
#define NUM 35

void child(int* pl);

int main(int argc, int argv) {
    if (argc != 1) {
        fprintf(2, "error! usage: primes\n");
        exit(0);
    }
    
    int pl[2];
    pipe(pl);
    
   	if (fork() == 0) {
        child(pl);
    } else {
        close(pl[READEND]);
        for (int i = 2; i <= NUM; i++) {
            write(p[WRITEEND], &i, sizeof(int));
        }
        close(pl[WRITEEND]);
        wait(0);
    }
    
    exit(0);
}

void child(int* pl) {
    int pr[2];
    int buf
    
    // 读管道，读的数一定会是质数
    int tmp = read(pl[READEND], &buf, sizeof(int));
    if (tmp <= 0) {
        return ;
    }
    
    pipe(pr);
    if (fork() == 0) {
        child(pr);
    } else {
        printf("prime %d", buf);
        
        close(pr[READEND]);
        int prime = buf;
        // 剩下的所有数除质数，只有不能整除的，才有资格到下一个递归中。
        while (read(pl[READEND], &buf, sizeof(int)) > 0) {
            if (buf % prime != 0) {
                write(pr[WRITEEDN], &buf, sizeof(int));
            }
        }
      	
        close(pr[WRITEEND]);
        wait(0);
    }
    
    exit(0);
}
```

## find

find 指令 `find <dir> <file>`，输入目录和目标文件，返回该目录下所有的文件路径。

1. 需要了解 ls 的源码，才会很好写。
2. 使用递归的方式查找，更好理解



```c
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"
#include "kernel/fs.h"
#include "kernel/fcntl.h"

void find(char* file, char* path) {
    int fd;
    char buf[512], *p;
    struct dirent de;
    struct stat st;
    
    if ((fd = open(path, 0)) < 0) {
        return;
    }
    
    if (fstat(fd, &st) < 0) {
        close(fd);
        return;
    }
    
    while (read(fd, &de, sizeof(de)) == sizeof(de)) {
        strcpy(buf, path);
        p = buf + strlen(buf);
        *p++ = '/';
        if (de.inum == 0) {
            continue;
        }
        
        memmove(p, de.name, DIRSIZ);
        p[DIRSIZ] = 0;
        if (stat(buf, &st) < 0) {
            fprintf(2, "error: cannot stat %s\n", buf);
            return;
        }
        
        switch(st.type) {
            case T_FILE:
                if (strcmp(de.name, file) == 0) {
                    printf("%s\n", buf);
                }
                break;
                
            case T_DIR:
                if (strcmp(de.name, "..") != 0 && strcmp(de.name, ".") != 0) {
                    find(file, path);
                }
                break;
        }
    }
    
    close(fd);
    exit(0);
}

int main(int argc, char* argv[]) {
    if (argc != 3) {
        fprintf(2, "error usage: find dir file\n");
        exit(1);
    }

    char* path = argv[1];
    char* file_name = argv[2];

    find(file_name, path);

    exit(0);
}
```

## xargs

xargs 命令就不多说了，Linux 命令里有学到，这里需要了解的是，要读取标准输出，需要从 0 中 read。

```c
#include "kernel/types.h"
#include "kernel/stat.h"
#include "user/user.h"
#include "kernel/param.h"

int main(int argc, char* argv[]) {
    char* command = argv[1];
    char* paramv[MAXARG];
    int len;
    int index = 0;
    char buf[1024];

    for (int i = 1; i < argc; i++) {
        paramv[index++] = argv[i];
    }
    
    while ((len = read(0, &buf, 1024)) > 0) {
        if (fork() == 0){
            char *tmp = (char*) malloc(sizeof(buf));
            int tmp_index = 0;
            for (int i = 0; i < len; i++) {

                if (buf[i] == ' ' || buf[i] == '\n') {
                    tmp[tmp_index] = 0;
                    paramv[index++] = tmp;
                    tmp = (char*) malloc(sizeof(buf));
                    tmp_index = 0;
                } else {
                    tmp[tmp_index++] = buf[i];
                }
            }

            tmp[tmp_index] = 0;
            paramv[index] = 0;
            exec(command, paramv);
        } else {
            wait(0);
        }
    }

    exit(0);
}
```

