## 引言

学习Spring事务为后续大事务做铺垫。

## Spring事务

> Propagation.REQUIRED

默认事务级别Propagation.REQUIRED，aMethod和bMethod属于同一个事务，只要其中一个方法回滚，整个事务均回滚。

```java
static class A {
    @Transactional(propagation = Propagation.REQUIRED)
    public void aMethod() {
        B b = new B();
        b.bMethod();
    }
}

static class B {
    @Transactional(propagation = Propagation.REQUIRED)
    public void bMethod() {

    }
}
```

> REQUIRES_NEW

bMethod不会跟着回滚，因为b开启了独立的事务。

```java
static class A {
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void aMethod() {
        B b = new B();
        b.bMethod();
    }
}

static class B {
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void bMethod() {

    }
}
```

但注意父方法需要注意子方法抛出的异常，避免因子方法抛出异常，而导致父方法回滚。如下案例A顺利执行，而B抛出异常执行回滚。

```java
static class A {
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void aMethod() {
        B b = new B();

        try {
            b.bMethod();
        } catch (Exception e) {
            e.printStackTrace();
        }
    }
}

static class B {
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public void bMethod() throws RuntimeException {
        throw new RuntimeException("throw exception");
    }
}
```

> NESTED

当方法存在事务时，子方法加入在嵌套事务执行。

1. 当父事务回滚时，子事务也跟着回滚。
2. 当子事务回滚，父事务回滚取决于是否捕获了异常。如果捕获了异常，那么就不回滚，否则回滚。

如下方法，aMethod()回滚，则bMethod(), bMethod2()也会回滚。

```java
class A {
    @Transactional(propagation = Propagation.NESTED)
    public void aMethod() {
        //do something
        B b = new B();
        b.bMethod();
        b.bMethod2();
    }
}

class B {
    @Transactional(propagation = Propagation.NESTED)
    public void bMethod() {
        //do something
    }

    @Transactional(propagation = Propagation.NESTED)
    public void bMethod2() {
        //do something
    }
}
```

> 事务超时时间

事务的超时时间TransactionDefinition#TIMEOUT_DEFAULT，默认值为-1；

```java
/**
 * The timeout for this transaction (in seconds).
 * <p>Defaults to the default timeout of the underlying transaction system.
 * <p>Exclusively designed for use with {@link Propagation#REQUIRED} or
 * {@link Propagation#REQUIRES_NEW} since it only applies to newly started
 * transactions.
 * @return the timeout in seconds
 * @see org.springframework.transaction.interceptor.TransactionAttribute#getTimeout()
 */
int timeout() default TransactionDefinition.TIMEOUT_DEFAULT;
```

> 事务只读属性
>

对于只读读取数据查询的事务，可以指定事务类型为readonly，即只读事务。

MySQL默认对每一个新建立的连接都启用了autocommit模式。在该模式下，每一个发送到 MySQL
服务器的sql语句都会在一个单独的事务中进行处理，执行结束后会自动提交事务，并开启一个新的事务。

1. 如果你一次执行单条查询语句，则没有必要启用事务支持，数据库默认支持 SQL 执行期间的读一致性；
2. 如果你一次执行多条查询语句，例如统计查询，报表查询，在这种场景下，多条查询 SQL 必须保证整体的读一致性，否则，在前条 SQL
   查询之后，后条 SQL 查询之前，数据被其他用户改变，则该次整体的统计查询将会出现读数据不一致的状态，此时，应该启用事务支持

> 事务回滚规则
>

默认情况下，事务只有遇到运行异常(RuntimeException的子类)时才会回滚，Error也会导致事务回滚，但是，在遇到检查型(Checked)
异常时不会回滚。

```java
/**
 * Defines zero (0) or more exception {@link Class classes}, which must be
 * subclasses of {@link Throwable}, indicating which exception types must cause
 * a transaction rollback.
 * <p>By default, a transaction will be rolling back on {@link RuntimeException}
 * and {@link Error} but not on checked exceptions (business exceptions). See
 * {@link org.springframework.transaction.interceptor.DefaultTransactionAttribute#rollbackOn(Throwable)}
 * for a detailed explanation.
 * <p>This is the preferred way to construct a rollback rule (in contrast to
 * {@link #rollbackForClassName}), matching the exception class and its subclasses.
 * <p>Similar to {@link org.springframework.transaction.interceptor.RollbackRuleAttribute#RollbackRuleAttribute(Class clazz)}.
 * @see #rollbackForClassName
 * @see org.springframework.transaction.interceptor.DefaultTransactionAttribute#rollbackOn(Throwable)
 */
Class<? extends Throwable>[] rollbackFor() default {};
```

可以回滚定义的特定的异常类型

```java
@Transactional(rollbackFor = MyException.class)
```

### Transactional注解使用详解

> @Transactional的作用范围
>

1. **方法** ：推荐将注解使用于方法上，不过需要注意的是：**该注解只能应用到 public 方法上，否则不生效。**
2. **类** ：如果这个注解使用在类上的话，表明该注解对该类中所有的 public 方法都生效。
3. **接口** ：不推荐在接口上使用。

> @Transactional的配置参数
>

| propagation | 事务的传播行为，默认值为 REQUIRED，可选的值在上面介绍过                |
|-------------|-------------------------------------------------|
| isolation   | 事务的隔离级别，默认值采用 DEFAULT，可选的值在上面介绍过                |
| timeout     | 事务的超时时间，默认值为-1（不会超时）。如果超过该时间限制但事务还没有完成，则自动回滚事务。 |
| readOnly    | 指定事务是否为只读事务，默认值为 false。                         |
| rollbackFor | 用于指定能够触发事务回滚的异常类型，并且可以指定多个异常类型。                 |

### Spring AOP自调用问题

@Transactional注解的方法在类以外被调用的时候，Spring事务管理才生效,如下调用事务会失效。

```java

@Service
public class MyService {

    private void method1() {
        method2();
        //......
    }

    @Transactional
    public void method2() {
        //......
    }
}
```

## 参考资料

- [https://juejin.cn/post/6844903608224333838](https://juejin.cn/post/6844903608224333838)
- [https://www.cnblogs.com/chanshuyi/p/head-first-of-spring-transaction.html](https://www.cnblogs.com/chanshuyi/p/head-first-of-spring-transaction.html)
