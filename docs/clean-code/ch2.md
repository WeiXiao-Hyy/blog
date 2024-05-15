## 引言

clean-code ch2阅读笔记

## 有意义的命名

> 名副其实

选择体现本意的名称能让人更容易理解和修改代码。

> 避免误导

怎么能知道该调用哪个函数呢?

```java
getActiveAccount();
getActiveAccounts();
getActiveAccountInfo();
```

moneyAmount与money没区别,customerInfo与customer没区别。

> 使用读得出来的名称

不要使用自造词(nsr=>纳税人)

> 使用可搜索的名称

使用WORK_DAYS_PER_WEEK代替常量5。

```java
const int WORK_DAYS_PER_WEEK = 5;
```

> 避免使用编码

ShapeFactory >> IShapeFactory，如果接口和实现必须选一个来编码的话，使用ShapeFactoryImp。

> 类名

类名和对象名应该是名词或名词短语，如Customer,WikiPage,Account,避免使用Manager,Processor,Data或Info这样的类名。类名不应当是动词。

> 方法名

方法名应当是动词或动词短语，如postPayment,deletePage或save。

重构构造器时，使用描述了参数的静态工厂方法名。

```java
Complex fulcrumPoint = Complex.FromRealNumber(23.0);
```

> 每个概念对应一个词

给每个抽象概念选一个词,使用fetch，retrieve和get来给多个类中的同种方法命名。

> 别用双关词

add方法一种解释为通过增加或连接两个现存值来获得新值;另一种解释为把单个参数放到群集(collection)中则不应该使用add，可以使用insert或append之类词来命名才对。

> 不要添加没用的语境

只要短名称足够清楚，就要比长名称好。别给名称添加不必要的语境。

GSDAccountAddress << PostalAddress