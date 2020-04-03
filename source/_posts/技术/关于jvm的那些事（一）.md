---
title: 关于jvm的那些事（一）
date: 2017-02-16 14:32:29
tags: 
    - 技术 
    - jvm
---
# 开场问题
这也是最近发生的一个B-U-G

现象：过年值班期间，还是大年30晚饭时间，老板约我们值班的一行人去吃年夜饭。

我们兴高采烈走到饭店楼下，等电梯了，突然接到一个电话。

好吧，是那个万恶的老蔡！！



> ‘诶，王章啊，短信收到了吗？’

> ‘鱼塘发货吗？ 收到了，收到了！’

> ‘是那个没有兑付的短信’

> ‘啊？什么付？’

> ‘兑付啊’

> ‘哦，兑付啊’  此时心里一万个草泥马啊


看了下手机。。。

![](https://timgsa.baidu.com/timg?image&quality=80&size=b9999_10000&sec=1487332897577&di=c922cf2159bb4707be1041da738fb967&imgtype=0&src=http%3A%2F%2Fs3.sinaimg.cn%2Fmiddle%2F53a936a5gbcd6ada09662%26690)

![](http://upload.ouliu.net/i/20170217152040jvkfh.jpeg)

脸都绿了，果然收到了， 拉上db鹏和蔡食屎就又匆匆回去了。望着老王那些人，心里那个堵啊！

好吧，我们来看下问题吧

先介绍下打金融事业部的 颜值理财产品兑付兑付流程：

![](http://upload.ouliu.net/i/20170217153706i7jg9.png)

我们的理财服务是好的，因为用户都是能购买理财的，而兑付服务也在理财服务上，理论上应该也是正常工作不是吗？？

思考下有那些环节可能出问题

那我们首先想到的是定时任务不工作了，然而通过quartz的日志我们发现，还真是工作了！！

![](http://upload.ouliu.net/i/20170217160229y0po6.png)

那我们继续找下 日志，那到底是发生什么了

![](http://upload.ouliu.net/i/20170217160354gmq0j.png)
看下可能是什么问题！！

细心的小伙伴肯定能关注到这里了。。

![](http://upload.ouliu.net/i/20170217160737ow1m9.png)

cause: message can not send, because channel is closed？？

我们再看下调用处java代码！！

![](http://upload.ouliu.net/i/20170217162041dz6dv.png)

是不是有问题？？是不是有问题？？

![](http://upload.ouliu.net/i/201702171621082i6o9.png)

cause: message can not send, because channel is closed
调用失败：原因是 通道关闭！

我们知道dubbo发生这个错误的原因基本上都是服务没有启动！有木有？？（ 具体可以参见源码，有时间跟大家分享下dubbo的源码）

我们看服务是否启动可以在dubbo Admin上去看,这样排查问题确实会比较迅速！

这个时候我们可以去看dubbo Admin上 finance理财服务是否存在吧？

上个图，因为现场不在了，所以上个非现场的图

![](http://upload.ouliu.net/i/20170217163601tyvj9.png)

那这一连串的事，是不是可以串起来告诉我们为什么兑付失败了吧！

于是我们启动了165服务！然而 事情才解决了一半，还没有恢复兑付呢！！

不得不夸奖下金融部门的小伙伴啊，不知道是谁想出来的（自己站出来），做了个face-admin平台，这个平台有如下功能

![](http://upload.ouliu.net/i/20170217163946vv3rp.jpeg)

啊 就在一瞬间啊 我们兑付又愉快的开始了。

事情到这里，只是开始，难道不是吗？？ 到底为什么机器突然挂了！！！ 我们百思不得其解。。。。

第二天我们分析了我们finance的内存情况（MAT分析工具），想以此来查找程序中造成异常关闭的蛛丝马迹，结果是毫无破绽！！！

于是我们开始将我们的目光放在了系统的配置上

我们先来看下165机器的 一些硬件状态，cpu，硬盘等资源都是正常的不能再正常的，剩下只有内存了！
我们先来看几个图

![](http://upload.ouliu.net/i/20170217164710c9bg3.png)

可用内存 濒临‘灭绝’啊 有木有啊！！

下面是服务被关闭之后的情况

![](http://upload.ouliu.net/i/20170217164735f4rnb.png)

那么我们是否可以判断出，内存被无限制的使用，导致操作系统为了维护系统稳定，强制关闭了我们的应用

带着这个怀疑我们看下 近一个月的系统整体的状态图

![](http://upload.ouliu.net/i/20170217165548eb6hf.png)


我们看下 这几个区域是不是可以这么假设

似乎是说的通的哦！

那么我们来看看 万恶的紧紧们，在我们的tomcat上做了怎么样的配置：

```
vim /opt/wgj2/wgj-finance/bin/catalina.shCATALINA_OPTS="-server -Xss512k -Xms8192M -Xmx8192M -Xmn2048M -XX:PermSize=512M -XX:CMSFullGCsBeforeCompaction=0 
-XX:CMSInitiatingOccupancyFraction=75 -XX:CMSMaxAbortablePrecleanTime=30000 -XX:+UseConcMarkSweepGC -XX:+UseParNewGC -XX:SurvivorRatio=6
-XX:+PrintGCDetails -XX:+PrintGCDateStamps -XX:+PrintHeapAtGC -Xloggc:/opt/wgj2/wgj-server/logs/gc.log
-XX:ParallelGCThreads=8 -Djavax.servlet.request.encoding=UTF-8 -Djavax.servlet.response.encoding=UTF-8 -Dfile.encoding=UTF-8
-Duser.timezone=Asia/Shanghai -Dcom.sun.management.jmxremote -Dcom.sun.management.jmxremote.port=12346 
-Dcom.sun.management.jmxremote.ssl=false -Dcom.sun.management.jmxremote.authenticate=false -Djava.rmi.server.hostname=192.168.0.165
-Xdebug -Xnoagent -Xrunjdwp:transport=dt_socket,address=9999,server=y,suspend=n"

cat /proc/meminfo

MemTotal:7963036 kB
MemFree:  152096 kB
Buffers:  130768 kB
Cached:  1685188 kB
SwapCached:0 kB
Active:  5338728 kB
Inactive:2179496 kB
Active(anon):4431500 kB
Inactive(anon):  1271408 kB
Active(file): 907228 kB
Inactive(file):   908088 kB
Unevictable:   0 kB
Mlocked:   0 kB
SwapTotal:  16515068 kB
SwapFree:   16515068 kB
Dirty:  2664 kB
Writeback: 0 kB
AnonPages:   5702388 kB
Mapped: 9808 kB
Shmem:   524 kB
Slab: 190996 kB
SReclaimable: 126280 kB
SUnreclaim:64716 kB
KernelStack:   10416 kB
PageTables:13920 kB
NFS_Unstable:  0 kB
Bounce:0 kB
WritebackTmp:  0 kB
CommitLimit:20496584 kB
Committed_AS:7698828 kB
VmallocTotal:   34359738367 kB
VmallocUsed:  161408 kB
VmallocChunk:   34359569276 kB
HardwareCorrupted: 0 kB
AnonHugePages:   5545984 kB
HugePages_Total:   0
HugePages_Free:0
HugePages_Rsvd:0
HugePages_Surp:0
Hugepagesize:   2048 kB
DirectMap4k:8192 kB
DirectMap2M: 1990656 kB
DirectMap1G: 6291456 kB
```

好吧 这台机器 一共才8个G内存，他们给我们应用也配置了这么大的内存！导致应用不停的去吃内存，到后来达到系统临界值，强制被关闭！！

醉了醉了~

至此问题算是早到了，我们又可以让紧紧请客了。

可恶的是，那天老板以为是我们开发的问题，这个问题你们说是谁的问题？？万恶的紧紧们啊。。。

但是，我们都是研发中心的 要有集体荣誉感，好吧 当我没说

# 事件小结
事情虽然过去，。。。。。。。。。。。。

# jvm命令解析
CATALINA_OPTS=”-server -Xss512k -Xms6144M -Xmx6144M 
-Xmn2048M 
-XX:PermSize=512M 
-XX:CMSFullGCsBeforeCompaction=0
-XX:CMSInitiatingOccupancyFraction=75 
-XX:CMSMaxAbortablePrecleanTime=30000 
-XX:+UseConcMarkSweepGC -XX:+UseParNewGC 
-XX:SurvivorRatio=6
-XX:+PrintGCDetails 
-XX:+PrintGCDateStamps 
-XX:+PrintHeapAtGC 
-Xloggc:/opt/wgj2/wgj-server/logs/gc.log
-XX:ParallelGCThreads=8 -Djavax.servlet.request.encoding=UTF-8 
-Djavax.servlet.response.encoding=UTF-8 
-Dfile.encoding=UTF-8
-Duser.timezone=Asia/Shanghai 
-Dcom.sun.management.jmxremote 
-Dcom.sun.management.jmxremote.port=12346
-Dcom.sun.management.jmxremote.ssl=false 
-Dcom.sun.management.jmxremote.authenticate=false 
-Djava.rmi.server.hostname=192.168.0.165
-Xdebug -Xnoagent -Xrunjdwp:transport=dt_socket,address=9999,server=y,suspend=n”

