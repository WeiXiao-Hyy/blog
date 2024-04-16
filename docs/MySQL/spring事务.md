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

bMethod不会跟着回滚，因为b开启了独立的事务

```java
static class A {
    @Transactional(propagation = Propagation.REQUIRES_NEW)
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

aMethod()回滚，bMethod()和bMethod2()都要回滚，而bMethod()回滚的话，并不会造成aMethod()和bMethod()回滚。

```java
class A {
	@Transactional(propagation=propagation.PROPAGATION_REQUIRED)
	public void aMethod() {
	    //do something
	    B b = new B();
	    b.bMethod();
	    b.bMethod2();
	}
}

class B {
	@Transactional(propagation=propagation.PROPAGATION_NESTED)
	public void bMethod() {
	   //do something
	}
	@Transactional(propagation=propagation.PROPAGATION_NESTED)
	public void bMethod2() {
	   //do something
	}
}
```

InnoDB存储引擎在REPEATABLE-READ，事务隔离级别下使用的Next-Key Lock锁算法，因此可以避免幻读的产生。

事务的超时时间TransactionDefinition#TIMEOUT_DEFAULT，默认值为-1；

```java
/**
 * Use the default isolation level of the underlying datastore.
 * <p>All other levels correspond to the JDBC isolation levels.
 * @see java.sql.Connection
 */
int ISOLATION_DEFAULT = -1;
```

> 事务只读属性
>

对于只读读取数据查询的事务，可以指定事务类型为readonly，即只读事务。

MySQL默认对每一个新建立的连接都启用了autocommit模式。在该模式下，每一个发送到 MySQL 服务器的sql语句都会在一个单独的事务中进行处理，执行结束后会自动提交事务，并开启一个新的事务。
1. 如果你一次执行单条查询语句，则没有必要启用事务支持，数据库默认支持 SQL 执行期间的读一致性；
2. 如果你一次执行多条查询语句，例如统计查询，报表查询，在这种场景下，多条查询 SQL 必须保证整体的读一致性，否则，在前条 SQL 查询之后，后条 SQL 查询之前，数据被其他用户改变，则该次整体的统计查询将会出现读数据不一致的状态，此时，应该启用事务支持

> 事务回滚规则
>

默认情况下，事务只有遇到运行异常(RuntimeException的子类)时才会回滚，Error也会导致事务回滚，但是，在遇到检查型(Checked)异常时不会回滚。

```java
/**
 * Defines zero (0) or more exception {@linkplain Class types}, which must be
 * subclasses of {@link Throwable}, indicating which exception types must cause
 * a transaction rollback.
 * <p>By default, a transaction will be rolled back on {@link RuntimeException}
 * and {@link Error} but not on checked exceptions (business exceptions). See
 * {@link org.springframework.transaction.interceptor.DefaultTransactionAttribute#rollbackOn(Throwable)}
 * for a detailed explanation.
 * <p>This is the preferred way to construct a rollback rule (in contrast to
 * {@link #rollbackForClassName}), matching the exception type and its subclasses
 * in a type-safe manner. See the {@linkplain Transactional class-level javadocs}
 * for further details on rollback rule semantics.
 * @see #rollbackForClassName
 * @see org.springframework.transaction.interceptor.RollbackRuleAttribute#RollbackRuleAttribute(Class)
 * @see org.springframework.transaction.interceptor.DefaultTransactionAttribute#rollbackOn(Throwable)
 */
Class<? extends Throwable>[] rollbackFor() default {};
```

可以回滚定义的特定的异常类型

```java
@Transactional(rollbackFor= MyException.class)
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

@Transactional注解的方法在类以外被调用的时候，Spring事务管理才生效

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