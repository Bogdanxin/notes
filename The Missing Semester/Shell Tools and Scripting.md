# Shell Tools and Scripting

## Script 脚本

脚本中，使用了特殊的变量代表参数、错误代码和相关变量：

- `$0` - 脚本名
- `$1` 到 `$9` - 脚本的参数。 `$1` 是第一个参数，依此类推。
- `$@` - 所有参数
- `$#` - 参数个数
- `$?` - 前一个命令的返回值
- `$$` - 当前脚本的进程识别码
- `!!` - 完整的上一条命令，包括参数。常见应用：当你因为权限不足执行命令失败时，可以使用 `sudo !!`再尝试一次。
- `$_` - 上一条命令的最后一个参数。如果你正在使用的是交互式 shell，你可以通过按下 `Esc` 之后键入 . 来获取这个值。
- `$(命令)` - 将命令执行结果打印出来



如果需要和字符串搭配使用，一定要用双引号 ""，才能真正提取出指令内容

```shell
#!/bin/bash

echo "Starting program at $(date)" # $(date)打印date 指令的结果，并和字符串拼接
echo "Running program $0 with $# argument with pid $$" 

# 通过 $@ 获取所有参数，遍历所有参数, 注意 ``; do``
for file in "$@"; do
	# grep 查找文件中的指定字符串 foobar， 这里两个重定向流分别为标准输出流和标准错误流，我们并不关心，所以输出到 null 中
	grep foobar "$file" > /dev/null 2> /dev/null
	# if 使用 [[]] 双括号 ，会降低犯错几率 注意 ``; then``
	if [[ $? -ne 0 1 ]]; then
		echo "File $file does not have any foobar, adding one"
		echo "# Foobar" >> "$file"
	fi
done
```



### 通配

* 通配符，使用`?`和`*`通配符匹配一个或者任意个字符。

* 花括号`{}`，如果在指令中有公共子串，可以用花括号自动展开这些命令

    ```
    touch project{1,2}/src/test/test{1,2,3}.tmp
    => touch project1/src/test/test1.tmp project1/src/test/test2.tmp project1/src/test/test3.tmp project2/src/test/test1.tmp project2/src/test/test2.tmp project2/src/test/test3.tmp
    ```



脚本可以是多种类型的，可以用 py，也可以 shell 等等，但是在脚本中一定要有 shebang(`#!`)

> shell函数和脚本有如下一些不同点：
>
> - 函数只能与shell使用相同的语言，脚本可以使用任意语言。因此在脚本中包含 `shebang` 是很重要的。
> - 函数仅在定义时被加载，脚本会在每次被执行时加载。这让函数的加载比脚本略快一些，但每次修改函数定义，都要重新加载一次。
> - 函数会在当前的shell环境中执行，脚本会在单独的进程中执行。因此，函数可以对环境变量进行更改，比如改变当前工作目录，脚本则不行。脚本需要使用 [`export`](httsp://man7.org/linux/man-pages/man1/export.1p.html) 将环境变量导出，并将值传递给环境变量。
> - 与其他程序语言一样，函数可以提高代码模块性、代码复用性并创建清晰性的结构。shell脚本中往往也会包含它们自己的函数定义。



## 其他指令 tool

**find 指令**，可以用于查找文件，并通过指定不同的限制，将范围缩小

```
find . -name src -type d # 在当前目录(.)下找到名字叫 src 的文件夹(type=dir)
find . -path "*/test/*.py" -type f # 在当前目录下，找到父目录为 test 的.py 文件
find . -mtime -1 #查找创建时间为前一天的所有文件
find . -size +500k -size -10M # 查找大小在 500k~10M 之间的的文件
```

同时也可以使用 -exec 参数，对查找得到文件进行执行其他命令操作。

```
# 删除全部扩展名为.tmp 的文件
find . -name '*.tmp' -exec rm {} \;
# 查找全部的 PNG 文件并将其转换为 JPG
find . -name '*.png' -exec convert {} {}.jpg \;
```



可以使用 find 的代替品 fd，更迅速具体的手册可以通过[fdfind 教程](https://github.com/chinanf-boy/fd-zh#教程)查看



**grep 指令**，用于对文件中的文字进行查找，同时也可以使用 rg 指令进行查找，具体手册通过 [ripgrep  guide](https://github.com/BurntSushi/ripgrep/blob/master/GUIDE.md)查看。



**shell 指令查找**：

1. 在 zsh 中使用 history 指令

