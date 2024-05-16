## 引言

clean-code ch4阅读笔记

注释是写代码永远避开不了的话题，需要知道什么是好的，必要的注释。

## 用代码来阐述

```java
// Check to see if the employee is eligible for full benefits
if ((employee.flags & HOURLY_FLAG) && employee.age > 65)

if (employee.isEligibleForFullBenefits())
```

只需要创建一个描述与注释所言同一事物的函数即可。

## 好注释 

唯一真正好的注释是你想办法不去写的注释。

> 对意图的解释

也许不同意程序员给这个问题提供的解决方案，但至少知道他想做什么。

```java

// This is our best attempt to get a race condition
// by creating large number of threads

for(int i = 0; i < 25000; i++) {
    Thread thread = new Thread(widgetBuilderThread);
    thread.start();
......
}
```

> 阐释

```java
assertTure(a.compareTo(a) == 0); // a == a
assertTure(a.compareTo(b) != 0); // a != b
......
```

> 警示

警告其他程序员会出现某种后果的注释也是有用的。

```java
// Don't run unless you 
// have some time to kil
public void _testWithReallyBigFile() {
    ......
}
```

> 放大

注释可以用来放大某种看来不合理之物的重要性。

```java
String listItemContent = match.group(3).trim();
// the trim is real important. It removes the starting
// spaces that could cause the item to be recognized
// as another list.
```

## 坏注释

> 喃喃自语

任何迫使读者查看其他模块的注释，都没能与读者沟通好，不值所费。

> 多余的注释

多余的注释并不能比代码本身提供更多A的信息。没有证明代码的意义，也没有给出代码的意图或逻辑。不如读代码精确。

> 循轨式注释

所谓每个函数都要有Javadoc或每个变量都要有注释的规矩全然是愚蠢可笑的。

> 日志式注释

没有源代码控制系统可用。如今，应当全部删除。

> 可怕的废话

应该我见过最多的注释类型了

```java
/* The name */
private String name;

/* The version */
private String version;

/* The version */ 
private String info;
```

废话注释，并且还有剪贴-粘贴的错误。

> 能用函数或变量时候就别用注释

这个保持质疑态度，内联也是重构代码的一种方法。

```java
// does the module from the global list <mod> depend on the
// subsystem we are part of?

if (smodule.getDependSubsystems().contains(subSysMod.getSubSystem()))
```

可以改成以下没有注释的版本

```java
ArrayList moduleDependees = smodule.getDependSubsystems();
String ourSubSystem = subSysMod.getSubSystem();
if (moduleDependees.contains(ourSubSystem))
```

> 注释掉的代码

注释掉的代码建议不要保留，及时清理。

> 非本地信息

别在本地注释的上下文环境中给出系统级的信息。

> 不明显的联系

注释及其描述的代码之间联系应该显而易见。至少让读者能看着注释和代码，并且理解注释所谈何物。


## 函数头

短函数不需要太多描述。为只做一件事的短函数选个好名字，通常要比写函数头注释要好。
