# Shell

### 文件权限：

通过`ls -l`命令或者其他文件目录详细信息的命令，都可看到以下的列表：

```shell
total 68
drwxrwxr-x 10 rydovo rydovo 4096  5月 14 16:12 .
drwxrwxr-x  7 rydovo rydovo 4096  5月 14 15:52 ..
drwxrwxr-x  3 rydovo rydovo 4096  5月 16 11:47 build
-rw-rw-r--  1 rydovo rydovo 1222  5月  6 18:14 .config
-rw-rw-r--  1 rydovo rydovo 1233  4月 30 12:31 .config.old
drwxrwxr-x  2 rydovo rydovo 4096  4月 30 12:27 configs
-rw-rw-r--  1 rydovo rydovo  112  5月 12 15:21 .gitignore
drwxrwxr-x  8 rydovo rydovo 4096  5月 14 15:52 include
-rw-rw-r--  1 rydovo rydovo    7  5月 14 12:28 in.txt
-rw-rw-r--  1 rydovo rydovo 3883  4月 30 12:27 Kconfig
-rw-rw-r--  1 rydovo rydovo 1644  4月 30 12:27 Makefile
-rw-rw-r--  1 rydovo rydovo 1138  4月 30 12:27 README.md
drwxrwxr-x  5 rydovo rydovo 4096  4月 30 12:27 resource
drwxrwxr-x  2 rydovo rydovo 4096  5月 14 16:15 scripts
drwxrwxr-x  9 rydovo rydovo 4096  5月 14 15:52 src
drwxrwxr-x  3 rydovo rydovo 4096  5月  6 22:16 test
drwxrwxr-x  8 rydovo rydovo 4096  4月 30 12:27 tools

```

最前面的字符串：

`d rwx rwx r-x` 

首先，第一个字符代表文件类型，一般有普通文件、目录文件、数据接口文件、字符设备文件和块设备文件、符号链接文件。

* '-' 符号代表普通文件，这里的普通文件又可以分为：纯文本文件、二进制文件（可执行文件）、数据格式文件（datafile）。

* 'd' 代表目录文件。其实代表的就是一个目录。

* 'c' 和 'b' 分别代表字符设备文件和块设备文件。

    > **区块(block)设备档 ：**
    >
    > 就是一些储存数据， 以提供系统随机存取的接口设备，举例来说，硬盘与软盘等就是啦！ 你可以随机的在硬盘的不同区块读写，这种装置就是成组设备！你可以自行查一下/dev/sda看看， 会发现第一个属性为[ b ]！
    >
    > **字符(character)设备文件：**
    >
    > 亦即是一些串行端口的接口设备， 例如键盘、鼠标等等！这些设备的特色就是一次性读取的，不能够截断输出。 举例来说，你不可能让鼠标跳到另一个画面，而是滑动到另一个地方！第一个属性为 [ c ]。

* 's' 数据接口文件（套接字文件）：这种类型的文件通常被用在网络上的数据承接了。

* 'l' 符号链接文件：表示链接一个文件是另一个文件的链接，类似于windows 的快捷方式。



剩下的 9 个字符，分为三组，每组rwx 分别代表可读、可写、可执行，第一组代表文件所属用户的权限，第二组代表文件所属用户组权限，最后一组代表其他用户权限。

#### 如何修改文件的执行权限

[chmod 命令，Linux chmod 命令详解：用来变更文件或目录的权限](https://wangchujiang.com/linux-command/c/chmod.html)

```shell
/tmp/missing ll                             
.rwxrw-rw- rydovo rydovo 61 B Tue May 24 10:07:24 2022  semester
.rwxrwxrwx rydovo rydovo  0 B Tue May 24 09:53:39 2022  test.log
.rwxrwxrwx rydovo rydovo  0 B Tue May 24 10:03:28 2022  test1.log

/tmp/missing chmod 000  test1.log            

/tmp/missing ll                               
.rwxrw-rw- rydovo rydovo 61 B Tue May 24 10:07:24 2022  semester
.rwxrwxrwx rydovo rydovo  0 B Tue May 24 09:53:39 2022  test.log
.--------- rydovo rydovo  0 B Tue May 24 10:03:28 2022  test1.log

/tmp/missing chmod --reference=test.log test1.log

/tmp/missing ll                              
.rwxrw-rw- rydovo rydovo 61 B Tue May 24 10:07:24 2022  semester
.rwxrwxrwx rydovo rydovo  0 B Tue May 24 09:53:39 2022  test.log
.rwxrwxrwx rydovo rydovo  0 B Tue May 24 10:03:28 2022  test1.log
```



### 程序间创建连接

通过使用创建『流』，将程序之间连接起来。程序会从标准输入流中获取信息，经程序处理后，再对处理数据输出到输出流。同时，我们可以将『流』进行重定向，这样就可以将流数据输入或者输出到指定的文件中。

最简单的重定向就是`< file`和 `> file` 。两个命令可以将程序输入输出流分别重定向到文件中：

```shell
missing:~$ echo hello > hello.txt
missing:~$ cat hello.txt
hello
missing:~$ cat < hello.txt
hello
missing:~$ cat < hello.txt > hello2.txt
missing:~$ cat hello2.txt
hello
```

同时可以使用 `>>` 来向一个文件追加内容。管道`|`可以更好的进行重定向。管道可以将两个程序的输入和输出流连接起来

```shell
missing:~$ ls -l / | tail -n1
drwxr-xr-x 1 root  root  4096 Jun 20  2019 var
missing:~$ curl --head --silent google.com | grep --ignore-case content-length | cut --delimiter=' ' -f2
219
```