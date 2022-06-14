# ELF 文件格式

ELF 文件是一种标准，所有 UNIX 系统的可执行文件都在使用该格式。 ELF 文件又可以分为三种类型：

* 可重定位目标文件
* 可执行文件
* 共享库

首先讨论**目标文件**和**可执行文件**的格式。目标文件是在编译结束后，得到的文件，可执行文件是在将目标文件进行链接操作后得到的文件。

1. 写一个汇编程序保存成文本文件`max.s`。
2. 汇编器读取这个文本文件转换成目标文件`max.o`，目标文件由若干个Section组成，我们在汇编程序中声明的`.section`会成为目标文件中的Section，此外汇编器还会自动添加一些Section（比如符号表）。
3. 然后链接器把目标文件中的Section合并成几个Segment，生成可执行文件`max`。
4. 最后加载器（Loader）根据可执行文件中的Segment信息加载运行这个程序。

链接器会将ELF看做 section 的集合，加载器会将 ELF 看做 Segment 的集合，如图所示。

![asm.elfoverview](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/asm.elfoverview-20220604194156073-20220604204143796.png)

那么我们就可以看出，其实一个 segment 可以由多个 section 组成，Program header table 存储了Segment 对应的地址信息，也就是是指在文件的那个位置，而 section header table 则指出了每个 section 对应的地址信息。

> 需要注意的是，section header table 中可以有多个section 地址信息，同理 program header table 也是；
>
> 第二，section header 和 program header 不一定是在文件的开头和结尾。这里只是简略的画出来了。

通过 `readelf` 指令，可以解析出 elf 文件的格式信息，可以对两种文件进行解析

## **解析目标文件 ELF 结构**

### 文件解析

```asm
ELF Header:
  Magic:   7f 45 4c 46 01 01 01 00 00 00 00 00 00 00 00 00 
  Class:                             ELF32
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              REL (Relocatable file)
  Machine:                           Intel 80386
  Version:                           0x1
  Entry point address:               0x0
  Start of program headers:          0 (bytes into file)
  Start of section headers:          200 (bytes into file)
  Flags:                             0x0
  Size of this header:               52 (bytes)
  Size of program headers:           0 (bytes)
  Number of program headers:         0
  Size of section headers:           40 (bytes)
  Number of section headers:         8
  Section header string table index: 5
Section Headers:
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            00000000 000000 000000 00      0   0  0
  [ 1] .text             PROGBITS        00000000 000034 00002a 00  AX  0   0  4
  [ 2] .rel.text         REL             00000000 0002b0 000010 08      6   1  4
  [ 3] .data             PROGBITS        00000000 000060 000038 00  WA  0   0  4
  [ 4] .bss              NOBITS          00000000 000098 000000 00  WA  0   0  4
  [ 5] .shstrtab         STRTAB          00000000 000098 000030 00      0   0  1
  [ 6] .symtab           SYMTAB          00000000 000208 000080 10      7   7  4
  [ 7] .strtab           STRTAB          00000000 000288 000028 00      0   0  1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings)
  I (info), L (link order), G (group), x (unknown)
  O (extra OS processing required) o (OS specific), p (processor specific)

There are no section groups in this file.

There are no program headers in this file.

Relocation section '.rel.text' at offset 0x2b0 contains 2 entries:
 Offset     Info    Type            Sym.Value  Sym. Name
00000008  00000201 R_386_32          00000000   .data
00000017  00000201 R_386_32          00000000   .data

There are no unwind sections in this file.

Symbol table '.symtab' contains 8 entries:
   Num:    Value  Size Type    Bind   Vis      Ndx Name
     0: 00000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 00000000     0 SECTION LOCAL  DEFAULT    1 
     2: 00000000     0 SECTION LOCAL  DEFAULT    3 
     3: 00000000     0 SECTION LOCAL  DEFAULT    4 
     4: 00000000     0 NOTYPE  LOCAL  DEFAULT    3 data_items
     5: 0000000e     0 NOTYPE  LOCAL  DEFAULT    1 start_loop
     6: 00000023     0 NOTYPE  LOCAL  DEFAULT    1 loop_exit
     7: 00000000     0 NOTYPE  GLOBAL DEFAULT    1 _start

No version information found in this file.
```

解析出来后，发现没有 program header，正好说明 Program Header 存储 Segment，存在于可执行文件中。同时，我们可以看到在 ELF Header 中，展示了本文件 section、section Header、Program Header 等信息，指出了当前文件的起始地址等等信息。

同时查看 Section Headers，可以发现每个 header 指向了对应的 section，Off 就是每个 section 的起始地址，size 就是对应的大小。这样我们就可以轻松的画出这个目标文件的布局了。

