# xargs 命令

[xargs 命令教程 - 阮一峰的网络日志 (ruanyifeng.com)](https://www.ruanyifeng.com/blog/2019/08/xargs-tutorial.html)

## 标准输入和管道命令

Unix 命令都带有参数，有些命令可以接受『标准输入』（stdin）作为参数，管道则可以将左侧的『标准输出』转变为『标准输入』，然后传递给管道右侧的命令。如

```
cat /etc/passwd | grep root
```

就是将左侧 `cat /etc/passwd` 输出传递给右侧 `grep root` 命令。

但是有些命令不接受标准输入，则需要将标准输入转换为命令行输入。这时候就需要 xargs 命令。

## xargs 命令作用

xargs 命令的作用就是将标准输入转换为命令行输入。如：

```shell
$ echo "hello world" | xargs echo
```

xargs 命令格式如下：

```shell
$ xargs [-options] [commmand]
```

真正执行的命令[command]，紧跟在 xargs 后面，接收 xargs 输出的命令行输出。他的作用在于，大多数命令（rm、mkdir、ls）和管道一起使用时候，都需要将管道左的标准输入转换为命令行参数。





