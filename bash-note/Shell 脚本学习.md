# Shell 脚本学习

## Bash 基本语法

注意，这些命令默认都是在 bash 中使用，所以和经常使用的 zsh有些差别

### echo 命令

用于输出文本，如果需要输出多行，需要使用引号，文本放在引号中。

```shell
echo "<HTML>
    <HEAD>
          <TITLE>Page Title</TITLE>
    </HEAD>
    <BODY>
          Page body.
    </BODY>
</HTML>"

```

#### -n 参数

默认情况下，echo 输出文本末尾会有一个回车符，`-n` 参数会取消回车符。

```shell
$ echo -n hello world
hello world$
```

#### -e 参数

使用 `-e` 参数，会解析引号中的特殊符号（比如换行符`\n`），如果不使用，引号会让特殊字符编程普通字符，echo 也不会对其进行解析，原样输出。

```shell
$ echo "Hello\nWorld"
Hello\nWorld

# 双引号的情况
$ echo -e "Hello\nWorld"
Hello
World

# 单引号的情况
$ echo -e 'Hello\nWorld'
Hello
World
```

代码所示，`-e` 会将特殊字符解析，并执行对应意义的操作。

### 空格

Bash 使用空格区别不同的参数，两个参数之间如果有多个空格，只会忽略多余空格，认为只有一个。

### 分号

分号`;`是命令结束符，可以让一行中放置多个命令，一个命令执行后，再执行第二个

```shell
$ clear; ls
```

### 命令组合符 && 和 ||

`&&` 和 `||` 分别表示两个命令执行的继发关系。

```shell
command1 && command2
```

表示 command1 执行成功后，才能执行 command2

```shell
command1 || command2
```

表示 command1 执行失败后才能执行 command2

`;`表示两个命令依次执行，和上面两个也有不同之处。



### type 命令

使用 `type`命令可以判断命令的来源；

```
$ type echo 
echo is a shell builtin
$ type ls
ls is hashed (/bin/ls)
```

ls 是外部程序，echo 是内部命令。

## Bash 模式拓展

Shell 接收到用户输入的命令以后，会根据空格将用户的输入，拆分成一个个词元（token）。然后，Shell 会扩展词元里面的特殊字符，扩展完成后才会调用相应的命令。

这种特殊字符的扩展，称为模式扩展（globbing）。其中有些用到通配符，又称为通配符扩展（wildcard expansion）。Bash 一共提供八种扩展。只记录我不会的几种拓展。

- 波浪线扩展：用户主目录拓展。
- `?` 字符扩展：表示文件路径中<font color=red>任意一个</font>字符，不包括空字符。
- `*` 字符扩展：表示文件路径中<font color=red>任意数量</font>的字符，包括零个字符。
- 方括号扩展：表示方括号`` []``中的任意一个字符进行匹配，也有[0-9]这样的设计。
- 大括号扩展：表示分别扩展成大括号`{}`中的所有值，括号中，可以在最前设为空，表示没有这个：``{,123,23}``
- 变量扩展：使用`$`美元符号修饰的词元视为变量，将其拓展为变量值，可以直接使用`$变量名`，或者`${变量名}`
- 子命令扩展：使用`$(命令)`的方式，可以作为命令的返回值，当然也可以用于嵌套``$(ls $(pwd))``
- 算术扩展：使用 `$((算数表达式))`可以拓展为算术结果

### 使用注意点 

通配符有一些使用注意点，不可不知。

**（1）通配符是先解释，再执行。**

Bash 接收到命令以后，发现里面有通配符，会进行通配符扩展，然后再执行命令。

```
$ ls a*.txt
ab.txt
```

上面命令的执行过程是，Bash 先将`a*.txt`扩展成`ab.txt`，然后再执行`ls ab.txt`。

**（2）文件名扩展在不匹配时，会原样输出。**

文件名扩展在没有可匹配的文件时，会原样输出。

**（3）只适用于单层路径。**

所有文件名扩展只匹配单层路径，不能跨目录匹配，即无法匹配子目录里面的文件。或者说，`?`或`*`这样的通配符，不能匹配路径分隔符（`/`）。

## 转义和引号

转义：将命令中的特殊符号转义为普通的符号

```shell
$ echo $date
$
----- 转为打印 $date
$ echo \$date
$date
```

### 单引号

将字符串放在单引号中，表示保留字符字面含义，各种特殊字符在单引号中，都变成普通字符

```shell
$ echo '*'
*

$ echo '$USER'
$USER

$ echo '$((2+2))'
$((2+2))

$ echo '$(echo foo)'
$(echo foo)
```