| 起始地址(Off) | Section或Header      | Size |
| ------------- | :------------------- | ---- |
| 0             | ELF Header           | 0x34 |
| 0x34          | `.text`              | 0x2a |
| 0x60          | `.data`              | 0x38 |
| 0x98          | `.bss`（此段为空）   | 0x00 |
| 0x98          | `.shstrtab`          | 0x30 |
| 0xc8          | Section Header Table | 0x28 |
| 0x208         | `.symtab`            | 0x80 |
| 0x288         | `.strtab`            | 0x28 |
| 0x2b0         | `.rel.text`          | 0x10 |

### section 分析

同时，我们也可以用`hexdump`指令将文件的字节打印出来，这里就不过多展示了。可以根据上表中的文件地址，找到对应的字节码，然后对字节码进行解析，就会发现每个 section 的作用了。

`.data` 节保存的就是汇编程序中的 `.data` 中的数据，`.shstrtab`节中保存的是每个 section 的名字，`.strtab`保存的是程序中用到的符号名字。

C 语言的全局变量如果在代码中没有初始化，就会在程序加载时用0初始化。这种数据属于`.bss`段，在加载时它和`.data`段一样都是可读可写的数据，但是在ELF文件中`.data`段需要占用一部分空间保存初始值，而`.bss`段则不需要。也就是说，`.bss`段在文件中只占一个Section Header而没有对应的Section，程序加载时`.bss`段占多大内存空间在Section Header中描述。

最后还有两个`.rel.text`和`.symtab`。`.rel.text` 告诉链接器那个地方需要进行重定位。`.symtab` 则是将`.strtab`中的每个字符通过 Ndx 字段定位到对应的section 中，比如 data_items 字符就对应到 3 号 section 也就是`.data`中，Value 作为偏移量字段，如果多个字符在同一个 section 中，那么这些字段一定会有前后关系，而这种顺序就是通过 Value 这个偏移字段进行体现。比如 `_start`、`loop_exit`和`start_loop`三个字符，都在`.text` section 中，通过 value 发现，`_start`是最开始的字符，然后是`start_loop`再是`loop_exit`。这里还有一个 Bind字段，只有`_start`字段，是 GLOBAL 的，是因为在代码中声明中指定了`.global`的。

### 反汇编代码

但是我们没有得到真正需要执行的代码，也就是`.text` 的内容，这时，我们可以通过`objdump`指令，将具体的代码反汇编出来，就能得到一个汇编代码以及对应的字节码指令。

```asm
Disassembly of section .text:

00000000 <_start>:
   0:	bf 00 00 00 00       	mov    $0x0,%edi
   5:	8b 04 bd 00 00 00 00 	mov    0x0(,%edi,4),%eax
   c:	89 c3                	mov    %eax,%ebx

0000000e <start_loop>:
   e:	83 f8 00             	cmp    $0x0,%eax
  11:	74 10                	je     23 <loop_exit>
  13:	47                   	inc    %edi
  14:	8b 04 bd 00 00 00 00 	mov    0x0(,%edi,4),%eax
  1b:	39 d8                	cmp    %ebx,%eax
  1d:	7e ef                	jle    e <start_loop>
  1f:	89 c3                	mov    %eax,%ebx
  21:	eb eb                	jmp    e <start_loop>

00000023 <loop_exit>:
  23:	b8 01 00 00 00       	mov    $0x1,%eax
  28:	cd 80                	int    $0x80
```

左边是机器指令的字节，右边是反汇编结果。显然，所有的符号都被替换成地址了，比如`je 23`，注意没有加`$`的数表示内存地址，而不表示立即数。这条指令后面的`<loop_exit>`并不是指令的一部分，而是反汇编器从`.symtab`和`.strtab`中查到的符号名称，写在后面是为了有更好的可读性。目前所有指令中用到的符号地址都是相对地址，下一步链接器要修改这些指令，把其中的地址都改成加载时的内存地址，这些指令才能正确执行。

>可以看出，`readelf`指令读取的是 elf 文件的文件结构（比如 header 信息、section 信息等等），没有将结构中保存的数据解析出来，也没有将需要执行的代码解析出来。这时，就需要`hexdump`指令读取文件的字节信息，通过上述文件结构信息，找到对应的地址，根据地址查看存储的数据（一般是.data节）。同时需要`objdump`指令解析出代码指令（一般是.text 段）。

## 对可执行文件解析

