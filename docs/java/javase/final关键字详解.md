## 引言

阅读《Java并发编程实战》的基础知识篇发现java中的final作用实在是太大了，故结合实例深入剖析final关键字。

## 基础

### 修饰类

final修饰类时意味着该类不能被继承,所有方法都将为final,所有在final类中给任何方法添加final是没有任何意义的。

### 修饰方法

private方法是隐式的final，final方法是可以重载的。

### 修饰参数

将参数列表中的参数申明为final，意味着无法在方法中更改参数引用所指向的对象。常常用在匿名内部类中。

```java
interface GreetingService {
    void greet(String message);
}

public void executeGreeting(final String name) {
    GreetingService service = new GreetingService() {
        @Override
        public void greet(String message) {
            name = "hello"; // 报错
            System.out.println(message + " " + name);
        }
    };

    service.greet("Hello");
}
```

注意从Java8开始，即使局部变量和参数没有显式地被声明为final，只要它们实际上没有被修改，就可以在匿名内部类或lambda表达式中使用。

### 修饰变量

> 编译期常量和非编译期常量

```java
import java.util.Random;

public class Test {
    //编译期常量
    final int i = 1;
    //非编译期常量
    Random random = new Random();
    final int k = random.nextInt();
}
```

所以final修饰的字段不都是编译期间常量，如上的k只是在初始化之后无法被更改了。

> static final 

static final 只占据一段不能改变的存储空间，必须在定义的时候进行赋值。

> blank final 

允许生成空白final，但是该字段被使用之前需要被赋值，通常在构造器进行赋值。

> final修饰引用变量

被final修饰的变量无法被改变引用，但引用变量内部仍然可以修改值，如下。

```java
import java.util.ArrayList;

public class Test {
    private final List<Integer> list = new ArrayList<>();
    
    
    public void add(int num) {
        list.add(num); //是允许的
    }
    
    public void change(List<Integer> otherList) {
        list = otherList; //不被允许
    }
}
```

## 指令重排序

### final为基本类型

#### 写final域重排序规则

```java
/**
 * @author hyy (hjlbupt at 163 dot com)
 */
public class FinalInitialDemo {

    private int a;
    private boolean flag;
    private FinalInitialDemo demo;

    public FinalInitialDemo() {
        a = 1;
        flag = true;
    }

    public void writer() {
        demo = new FinalInitialDemo();
    }

    public void reader() {
        if (flag) {
            int i = a * a;
            if (i == 0) {
                // On my dev machine, the variable initial always success.
                // To solve this problem, add final to the `a` field and `flag` field.
                System.out.println("Fuck! instruction reordering occurred.");
            }
        }
    }

    @SuppressWarnings("InfiniteLoopStatement")
    public static void main(String[] args) throws Exception {
        while (true) {
            FinalInitialDemo demo = new FinalInitialDemo();
            Thread threadA = new Thread(demo::writer);
            Thread threadB = new Thread(demo::reader);

            threadA.start();
            threadB.start();

            threadA.join();
            threadB.join();
        }
    }
}
```

上述代码存在并发安全问题，writer和reader同时进行，writer线程进行类的初始化，此时JVM可能会进行指令的重排序，将a,flag等变量的初始化赋值重排序到构造函数之外，导致reader读取的a,flag变量是基础变量的初始值即0和false(指令顺序不一定发生,并且需要特定的硬件和JVM环境)

> 原理

- JMM禁止编译器把final域的写重排序到构造函数之外
- 编译器会在final域写之后，构造函数return之前，插入一个storestore屏障，可以禁止处理器把final域的写重排序到构造函数之外。

#### 读final域重排序规则

```java
/**
 * @author hyy (hjlbupt at 163 dot com)
 */
public class FinalInitialDemo {

    private int a;
    private boolean flag;
    private FinalInitialDemo demo;

    public FinalInitialDemo() {
        a = 1;
        flag = true;
    }

    public void writer() {
        demo = new FinalInitialDemo();
    }

    public void reader() {
       FinalInitialDemo referenceDemo = demo;
       int a = referenceDemo.a;
       boolean flag = referenceDemo.flag;
    }

    @SuppressWarnings("InfiniteLoopStatement")
    public static void main(String[] args) throws Exception {
        while (true) {
            FinalInitialDemo demo = new FinalInitialDemo();
            Thread threadA = new Thread(demo::writer);
            Thread threadB = new Thread(demo::reader);

            threadA.start();
            threadB.start();

            threadA.join();
            threadB.join();
        }
    }
}
```