如果需要在单引号引用字符串中使用单引号，需要在单引号字符串前加一个$字符，并对单引号进行转义

```shell
echo $'it's'
it's
```

其实更合理的是直接使用双引号

### 双引号

双引号比单引号宽松，大部分特殊字符在双引号里面，都会失去特殊含义，变成普通字符。

```
$ echo "*"
*
```

上面例子中，通配符`*`是一个特殊字符，放在双引号之中，就变成了普通字符，会原样输出。这一点需要特别留意，这意味着，双引号里面不会进行文件名扩展。

但是，三个特殊字符除外：美元符号（`$`）、反引号（` `` `）和反斜杠（``\``）。这三个字符在双引号之中，依然有特殊含义，会被 Bash 自动扩展。

双引号可以用在文件名称有空格，保留原样多余的空格，保持原命令输出格式。

```shell
$ echo "test abc.txt" 
创建一个 test abc.txt  文件
$ echo "abc     ggsd"
abc     ggsd
$ echo $(cal) 第一种就只会输出结果，但是格式为一行
May 2022 Su Mo Tu We Th Fr Sa 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20 21 22 23 24 25 26 27 28 29 30 31
$ echo "$(cal)" 就会保留输出格式
	May 2022
Su Mo Tu We Th Fr Sa
 1  2  3  4  5  6  7
 8  9 10 11 12 13 14
15 16 17 18 19 20 21
22 23 24 25 26 27 28
29 30 31
```

### Here 文档

Here 文档（here document）是一种输入多行字符串的方法，格式如下。

```shell
<< token
text
token
```

它的格式分成开始标记（`<< token`）和结束标记（`token`）。开始标记是两个小于号 + Here 文档的名称，名称可以随意取，后面必须是一个换行符；结束标记是单独一行顶格写的 Here 文档名称，如果不是顶格，结束标记不起作用。两者之间就是多行字符串的内容。

Here 文档内部会发生变量替换`$变量`，也支持转义，但是不支持通配符扩展，单双引号也会失去意义，变为普通字符。

```shell
$ foo='helloworld'
$ <<test
heredoc> $foo
heredoc> '$foo'
heredoc> "$foo"
heredoc> foo
heredoc> test
出输出
helloworld
'helloworld'
"helloworld"
foo
```

如果不希望发生变量替换，可以把 Here 文档的开始标记放在单引号之中。

```shell
$ foo='hello world'
$ cat << '_example_'
$foo
"$foo"
'$foo'
_example_

$foo
"$foo"
'$foo'
```

上面例子中，Here 文档的开始标记（`_example_`）放在单引号之中，导致变量替换失效了。

> Here 文档的本质是重定向，它将字符串重定向输出给某个命令，相当于包含了`echo`命令。
>
> ```shell
> $ command << token
>   string
> token
> 
> # 等同于
> 
> $ echo string | command
> ```
>
> 上面代码中，Here 文档相当于`echo`命令的重定向。
>
> 所以，Here 字符串只适合那些可以接受标准输入作为参数的命令，对于其他命令无效，比如`echo`命令就不能用 Here 文档作为参数。
>
> ```shell
> $ echo << _example_
> hello
> _example_
> ```
>
> 上面例子不会有任何输出，因为 Here 文档对于`echo`命令无效。
>
> 此外，Here 文档也不能作为变量的值，只能用于命令的参数。

### Here 字符串

> Here 文档还有一个变体，叫做 Here 字符串（Here string），使用三个小于号（`<<<`）表示。
>
> ```
> <<< string
> ```
>
> <font color=red>它的作用是将字符串通过标准输入，传递给命令。</font>
>
> 有些命令直接接受给定的参数，与通过标准输入接受参数，结果是不一样的。所以才有了这个语法，使得将字符串通过标准输入传递给命令更方便，比如`cat`命令只接受标准输入传入的字符串。
>
> ```
> $ cat <<< 'hi there'
> # 等同于
> $ echo 'hi there' | cat
> ```
>
> 上面的第一种语法使用了 Here 字符串，要比第二种语法看上去语义更好，也更简洁。
>
> ```
> $ md5sum <<< 'ddd'
> # 等同于
> $ echo 'ddd' | md5sum
> ```
>
> 上面例子中，`md5sum`命令只能接受标准输入作为参数，不能直接将字符串放在命令后面，会被当作文件名，即`md5sum ddd`里面的`ddd`会被解释成文件名。这时就可以用 Here 字符串，将字符串传给`md5sum`命令。



