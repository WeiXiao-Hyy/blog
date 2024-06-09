## 引言

[fucking-java-concurrency](https://juejin.cn/post/7371671537509187596)主要解读了在开发过程中尝尝会遇到的Java并发问题，本文主要总结Java的中断原理和应用。

PS: [https://github.com/WeiXiao-Hyy/blog](https://github.com/WeiXiao-Hyy/blog)整理了后端开发的知识网络，欢迎Star！

## 操作系统的中断

> 什么是中断？

中断可以归结为一种事件处理机制，通过中断发出一个信号, 用来响应硬件设备请求的一种机制。操作系统收到硬件的中断请求，会打断正在执行的进程，然后调用内核中的中断处理程序来响应请求。

> 中断解决了什么样问题？
>

当CPU需要访问外部设备时，必须不断地进行轮询和等待外部设备的状态, 这种轮询过程极大地浪费资源。中断机制有效地解决了CPU轮询和忙等待以检查外部设备状态所带来的性能损耗问题。

**注意**：操作系统收到中断请求，会打断其他进程的运行，所以中断请求的响应程序要尽可能快的执行完，这样可以减少对正常进程运行调度地影响。

> 中断过程
>

为了解决中断处理程序执行过长和中断丢失的问题，将中断过程分成了两个阶段，分别为上半部和下半部。

- 上半部用来快速处理中断：一般会暂时关闭中断请求，主要负责处理跟硬件紧密相关或者时间敏感的事情。
- 下半部用来**延迟处理**上半部未完成的工作：一般以内核线程的方式运行。

> 网卡例子
>

网卡收到网络包后，通过DMA方式将接收的数据写入内存，接着会通过硬件中断通知内核有新的数据到了。上半部会先禁止网卡中断，避免频繁硬中断。内核会触发一个软中断，把一些处理比较耗时且复杂的事情，交给软中断处理程序去做，也就是中断的下半部。

- 上半部直接处理硬件请求，也就是硬中断，主要负责耗时短的工作，特点是快速执行。
- 下半部分是由内核触发，也就是软中断，主要负责上半部未完成的工作。

## Java的中断

Java中没有办法立即停止一个线程，Java提供了一种用于停止线程的协商机制：**中断**。

Java的中断只是一种协商机制, 通过中断并不能直接中断另外一个线程，而需要被中断的线程自己处理中断, **通常，中断是实现取消的最合理方式**。

> 中断原理

每一个线程都有boolean标识，代表着是否有中断请求。线程可以选择在合适的时候处理该中断请求，甚至可以完全不理会该请求，就像这个线程没有被中断一样。

> API
>

|            Method            |           Description            |                                           
|:----------------------------|:--------------------------------|
|       void interrupt()       |        中断线程，设置线程的中断位为true        |
|   boolean isInterrupted()    | 检查线程的中断标记位，true-中断状态，false-非中断状态 |
| static boolean interrupted() |  返回当前线程的中断标记位，同时清楚中断标记，改为false   |

注意：使用静态`interrupted`方法应该小心，因为它会清楚当前线程的中断状态，如果在调用interrupted时返回了true，那么除非你想屏蔽这个中断，否则必须对它进行处理——可以抛出`InterruptedException`，或者通过再次调用`interrupt`来恢复中断状态；

```java
public class InterruptExample implements Runnable {

    BlockingQueue<Task> queue;

    @Override
    public void run() {
        try {
            processTask(queue.take());
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt(); // 恢复被中断的状态
        }
    }
}
```

## 案例讲解

### 可中断的阻塞

针对线程处于由`sleep`, `wait`, `join`, `LinkedBlockingQueue#take`等方法调用产生的阻塞状态时，调用`interrupt`方法，会抛出异常`InterruptedException`，同时会清除中断标记位，自动改成false;

> LinkedBlockQueue#take()
>
```java
public E take() throws InterruptedException {
    final E x;
    final int c;
    final AtomicInteger count = this.count;
    final ReentrantLock takeLock = this.takeLock;
    takeLock.lockInterruptibly(); // important
    try {
        while (count.get() == 0) {
            notEmpty.await();
        }
        x = dequeue();
        c = count.getAndDecrement();
        if (c > 1)
            notEmpty.signal();
    } finally {
        takeLock.unlock();
    }
    if (c == capacity)
        signalNotFull();
    return x;
}

@ReservedStackAccess
final void lockInterruptibly() throws InterruptedException {
    if (Thread.interrupted())
        throw new InterruptedException();
    if (!initialTryLock())
        acquireInterruptibly(1);
}
```

### 通过中断来取消

根据上述可中断的阻塞操作，可以通过中断来取消任务。

```java
import java.math.BigInteger;
import java.util.concurrent.BlockingQueue;

class PrimeProducer extends Thread {
    private final BlockingQueue<BigInteger> queue;

    PrimeProducer(BlockingQueue<BigInteger> queue) {
        this.queue = queue;
    }

    public void run() {
        try {
            BigInteger p = BigInteger.ONE;
            while (!Thread.currentThread().isInterrupted()) {
                queue.put(p = p.nextProbablePrime());
            }
        } catch (InterruptedException consumed) {
            // 允许线程退出
        }
    }

    public void cancel() {
        interrupt();
    }
}
```

### 综上

当调用可中断的阻塞函数时，有两种实用策略可用于处理`InterruptedException`。

- 传递异常，使你的方法也成为可中断的阻塞方法。
- 恢复中断状态，从而使得调用栈中的上层代码能够对其进行处理。

## 参考资料

- [https://www.xiaolincoding.com/os/1_hardware/soft_interrupt.html](https://www.xiaolincoding.com/os/1_hardware/soft_interrupt.html#%E5%A6%82%E4%BD%95%E5%AE%9A%E4%BD%8D%E8%BD%AF%E4%B8%AD%E6%96%AD-cpu-%E4%BD%BF%E7%94%A8%E7%8E%87%E8%BF%87%E9%AB%98%E7%9A%84%E9%97%AE%E9%A2%98)
- [https://anyview.fun/2022/11/28](https://anyview.fun/2022/11/28/%E4%B8%80%E6%96%87%E4%BA%86%E8%A7%A3os-%E4%B8%AD%E6%96%AD/)
- [https://juejin.cn/post/7296751837340614671#2_6](https://juejin.cn/post/7296751837340614671#2_6)