观察到reader线程读取FinalInitialDemo的引用，成员变量a和flag。如果reader在未读取到对象的引用时，就在读取对象的普通域变量，这显然是错误的操作。

> 原理

- 在读一个对象的final域之前，一定会先读这个包含final域对象的引用
- 编译器会在读final域操作的前面插入一个loadload屏障，可以禁止处理器读取对象的普通域在读取对象引用之前。

### final为引用类型

#### 写final域重排序规则

这里参考了[pdai.tech博客](https://pdai.tech/md/java/thread/java-thread-x-key-final.html)中的内容

```java
public class FinalReferenceDemo {
    final int[] arrays;
    private FinalReferenceDemo finalReferenceDemo;

    public FinalReferenceDemo() {
        arrays = new int[1];  //1
        arrays[0] = 1;        //2
    }

    public void writerOne() {
        finalReferenceDemo = new FinalReferenceDemo(); //3
    }

    public void writerTwo() {
        arrays[0] = 2;  //4
    }

    public void reader() {
        if (finalReferenceDemo != null) {  //5
            int temp = finalReferenceDemo.arrays[0];  //6
        }
    }

    @SuppressWarnings("InfiniteLoopStatement")
    public static void main(String[] args) throws Exception {
        while (true) {
            FinalReferenceDemo demo = new FinalReferenceDemo();
            Thread threadA = new Thread(demo::writerOne);
            Thread threadB = new Thread(demo::writerTwo);
            Thread threadC = new Thread(demo::reader);

            threadA.start();
            threadB.start();
            threadC.start();

            threadA.join();
            threadB.join();
            threadC.join();
        }
    }
}
```
线程A先执行writerOne方法，线程B执行writerTwo方法，线程C执行reader方法。在构造函数内对一个final修饰的对象的成员域的写入，与随后在构造函数之外把这个被构造的对象的引用赋给一个引用变量，这两个操作是不能被重排序的。

> 原理

由于对final域的写禁止重排序到构造方法外，因此1和3不能被重排序。由于一个final域的引用对象的成员域写入不能与随后将这个被构造出来的对象赋给引用变量重排序，因此2和3不能重排序(简单来说即是要等构造函数对final域操作完成后才能进行其他操作)。

#### 读final域重排序规则

上述代码只能保证线程C能看到线程A对final引用的对象的成员域的写入，即能看到arrays[0]=1。而线程B对数组元素的写入是否能看到就不确定了(线程B和线程C存在数据竞争)。

### 防止重排序的前提条件

上述谈到final域初始化和构造函数初始化之间不能发生指令重排序有一个前提条件:该对象的引用不能在构造函数中“逸出”。

### This引用逃逸

参考《Java并发编程实战》的内容，作者提到了两个常见的对象逸出情况：

- 在构造函数中注册事件监听
- 在构造函数中启动新线程

```java
public class ThisEscape {
    private final int var;
    
    public ThisEscape(EventSource source) {
        source.registerListener(
            new EventListener() {
                public void onEvent(Event e) {
                    doSomething(e); //一旦注册成功则可能触发回调, 导致访问var变量可能是未赋值的变量,
                    // 隐含发布了ThisEscape实例本身.
                }
            });
        
        // other initial......
        
        var = 1;
    }
    
    public void doSomething(Event e) {
        System.out.println(var);
    }
}
```

```java
public class ThisEscape {
    private final int var;

    public ThisEscape() {
        new Thread(new EscapeRunnable()).start();
        // ...
        
        var = 1;
    }

    private class EscapeRunnable implements Runnable {
        @Override
        public void run() {
            System.out.println(ThisEscape.this.var);
            // ThisEscape.this就可以引用外围类对象, 但是此时外围类对象可能还没有构造完成, 
            // 即发生了外围类的this引用的逃逸
        }
    }
} 
```

简单来说，this逃逸就是说在构造函数返回之前其他线程就持有该对象的引用，调用尚未构造完全的对象的方法可能引发错误。

> 解决方案

```java
public class SafeListener {
    private final EventListener listener;
    
    private SafeListener() {
        listener = new EventListener() {
            public void onEvent(Event e) {
                doSomething(e);
            }
        }
    }
    
    public static SafeListener newInstance(EventSource source) {
        SafeListener safe = new SafeListener();
        source.registerListener(safe.listener);
        return safe;
    }
}
```

## 参考资料

- [https://pdai.tech/md/java/thread/java-thread-x-key-final.html](https://pdai.tech/md/java/thread/java-thread-x-key-final.html)
- [https://blog.csdn.net/liuwg1226/article/details/119955371](https://blog.csdn.net/liuwg1226/article/details/119955371)