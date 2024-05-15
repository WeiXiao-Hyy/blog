## 引言

clean-code ch3阅读笔记

## 短小

函数的第一规则是要短小，一般来说不要一个函数体不要超过半个屏幕。

## 只做一件事情

函数应该做一件事。做好这件事情。只做一件事。

编写函数毕竟是为了把大一些的概念拆分为另一抽象层上的一系列步骤。只做一件事的函数无法被合理地切分为多个区段。

## switch语句

使用抽象工厂来实现switch语句。

如果switch如果只是出现一次，用于创建多态对象，而且隐藏在某个继承关系中，在系统其他部分看不到，就还能容忍。

PS：就算使用抽象工厂来重构switch，当有新类型增加时，还是需要修改代码同样违反了开放闭合原则。

## 使用描述性的名称

别害怕长名称。长而具有描述性的名称，要比短而令人费解的名称好。

## 函数参数

最理想的参数数量是零，其次是一，再次是二，尽量避免三。

### 避免使用输出参数而非返回值

```java
void includeSetupPageInfo(StringBuffer pageText);
```

上述函数在函数体中修改了pageText的值，结果往往会让人费解。

### 避免标识参数

使用标识参数，则本函数不止做一件事情。

```java
render(boolean isSuite);
```

可以将函数一分为二

```java
renderForSuite();

renderForSignleTest();
```

### 超过三个参数考虑使用参数对象或参数列表

> 参数对象

```java
Circle makeCircle(double x, double y, double radius);
```

上述函数可修改为

```java
Circle makeCricle(Point center, double radius);
```

> 参数列表

例如String.format()方法

```java
String.format("%s worked %.2f hours.". name, hours);
```

## 无副作用

```java
public class UserValidator {
    private Cryptographer cryptographer;
    
    public boolean checkPassword(String userName, String password) {
        User user = ....;
        
        if ("Valid Password".equals(phrase)) {
            Session.initialize(); // 初始化session的副作用
            return true;
        }
    }
}
```

上述代码如果只看函数名称大概率是不知道会初始化session的，应将函数名称修改为checkPasswordAndInitialSession();


## 使用异常代替返回错误码

如果使用异常代替返回错误码，错误处理代码就能从主路径代码中分离出来，得到简化：

```java
try {
    deletePage(page);
    registry.deleteReference(page.name);
    configKeys.deleteKey(page.name.makeKey());
} catch(Exception e) {
    logger.log(e.getMessage());
}
```

## 抽离try/catch代码块

最好把try和catch代码块的主体部分抽离出来，另外形成函数。

```java
public void delete(Page page) {
    try {
        deletePageAndAllReferences(page);
    } catch (Exception e) {
        logError(e);
    }
}

private void deletePageAndAllReferences(Page page) throws Exception {
    deletePage(page);
    registry.deleteReference(page.name);
    configKeys.deleteKey(page.name.makeKey());
}

private void logError(Exception e) {
    logger.log(e.getMessage()); 
}
```

## 别重复自己

算法在函数体中重复了4次，修改时则需要重新修改4个地方，同时也会增加4次放过错误的可能性。


