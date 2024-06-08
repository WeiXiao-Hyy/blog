## 引言

偶然间看到一个Github仓库叫做fucking-java-concurrency感觉很意思。里面主要介绍了java开发可能会遇到的并发问题。本文就给出的案例代码给出自己的理解。为后续深入学习java并发打下基础。

仓库链接：[https://github.com/oldratlee/fucking-java-concurrency/tree/master](https://github.com/oldratlee/fucking-java-concurrency/tree/master)


## Infinite loop of HashMap

HashMap的老面试问题了，Java8之前由于头插入方式多线程扩容会导致环形链表，从而导致CPU飙升的问题；Java8之后换成尾插法和红黑树还是会有树节点成环的问题; 建议在并发场景下还是使用并发安全的ConcurrentHashMap吧。

原因和解释可以参考以下文章: [https://coolshell.cn/articles/9606.html](https://coolshell.cn/articles/9606.html)


## Update without synchronization cannot be read in another thread

一个线程在主存中修改了一个变量的值，而另外一个线程还继续使用它在寄存器中的变量值的拷贝，造成了数据的不一致, 可参考Java内存模型查看原因，代码如下:

```java
public class NoPublishDemo {
    boolean stop = false;

    public static void main(String[] args) throws Exception {
        // LoadMaker.makeLoad();

        NoPublishDemo demo = new NoPublishDemo();

        Thread thread = new Thread(demo.getConcurrencyCheckTask());
        thread.start();

        Thread.sleep(1000);
        System.out.println("Set stop to true in main!");
        demo.stop = true;
        System.out.println("Exit main.");
    }

    ConcurrencyCheckTask getConcurrencyCheckTask() {
        return new ConcurrencyCheckTask();
    }

    private class ConcurrencyCheckTask implements Runnable {
        @Override
        @SuppressWarnings({"WhileLoopSpinsOnField", "StatementWithEmptyBody"})
        public void run() {
            System.out.println("ConcurrencyCheckTask started!");
            // If the value of stop is visible in the main thread, the loop will exit.
            // On my dev machine, the loop almost never exits!
            // Simple and safe solution:
            //   add volatile to the `stop` field.
            while (!stop) {
            }
            System.out.println("ConcurrencyCheckTask stopped!");
        }
    }
}
```

> 解决方案

上述程序会陷入死循环，最简单的方法是将stop变量设置为volatile。

## Long variable read invalid value

Java内存模型要求，变量的读取和写入都必须是原子操作，但是对于非volatile类型的double和long变量，JVM将允许64位的读写操作分解为两个32位的读写操作。当读取一个非volatile类型的long变量的时候，如果对该变量的读写在不同的线程中，那么很有可能读取到某个值的高32位和另一个值的低32位。

```java
public class InvalidLongDemo {
    long count = 0;

    @SuppressWarnings("InfiniteLoopStatement")
    public static void main(String[] args) {
        // LoadMaker.makeLoad();

        InvalidLongDemo demo = new InvalidLongDemo();

        Thread thread = new Thread(demo.getConcurrencyCheckTask());
        thread.start();

        for (int i = 0; ; i++) {
            @SuppressWarnings("UnnecessaryLocalVariable")
            final long l = i;
            demo.count = l << 32 | l;
        }
    }

    ConcurrencyCheckTask getConcurrencyCheckTask() {
        return new ConcurrencyCheckTask();
    }

    private class ConcurrencyCheckTask implements Runnable {
        @Override
        @SuppressWarnings("InfiniteLoopStatement")
        public void run() {
            int c = 0;
            for (int i = 0; ; i++) {
                long l = count;
                long high = l >>> 32;
                long low = l & 0xFFFFFFFFL;
                if (high != low) {
                    c++;
                    System.err.printf("Fuck! Got invalid long!! check time=%s, happen time=%s(%s%%), count value=%s|%s%n",
                            i + 1, c, (float) c / (i + 1) * 100, high, low);
                } else {
                    // If remove this output, invalid long is not observed on my dev machine
                    System.out.printf("Emm... %s|%s%n", high, low);
                }
            }
        }
    }
}

```

> 解决方案

将long变量添加volatile修饰即可解决上述问题。

## Synchronization on mutable fields

当变量设置为volatile之后，在对其进行读写是不是就可以了呢？下述代码listeners设置为volatile，使用CopyOnWriteArrayList线程安全的集合并且在更新集合时使用了synchronized加锁，但问题没有得到解决。

```java
public class SynchronizationOnMutableFieldDemo {
    static final int ADD_COUNT = 10000;

    static class Listener {
        // stub class
    }

    private volatile List<Listener> listeners = new CopyOnWriteArrayList<>();

    public static void main(String[] args) throws Exception {
        SynchronizationOnMutableFieldDemo demo = new SynchronizationOnMutableFieldDemo();

        Thread thread1 = new Thread(demo.getConcurrencyCheckTask());
        thread1.start();
        Thread thread2 = new Thread(demo.getConcurrencyCheckTask());
        thread2.start();

        thread1.join();
        thread2.join();

        int actualSize = demo.listeners.size();
        int expectedSize = ADD_COUNT * 2;
        if (actualSize != expectedSize) {
            // On my development machine, it's almost must occur!
            // Simple and safe solution:
            //   final List field and use concurrency-safe List, such as CopyOnWriteArrayList
            System.err.printf("Fuck! Lost update on mutable field! actual %s expected %s.%n", actualSize, expectedSize);
        } else {
            System.out.println("Emm... Got right answer!!");
        }
    }

    @SuppressWarnings("SynchronizeOnNonFinalField")
    public void addListener(Listener listener) {
        synchronized (listeners) {
            List<Listener> results = new ArrayList<>(listeners);
            results.add(listener);
            listeners = results;
        }
    }

    ConcurrencyCheckTask getConcurrencyCheckTask() {
        return new ConcurrencyCheckTask();
    }

    private class ConcurrencyCheckTask implements Runnable {
        @Override
        public void run() {
            System.out.println("ConcurrencyCheckTask started!");
            for (int i = 0; i < ADD_COUNT; ++i) {
                addListener(new Listener());
            }
            System.out.println("ConcurrencyCheckTask stopped!");
        }
    }
}
```

> 解决方案

上述代码问题在于synchronized加锁的对象listeners是一个可变量，每一个线程拥有的锁都不一样导致出现问题。给出以下解决方案:

- CopyOnWriterArrayList本身就是线程安全的集合，无须使用synchronized同步。
```java
public void addListener(Listener listener) {
    listeners.add(listener);
}
```

- 使用同一个锁实例
```java
private static final Object lock = new Object();

public void addListener(Listener listener) {
    synchronized (lock) {
        List<Listener> results = new ArrayList<>(listeners);
        results.add(listener);
        listeners = results;
    }
}
```

## The result of concurrency count without synchronization is wrong

老生常谈的问题，count++不是原子操作，对于共享变量操作需要同步操作。同时也警惕volatile只能保证变量的可见性，操作是非原子性的还是会存在并发安全问题。

```java
public class WrongCounterDemo {
    private static final int INC_COUNT = 100000000;

    private volatile int counter = 0;

    public static void main(String[] args) throws Exception {
        WrongCounterDemo demo = new WrongCounterDemo();

        System.out.println("Start task thread!");
        Thread thread1 = new Thread(demo.getConcurrencyCheckTask());
        thread1.start();
        Thread thread2 = new Thread(demo.getConcurrencyCheckTask());
        thread2.start();

        thread1.join();
        thread2.join();

        int actualCounter = demo.counter;
        int expectedCount = INC_COUNT * 2;
        if (actualCounter != expectedCount) {
            // Even if volatile is added to the counter field,
            // On my dev machine, it's almost must occur!
            // Simple and safe solution:
            //   use AtomicInteger
            System.err.printf("Fuck! Got wrong count!! actual %s, expected: %s.%n", actualCounter, expectedCount);
        } else {
            System.out.println("Wow... Got right count!");
        }
    }

    ConcurrencyCheckTask getConcurrencyCheckTask() {
        return new ConcurrencyCheckTask();
    }

    private class ConcurrencyCheckTask implements Runnable {
        @Override
        @SuppressWarnings("NonAtomicOperationOnVolatileField")
        public void run() {
            for (int i = 0; i < INC_COUNT; ++i) {
                ++counter;
            }
        }
    }
}
```

> 解决方案

- 使用AtomicInteger类

```java
private final AtomicInteger counter = new AtomicInteger(0);
```

- 同步counter增加操作

```java
private static final Object lock = new Object();

public void run() {
    for (int i = 0; i < INC_COUNT; ++i) {
        synchronized (lock) {
            counter++;
        }
    }
}
```

## Combined state read invalid combination (Inconsistent read)

当线程写入变量之后,另一个线程存在多个读操作时,如果此时没有做好同步操作,会导致读操作存在不一致的问题。

如下代码，主线程改变task的state1和state2的值,并保持两倍关系,子线程读取state1和state2的值,会发现和主线程写入值关系不相同。

主要问题在于读操作分成了两步，第一次读取完state1变量后，主线程可能已经把state2变量改变了，所以导致错误。

```java
public class InvalidCombinationStateDemo {
    public static void main(String[] args) {
        CombinationStatTask task = new CombinationStatTask();
        Thread thread = new Thread(task);
        thread.start();

        Random random = new Random();
        while (true) {
            int rand = random.nextInt(1000);
            task.state1 = rand;
            task.state2 = rand * 2;
        }
    }

    private static class CombinationStatTask implements Runnable {
        // For combined state, adding volatile does not solve the problem
        volatile int state1;
        volatile int state2;

        @Override
        public void run() {
            int c = 0;
            for (long i = 0; ; i++) {
                int i1 = state1;
                int i2 = state2;
                if (i1 * 2 != i2) {
                    c++;
                    System.err.printf("Fuck! Got invalid CombinationStat!! check time=%s, happen time=%s(%s%%), count value=%s|%s%n",
                            i + 1, c, (float) c / (i + 1) * 100, i1, i2);
                } else {
                    // if remove blew output,
                    // the probability of invalid combination on my dev machine goes from ~5% to ~0.1%
                    System.out.printf("Emm... %s|%s%n", i1, i2);
                }
            }
        }
    }
}

```

> 错误案例

```java
public void run() {
    int c = 0;
    for (long i = 0; ; i++) {

        int i1, i2;
        synchronized (lock) {
            i1 = state1;
            i2 = state2;
        }

        if (i1 * 2 != i2) {
            c++;
            System.err.printf("Fuck! Got invalid CombinationStat!! check time=%s, happen time=%s(%s%%), count value=%s|%s%n",
                    i + 1, c, (float) c / (i + 1) * 100, i1, i2);
        } else {
            // if remove blew output,
            // the probability of invalid combination on my dev machine goes from ~5% to ~0.1%
            System.out.printf("Emm... %s|%s%n", i1, i2);
        }
    }
}
```

以上给赋值操作加上synchronized同步块却不能解决问题,理由: 赋值操作本来就是在一个线程，加同步块不能解决问题。

> 解决方案

读写分别加锁即可,参考代码如下:

```java
public class InvalidCombinationStateDemo {
    private static final Object lock = new Object();

    public static void main(String[] args) {
        CombinationStatTask task = new CombinationStatTask();
        Thread thread = new Thread(task);
        thread.start();

        Random random = new Random();
        while (true) {
            synchronized (lock) {
                int rand = random.nextInt(1000);
                task.state1 = rand;
                task.state2 = rand * 2;
            }
        }
    }

    private static class CombinationStatTask implements Runnable {
        // For combined state, adding volatile does not solve the problem
        volatile int state1;
        volatile int state2;

        @Override
        public void run() {
            int c = 0;
            for (long i = 0; ; i++) {
                int i1, i2;

                synchronized (lock) {
                    i1 = state1;
                    i2 = state2;
                }

                if (i1 * 2 != i2) {
                    c++;
                    System.err.printf("Fuck! Got invalid CombinationStat!! check time=%s, happen time=%s(%s%%), count value=%s|%s%n",
                            i + 1, c, (float) c / (i + 1) * 100, i1, i2);
                } else {
                    // if remove blew output,
                    // the probability of invalid combination on my dev machine goes from ~5% to ~0.1%
                    System.out.printf("Emm... %s|%s%n", i1, i2);
                }
            }
        }
    }
}
```

## Deadlock, livelock, and starvation

> 死锁

死锁很好理解,由于资源获取，进程相互阻塞，在等待另一个进程持有的资源，没有一个进程取得任何的进展。代码如下:

```java
public class SymmetricLockDeadlockDemo {
    static final Object lock1 = new Object();
    static final Object lock2 = new Object();

    public static void main(String[] args) throws Exception {
        Thread thread1 = new Thread(new ConcurrencyCheckTask1());
        thread1.start();
        Thread thread2 = new Thread(new ConcurrencyCheckTask2());
        thread2.start();
    }

    private static class ConcurrencyCheckTask1 implements Runnable {
        @Override
        @SuppressWarnings("InfiniteLoopStatement")
        public void run() {
            System.out.println("ConcurrencyCheckTask1 started!");
            while (true) {
                synchronized (lock1) {
                    synchronized (lock2) {
                        System.out.println("Hello1");
                    }
                }
            }
        }
    }

    private static class ConcurrencyCheckTask2 implements Runnable {
        @Override
        @SuppressWarnings("InfiniteLoopStatement")
        public void run() {
            System.out.println("ConcurrencyCheckTask2 started!");
            while (true) {
                synchronized (lock2) {
                    synchronized (lock1) {
                        System.out.println("Hello2");
                    }
                }
            }
        }
    }
}
```

task1持有lock1等待task2释放lock2,task2持有lock2等待task1释放lock1。

> 活锁

在活锁的情况下，活锁场景中涉及的进程的状态不断变化。另一方面，流程仍然相互依赖，永远无法完成其任务。

参考[https://www.baeldung.com/cs/deadlock-livelock-starvation#livelock](https://www.baeldung.com/cs/deadlock-livelock-starvation#livelock)的举例：活锁就像两个人同时给对方打电话，但同时占线，双方又在相同的间隔后再次拨号。注意和死锁的区别死锁是两个进程没有任何进展，而活锁进程仍然在执行。代码如下:

```java
public class ReentrantLockLivelockDemo {
    private static final Lock lock1 = new ReentrantLock();
    private static final Lock lock2 = new ReentrantLock();

    public static void main(String[] args) throws Exception {
        Thread thread1 = new Thread(ReentrantLockLivelockDemo::concurrencyCheckTask1);
        thread1.start();
        Thread thread2 = new Thread(ReentrantLockLivelockDemo::concurrencyCheckTask2);
        thread2.start();
    }

    private static void concurrencyCheckTask1() {
        System.out.println("Started concurrency check task 1");
        int counter = 0;

        while (counter++ < 10_000) {
            try {
                if (lock1.tryLock(50, TimeUnit.MILLISECONDS)) {
                    System.out.println("Task 1 acquired lock 1");
                    Thread.sleep(50);
                    if (lock2.tryLock()) {
                        System.out.println("Task 1 acquired lock 2");
                    } else {
                        System.out.println("Task 1 failed to acquire lock 2, releasing lock 1");
                        lock1.unlock();
                        continue;
                    }
                }
            } catch (InterruptedException e) {
                e.printStackTrace();
                break;
            }

            break;
        }

        System.err.printf("Fuck! No meaningful work done in %s iterations of task 1.%n", counter);
        lock2.unlock();
        lock1.unlock();
    }

    private static void concurrencyCheckTask2() {
        System.out.println("Started concurrency check task 2");

        int counter = 0;
        while (counter++ < 10_000) {
            try {
                if (lock2.tryLock(50, TimeUnit.MILLISECONDS)) {
                    System.out.println("Task 2 acquired lock 2");
                    Thread.sleep(50);
                    if (lock1.tryLock()) {
                        System.out.println("Task 2 acquired lock 1");
                    } else {
                        System.out.println("Task 2 failed to acquire lock 1, releasing lock 2");
                        lock2.unlock();
                        continue;
                    }
                }
            } catch (InterruptedException e) {
                e.printStackTrace();
                break;
            }

            break;
        }

        System.err.printf("Fuck! No meaningful work done in %s iterations of task 2.%n", counter);
        lock2.unlock();
        lock1.unlock();
    }
}
```

结果就是两个线程都不能第一时间同时获得lock1和lock2。

> 饥饿

饥饿是一个过程的结果，这个过程无法定期获得完成任务所需的共享资源，因此无法取得任何进展。饥饿可能由死锁、活锁或其他进程引起。

## 结果语

上述并发问题的解决方案会有更加优雅的方式，笔者只是给出通用的解法，有更好的解法可以在评论区讨论～

## 参考资料

- [https://github.com/oldratlee/fucking-java-concurrency/tree/master](https://github.com/oldratlee/fucking-java-concurrency/tree/master)
- [https://coolshell.cn/articles/9606.html](https://coolshell.cn/articles/9606.html)
- [https://www.baeldung.com/cs/deadlock-livelock-starvation#livelock](https://www.baeldung.com/cs/deadlock-livelock-starvation#livelock)