所以，Here 字符和 Heredoc是类似的，都是将字符串转为标准输入，传递给命令，接收参数。例子如下所示。

```shell
❯ cat <<< string
string
❯ cat <<< "string"
string
❯ cat << test
heredoc> string
heredoc> test
string
❯ cat << test
heredoc> "string"
heredoc> test
"string"
```

## Bash 变量

### 输出变量，export 变量

用户创建的变量只可以用于当前的 shell，子 shell 默认读不到父 shell 定义的变量。为了将变量传递给子 shell，需要使用 export 命令。这样的输出的变量对于子 shell 来说就是环境变量。

```shell
$ export test=1 # 在子 shell 中会继承这个变量以及相关值
# 进入子 shell
$ bash
$ echo $test
1
# 如果在子 shell 中将继承的变量进行修改，不会影响父shell 的变量
$ test=123
$ exit
# 进入父 shell
$ echo $test
1
```

### 特殊变量

bash 提供一些特殊变量，这些变量的值由 shell 提供，用户不能直接进行赋值。

1. `$?`：`$?`表示上一个命令的退出码，用来判断上一个命令是否执行成功。返回值是`0`，表示上个命令执行成功，如果不是 0，表示失败。

2. `$$`：表示当前 shell 的进程 ID。利用这个特殊变量可以命名临时文件

    ```shell
    LOGFILE=/tmp/output_log.$$
    ```

3. `$_`：表示上一个命令的最后一个参数

    ```shell
    $ fd '.*md' ~/Documents/notes/
    ....
    $ echo $_
    ~/Documents/notes/
    ```

4. `$!`：表示最近一个后台执行的异步命令的进程 ID

5. `$0`：表示当前 shell 的名称

6. `$-`：表示当前 shell 的启动参数

7. `$@` 和 `$#`：前者代表脚本的参数数量，后者代表脚本的参数值（可以是一个数组）

### 变量的默认值

Bash 提供四个特殊语法，跟变量的默认值有关，目的是保证变量不为空。

```shell
${varname:-word}
```

上面语法的含义是，如果变量`varname`存在且不为空，则返回它的值，否则返回`word`。它的目的是返回一个默认值，比如`${count:-0}`表示变量`count`不存在时返回`0`。



```shell
${varname:=word}
```

上面语法的含义是，如果变量`varname`存在且不为空，则返回它的值，否则将它设为`word`，并且返回`word`。它的目的是设置变量的默认值，比如`${count:=0}`表示变量`count`不存在时返回`0`，且将`count`设为`0`。



```shell
${varname:+word}
```

上面语法的含义是，如果变量名存在且不为空，则返回`word`，否则返回空值。它的目的是测试变量是否存在，比如`${count:+1}`表示变量`count`存在时返回`1`（表示`true`），否则返回空值。



```shell
${varname:?message}
```

上面语法的含义是，如果变量`varname`存在且不为空，则返回它的值，否则打印出`varname: message`，并中断脚本的执行。如果省略了`message`，则输出默认的信息“parameter null or not set.”。它的目的是防止变量未定义，比如`${count:?"undefined!"}`表示变量`count`未定义时就中断执行，抛出错误，返回给定的报错信息`undefined!`。



上面四种语法如果用在脚本中，变量名的部分可以用数字`1`到`9`，表示脚本的参数。

```shell
filename=${1:?"filename missing."}
```

上面代码出现在脚本中，`1`表示脚本的第一个参数。如果该参数不存在，就退出脚本并报错。



### declare 命令

`declare`命令可以声明一些特殊类型的变量，为变量设置一些限制，比如声明只读类型的变量和整数类型的变量。

它的语法形式如下。

```shell
declare OPTION VARIABLE=value
```

`declare`命令的主要参数（OPTION）如下。

- `-a`：声明数组变量。
- `-f`：输出所有函数定义。
- `-F`：输出所有函数名。
- `-i`：声明整数变量。
- `-l`：声明变量为小写字母。
- `-p`：查看变量信息。`declare -p`可以输出已定义变量的值，对于未定义的变量，会提示找不到。
- `-r`：声明只读变量。
- `-u`：声明变量为大写字母。
- `-x`：该变量输出为环境变量。

`declare`命令如果用在函数中，声明的变量只在函数内部有效，等同于`local`命令。

不带任何参数时，`declare`命令输出当前环境的所有变量，包括函数在内，等同于不带有任何参数的`set`命令。

### let 命令

`let`命令声明变量时，可以直接执行算术表达式。

```
$ let foo=1+2
$ echo $foo
3
```