```asm
ELF Header:
  Magic:   7f 45 4c 46 01 01 01 00 00 00 00 00 00 00 00 00 
  Class:                             ELF32
  Data:                              2's complement, little endian
  Version:                           1 (current)
  OS/ABI:                            UNIX - System V
  ABI Version:                       0
  Type:                              EXEC (Executable file)
  Machine:                           Intel 80386
  Version:                           0x1
  Entry point address:               0x8048074
  Start of program headers:          52 (bytes into file)
  Start of section headers:          256 (bytes into file)
  Flags:                             0x0
  Size of this header:               52 (bytes)
  Size of program headers:           32 (bytes)
  Number of program headers:         2
  Size of section headers:           40 (bytes)
  Number of section headers:         6
  Section header string table index: 3

Section Headers:
  [Nr] Name              Type            Addr     Off    Size   ES Flg Lk Inf Al
  [ 0]                   NULL            00000000 000000 000000 00      0   0  0
  [ 1] .text             PROGBITS        08048074 000074 00002a 00  AX  0   0  4
  [ 2] .data             PROGBITS        080490a0 0000a0 000038 00  WA  0   0  4
  [ 3] .shstrtab         STRTAB          00000000 0000d8 000027 00      0   0  1
  [ 4] .symtab           SYMTAB          00000000 0001f0 0000a0 10      5   6  4
  [ 5] .strtab           STRTAB          00000000 000290 000040 00      0   0  1
Key to Flags:
  W (write), A (alloc), X (execute), M (merge), S (strings)
  I (info), L (link order), G (group), x (unknown)
  O (extra OS processing required) o (OS specific), p (processor specific)

There are no section groups in this file.

Program Headers:
  Type           Offset   VirtAddr   PhysAddr   FileSiz MemSiz  Flg Align
  LOAD           0x000000 0x08048000 0x08048000 0x0009e 0x0009e R E 0x1000
  LOAD           0x0000a0 0x080490a0 0x080490a0 0x00038 0x00038 RW  0x1000

 Section to Segment mapping:
  Segment Sections...
   00     .text 
   01     .data 

There is no dynamic section in this file.

There are no relocations in this file.

There are no unwind sections in this file.

Symbol table '.symtab' contains 10 entries:
   Num:    Value  Size Type    Bind   Vis      Ndx Name
     0: 00000000     0 NOTYPE  LOCAL  DEFAULT  UND 
     1: 08048074     0 SECTION LOCAL  DEFAULT    1 
     2: 080490a0     0 SECTION LOCAL  DEFAULT    2 
     3: 080490a0     0 NOTYPE  LOCAL  DEFAULT    2 data_items
     4: 08048082     0 NOTYPE  LOCAL  DEFAULT    1 start_loop
     5: 08048097     0 NOTYPE  LOCAL  DEFAULT    1 loop_exit
     6: 08048074     0 NOTYPE  GLOBAL DEFAULT    1 _start
     7: 080490d8     0 NOTYPE  GLOBAL DEFAULT  ABS __bss_start
     8: 080490d8     0 NOTYPE  GLOBAL DEFAULT  ABS _edata
     9: 080490d8     0 NOTYPE  GLOBAL DEFAULT  ABS _end

No version information found in this file.
```

在ELF Header中，`Type`改成了`EXEC`，由目标文件变成可执行文件了，`Entry point address`改成了0x8048074（这是`_start`符号的地址），还可以看出，多了两个Program Header，少了两个Section Header。

在Section Header Table中，`.text`和`.data`段的加载地址分别改成了0x08048074和0x080490a0。`.bss`段没有用到，所以被删掉了。`.rel.text`段就是用于链接过程的，做完链接就没用了，所以也删掉了。

多出来的Program Header Table描述了两个Segment的信息。`.text`段和前面的ELF Header、Program Header Table一起组成一个Segment（`FileSiz`指出总长度是0x9e），`.data`段组成另一个Segment（总长度是0x38）。`VirtAddr`列指出第一个Segment加载到虚拟地址0x08048000（注意在x86平台上后面的`PhysAddr`列是没有意义的，并不代表实际的物理地址），第二个Segment加载到地址0x080490a0。`Flg`列指出第一个Segment的访问权限是可读可执行，第二个Segment的访问权限是可读可写。最后一列`Align`的值0x1000（4K）是x86平台的内存页面大小。在加载时文件也要按内存页面大小分成若干页，文件中的一页对应内存中的一页，对应关系如下图所示。

![asm.load](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/asm.load.png)

这个可执行文件很小，总共也不超过一页大小，但是两个Segment必须加载到内存中两个不同的页面，因为MMU的权限保护机制是以页为单位的，一个页面只能设置一种权限。此外还规定每个Segment在文件页面内偏移多少加载到内存页面仍然要偏移多少，比如第二个Segment在文件中的偏移是0xa0，在内存页面0x08049000中的偏移仍然是0xa0，所以从0x080490a0开始，这样规定是为了简化链接器和加载器的实现。从上图也可以看出`.text`段的加载地址应该是`0x08048074`，`_start`符号位于`.text`段的开头，所以`_start`符号的地址也是0x08048074，从符号表中可以验证这一点。

>  说白了，就是将相对地址转换为绝对地址，然后文件的类型转为 EXEC 可执行。添加了几个新的符号。将若干 section 合并成segment 等操作。

