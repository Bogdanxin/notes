#include<> 和 #include""  的区别：
```shell
#include "..." search starts here:
#include <...> search starts here:
 /usr/lib/gcc/x86_64-linux-gnu/10/include
 /usr/local/include
 /usr/include/x86_64-linux-gnu
 /usr/include
End of search list.
```

> 也就是说，我们通过 <> 是从系统库中引用的，"" 是从当前目录下引用。

如果 <> 引用的头文件，没有在库中，但是我们在本地写了一个，那么可以使用 `gcc a.c -I.` 的形式将 a.c 中的 "" 引用转为 <>，后面的 . 表示当前目录

```shell
#include "..." search starts here:
#include <...> search starts here:
 .
 /usr/lib/gcc/x86_64-linux-gnu/10/include
 /usr/local/include
 /usr/include/x86_64-linux-gnu
 /usr/include
End of search list.
```



![image-20220327105831315](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220327105831315.png)

编译时，不同编译形式会将不同的函数名进行编译，<foo> 和 <_Z3barv> 就是不同的，一个 c 编译，一个 c++ 编译。