上面例子中，`let`命令可以直接计算`1 + 2`。

`let`命令的参数表达式如果包含空格，就需要使用引号。

```
$ let "foo = 1 + 2"
```

`let`可以同时对多个变量赋值，赋值表达式之间使用空格分隔。

```
$ let "v1 = 1" "v2 = v1++"
$ echo $v1,$v2
2,1
```

上面例子中，`let`声明了两个变量`v1`和`v2`，其中`v2`等于`v1++`，表示先返回`v1`的值，然后`v1`自增。

## 字符串操作

### 获取字符串长度

```shell
${#字符串变量}
$ echo ${#varname}
12
```

### 提取子字符串

```shell
${varname:offset:length}
${varname:offset}
```

返回变量 varname 从 offset 处，长度为 length 的子字符串。offset 可以为负值，多一个空格（和`${varname:-word}`做区别），表示从末尾倒数offset开始算起。

```shell
$ string="hello world"
$ echo ${string:0:3}
hel
```

但是不能直接对原字符串进行获取，需要对字符串变量进行获取。

```shell
$ echo ${"hello world":0:3}
bash: ${"hello world":0:3}: bad substitution
```

下面例子中，`offset`为`-5`，表示从倒数第5个字符开始截取，所以返回`long.`。如果指定长度`length`为`2`，则返回`lo`；如果`length`为`-2`，表示要排除从字符串末尾开始的2个字符，所以返回`lon`。

```shell
$ foo="This string is long."
$ echo ${foo: -5}
long.
$ echo ${foo: -5:2}
lo
$ echo ${foo: -5:-2}
lon
```

### 搜索和替换

直接看教程[字符串操作](https://wangdoc.com/bash/string.html#搜索和替换)





## read 命令

有时，脚本需要在执行过程中，由用户提供一部分数据，这时可以使用`read`命令。它将用户的输入存入一个变量，方便后面的代码使用。用户按下回车键，就表示输入结束。

`read`命令的格式如下。

```
read [-options] [variable...]
```

上面语法中，`options`是参数选项，`variable`是用来保存输入数值的一个或多个变量名。如果没有提供变量名，环境变量`REPLY`会包含用户输入的一整行数据。除了可以读一行数据，也可以通过默认分隔符将输入进行分割

```shell
$ read a b c
test1 test2 test3
$ echo $a
test1
$ echo $b
test2
$ echo $c
test3
```

也可以读取文件：[示例](/Users/gwx/Documents/notes/bash-note/study-demo/read_cmd/read-timeout.sh)，注意：读取文件都是一行一行的读，并且文件的输入需要通过`<`符号进行重定向。

### read 参数

* `-t`参数设置为超时时间，如果超过就停止接收[示例](/Users/gwx/Documents/notes/bash-note/study-demo/read_cmd/read-timeout.sh)

* `-p`参数设置为用户提示信息，可以代替 echo 提示，[示例](/Users/gwx/Documents/notes/bash-note/study-demo/read_cmd/read-prompt.sh)

* `-a`将输入参数为一个数组。

    ```shell
    $ read -a array
    a b c 
    $ echo ${array[2]}
    c
    ```

* `-n` 指定读取若干个字符个数，[示例](/Users/gwx/Documents/notes/bash-note/study-demo/read_cmd/read-nchars.sh)

*  `-e` 使用 readline 库提供快捷键，自动补全。

### IFS 变量

用于自定义设置 read 命令的分隔符。默认为空格、Tab 符号、换行符号，通常取第一个（即空格），可以自定义其他字符，用来读取文件

```shell
#!/bin/bash

FILE=/etc/passwd

read -p "Enter a username > " username
file_info="$(grep "^username:" $FILE)"

if [[ -n "$file_info" ]]; then
	IFS=":" read user pw uid gid name home shell <<< "$file_name" 
	echo "User = '$user'"
  	echo "UID = '$uid'"
  	echo "GID = '$gid'"
  	echo "Full Name = '$name'"
   	echo "Home Dir. = '$home'"
	echo "Shell = '$shell'"
else 
	echo "No such user '$user_name'" >&2
	exit 1
fi
```

> `<<<` 符号就是 here 文档，将 file_name 转为标准输入，提供给 read 命令。
>
> IFS 和 read 指令一行，因为这样这个变量只会在这一行中生效，不然需要重新修改
>
> ```bash
> OLD_IFS="$IFS"
> IFS=":"
> read user pw uid gid name home shell <<< "$file_info"
> IFS="$OLD_IFS"
> ```



