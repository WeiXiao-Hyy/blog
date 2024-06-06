## 引言

有时候，我们需要推迟一些高开销的对象初始化操作，并且只有当使用这些对象时才进行初始化。这让我立马反应到DCL的写法，但很快就被打脸，《Java并发编程实战》中表示不太推荐使用DCL。本文记录安全初始化的几个方式。

PS：[fucking-java-concurrency代码解读](https://juejin.cn/post/7371671537509187596)上次学习了并发知识后，给仓库提交了一个final案例，没想到大佬很快就merge了，还给了我contributor，很开心，欢迎学习和Star！

附上仓库链接：[https://github.com/WeiXiao-Hyy/blog](https://github.com/WeiXiao-Hyy/blog)

## 线程安全的延迟初始化

```java
public class SafeLazyInitialization {
    private static Resource resource;
    
    public synchronized static Resource getInstance() {
        if (resource == null) {
            resource = new Resource();
        }
        return resource;
    }
}
```

getInstance的代码路径很短，因此如果getInstance没有被多个线程频繁调用，那么SafeLazyInitialization上不会存在激烈的竞争，从而能提供令人满意的性能。

### 静态初始化的对象都不需要显式的同步

> 静态代码块和静态变量初始化
>

静态代码块和静态变量初始化在类加载后并且被线程使用之前。并且JVM将在初始化期间获得一个锁，这个锁用于确保类的初始化在多线程环境下是安全的。每个线程至少获取一次锁，可能有多个线程同时尝试使用同一个类，而JVM需要确保类的初始化只被执行一次，在初始化完成之前，其他线程需要等待。

因此无论是在被构造期间还是被引用，静态初始化的对象都不需要显式的同步。

## 提前初始化

通过使用提前初始化，避免了在每次调用SafeLazyInitialization中的getInstance时所产生的同步开销。

```java
public class EagerInitialzation {
    private static Resource resource = new Resource();
    
    public static Resource getResource() {
        return resource;
    }
}
```

## 延长初始化占位类模式

> 首先明确静态内部类的加载过程
>

静态内部类的加载不需要依附外部类，在使用时才会加载。同时在加载静态内部类的过程中也会加载外部类。

通过以上理论可以形成一种延迟初始化技术，从而在常见的代码路径并不需要同步。

```java
public class ResourceFactory {
    private static class ResourceHolder {
        private static Resource resource = new Resource();
    }
    
    public static Resource getResource() {
        return ResourceHolder.resource;
    }
}
```

## 双重检查加锁 (DCL)

相信每个面过试的人很快就能写出以下代码。

```java
public class Singleton {
    
    private static Singleton instance;
    
    //私有构造函数
    private Singleton() {
    }
    
    public Singleton getInstance() {
        if (instance == null) {
            synchronized (Singleton.class) {
                if (instance == null) {
                    instance = new Singleton();
                }
            }
        }
        return instance;
    }
}
```

然而上述代码是有问题的，理由是new Singleton()并不是原子操作，有可能会被编译器进行指令重排操作。

```java
memory = allocate(); //1：分配对象的内存空间 
ctorInstance(memory);//2：初始化对象 
instance = memory;   //3：设置instance指向刚分配的内存地址
```

上面操作2依赖于操作1，但操作并不依赖操作2，所有可能出现如下执行顺序：

```java
memory = allocate();   //1：分配对象的内存空间 
instance = memory;     //3：instance指向刚分配的内存地址，此时对象还未初始化
ctorInstance(memory);  //2：初始化对象
```

导致程序直接使用这个未初始化的值时，便会出现错误。为了解决上述问题应该在写操作前后都会插入内存屏障，避免指令重排序, 在instance上添加volatile关键字即可。

## DCL举例

### Nacos的双重检查锁

```java
private final Map<String, ConcurrentHashSet<EventListener>> listenerMap = new ConcurrentHashMap<String, ConcurrentHashSet<EventListener>>();

private final Object lock = new Object();

public void registerListener(String groupName, String serviceName, String clusters, EventListener listener) {
    String key = ServiceInfo.getKey(NamingUtils.getGroupedName(serviceName, groupName), clusters);
    ConcurrentHashSet<EventListener> eventListeners = listenerMap.get(key);
    if (eventListeners == null) {
        synchronized (lock) {
            eventListeners = listenerMap.get(key);
            if (eventListeners == null) {
                eventListeners = new ConcurrentHashSet<EventListener>();
                listenerMap.put(key, eventListeners);
            }
        }
    }
    eventListeners.add(listener);
}
```

当然上述主要是由于"先查询后执行"这种方式导致的线程并发错误。也可以使用map.putIfAbsent()来代替双重检查锁的写法。

```java
private final Map<String, ConcurrentHashSet<EventListener>> listenerMap = new ConcurrentHashMap<String, ConcurrentHashSet<EventListener>>();

public void registerListener(String groupName, String serviceName, String clusters, EventListener listener) {
    String key = ServiceInfo.getKey(NamingUtils.getGroupedName(serviceName, groupName), clusters);
    
    ConcurrentHashSet<EventListener> eventListeners = listenerMap.get(key);
    if (eventListeners == null) {
        ConcurrentHashSet<EventListener> newEventListeners = new ConcurrentHashSet<>();
        eventListeners = listenerMap.putIfAbsent(key, newEventListeners);
        if (eventListeners == null) {
            eventListeners = newEventListeners;
        }
    }
    eventListeners.add(listener);
}
```

### 享元模式思考

参考[贯穿设计模式-享元模式思考](https://juejin.cn/post/7348363812948983847)

## 参考资料

- [静态内部类何时初始化](https://www.cnblogs.com/maohuidong/p/7843807.html)
- [双重检查锁，原来是这样演变来的，你了解吗](https://ost.51cto.com/posts/16465)
- [Java并发编程实战](https://book.douban.com/subject/10484692/)