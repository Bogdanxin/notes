# vim usage
* h j k l <- | ^ ->
	     v |
* x -> delete a character
* a -> add

 
* w -> word, e -> end, $ -> a line
* d -> delete some :
 1. d [nums] motion: dw de d$
 2. dd delete a line


* r -> replace
  r+character
* c -> change: cw ce c$
 1. c [nums] motion
* p -> paragraph 
* u -> undo, U -> undo a line, CTRL+R -> redo last undo(x

* G -> goto
 1. CTRL-G -> show the file info
 2. gg goto the first line
 3. G -> goto the last line
 4. [nums] + G -> goto nums line

* search orders
 1. '/' +[string] -> search the string in postive order
 2. '?' + [string] -> search the string in reverse order
 3. search  + n , search + N
 4. CTRL-O & CTRL-I

* match [] {} and () -> use [%]

* replace order:
  1. CTRL-G 用于显示当前光标所在位置和文件状态信息。
     G 用于将光标跳转至文件最后一行。
     先敲入一个行号然后输入大写 G 则是将光标移动至该行号代表的行。
     gg 用于将光标跳转至文件第一行。

  2. 输入 / 然后紧随一个字符串是在当前所编辑的文档中正向查找该字符串。
     输入 ? 然后紧随一个字符串则是在当前所编辑的文档中反向查找该字符串。
     完成一次查找之后按 n 键是重复上一次的命令，可在同一方向上查
     找下一个匹配字符串所在；或者按大写 N 向相反方向查找下一匹配字符串所在。
     CTRL-O 带您跳转回较旧的位置，CTRL-I 则带您到较新的位置。

  3. 如果光标当前位置是括号(、)、[、]、{、}，按 % 会将光标移动到配对的括号上。

  4. 在一行内替换头一个字符串 old 为新的字符串 new，请输入  :s/old/new
     在一行内替换所有的字符串 old 为新的字符串 new，请输入  :s/old/new/g
     在两行内替换所有的字符串 old 为新的字符串 new，请输入  :#,#s/old/new/g
     在文件内替换所有的字符串 old 为新的字符串 new，请输入  :%s/old/new/g
     进行全文替换时询问用户确认每个替换需添加 c 标志        :%s/old/new/gc


*  执行 order
  1. :!command 用于执行一个外部命令 command。

     请看一些实际例子：
         (MS-DOS)         (Unix)
          :!dir            :!ls            -  用于显示当前目录的内容。
          :!del FILENAME   :!rm FILENAME   -  用于删除名为 FILENAME 的文件。

  2. :w FILENAME  可将当前 VIM 中正在编辑的文件保存到名为 FILENAME 的文
     件中。

  3. v motion :w FILENAME 可将当前编辑文件中可视模式下选中的内容保存到文件
     FILENAME 中。

  4. :r FILENAME 可提取磁盘文件 FILENAME 并将其插入到当前文件的光标位置
     后面。

  5. :r !dir 可以读取 dir 命令的输出并将其放置到当前文件的光标位置后面。


*第六讲小结

  1. 输入小写的 o 可以在光标下方打开新的一行并进入插入模式。
     输入大写的 O 可以在光标上方打开新的一行。

  2. 输入小写的 a 可以在光标所在位置之后插入文本。
     输入大写的 A 可以在光标所在行的行末之后插入文本。

  3. e 命令可以使光标移动到单词末尾。

  4. 操作符 y 复制文本，p 粘贴先前复制的文本。

  5. 输入大写的 R 将进入替换模式，直至按 <ESC> 键回到正常模式。

  6. 输入 :set xxx 可以设置 xxx 选项。一些有用的选项如下：
        'ic' 'ignorecase'       查找时忽略字母大小写
        'is' 'incsearch'        查找短语时显示部分匹配
        'hls' 'hlsearch'        高亮显示所有的匹配短语
     选项名可以用完整版本，也可以用缩略版本。

  7. 在选项前加上 no 可以关闭选项：  :set noic
