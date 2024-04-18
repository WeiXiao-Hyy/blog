## 引言

## MySQL表级锁

MySQL中表级锁主要有表锁（注意区分表级锁）、意向锁、自增锁、元数据锁。

## 语法

```sql
lock
tables test.t1 read, test.t2 write;

unlock
tables
```

可以对同一个表同时加读锁，但是不能同时加写锁，或者混合读写锁。

## DML,DDL以及DCL是什么?

- DML（data manipulation language）是数据操纵语言：它们是UPDATE、INSERT、DELETE，就象它的名字一样，这4条命令是用来对数据库里的数据进行操作的语言。
- DQL（data query language） 数据查询语言DQL基本结构是由SELECT子句，FROM子句，WHERE子句组成的查询块。
- DDL（data definition
  language）是数据定义语言：DDL比DML要多，主要的命令有CREATE、ALTER、DROP等，DDL主要是用在定义或改变表（TABLE）的结构，数据类型，表之间的链接和约束等初始化工作上，他们大多在建立表时使用。
- DCL（data control language）是数据库控制语言：是用来设置或更改数据库用户或角色权限的语句，包括（grant,deny,revoke等）语句。

## 元数据(MDL)锁

元数据锁（Metadata
Lock，简称MDL）是表级锁中的一种，MDL锁主要作用是维护表元数据的数据一致性，为了避免DML与DDL冲突，保证读写的正确性。元数据锁不仅仅可以应用到表上，也可以应用到schemas、存储过程、函数、触发器、计划事件、表空间上。

DDL，DML，DQL, 表级锁都会加元数据锁。隐式加解锁，无需用户控制，系统自动完成。

### 查看元数据锁

```sql
select *
from performance_schema.metadata_locks;
```

![](./imgs/MDL-查询元数据锁.png)

因为查询了metadata_locks，所以系统自动加了元数据锁。

### MDL类型

> 类型
>

- 共享只读`SHARED_READ_ONLY`
- 共享写锁`SHARED_NO_READ_WRITE`
- 共享读锁`SHARED_READ`
- 共享写锁`SHARED_WRITE`
- 排他锁`EXCLUSIVE`

共享读锁`SHARED_READ`和共享写锁`SHARE_WRITE`是兼容的，跟排他锁`EXCLUSIVE`是互斥的。

> SHARED_NO_READ_WRITE，SHARED_WRITE 有什么区别
>

- `SHARED_NO_READ_WRITE`: 表示共享资源不可读写，即多个进程可以共享资源，但不能对其进行读写操作。
- `SHARED_WRITE`: 表示共享资源可写，即多个进程可以共享资源，并且可以对其进行写操作。

### 不同的DQL加元数据锁的类型

- `SELECT..., SELECT FOR SHARE -> SHARED_READ`;
- `SELECT... FOR UPDATE -> SHARED_WRITE`;

### 表锁加元数据锁的类型

加表级读锁的时候，系统会自动创建一个共享MDL读锁

![](./imgs/lock-read-MDL.png)

加表级写锁的时候，系统会自动创建一个MDL写锁(SHARED_NO_READ_WRITE)。

![](./imgs/lock-write-MDL.png)

### DML加元数据锁的类型

INSERT,UPDATE,DELETE的时候，系统会自动创建一个MDL写锁(SHARED_WRITE)。

### DDL加元数据锁的类型

对于DDL语句，系统会自动加上MDL排他锁（EXCLUSIVE），此排他锁会阻塞所有的DQL、DML以及其他的DML。

### 总结

|                    SQL                    |                 Type                  |                                                  兼容性                                                   |                                                  
|:-----------------------------------------:|:-------------------------------------:|:------------------------------------------------------------------------------------------------------:|
|        SELECT, SELECT...FOR SHARE         |              SHARED_READ              |                                与SHARED_READ和SHARED_WRITE兼容，与EXCLUSIVE互斥                                |
| INSERT, UPDATE, DELETE, SELECT FOR UPDATE |             SHARED_WRITE              |                                与SHARED_READ和SHARED_WRITE兼容，与EXCLUSIVE互斥                                |
|                    DDL                    |               EXCLUSIVE               | SHARED_READ_ONLY与SHARED_READ兼容，与SHARED_WRITE互斥； SHARED_NO_READ_WRITE与SHARED_READ_ONLY 和SHARED_WRITE都互斥 |
|          LOCK TABLES READ/WRITE           | SHARED_READ_ONLY/SHARED_NO_READ_WRITE |                                               与所有MDL锁互斥。                                               |

### 意向锁

意向锁是另外一种表级锁，为了避免DML语句在执行的时候行锁与表锁冲突而设计的意向锁，通过意向锁使得在加表锁的时候无需检查每行数据是否加锁。

## 补充

> 查看MySQL表锁

```sql
SHOW
OPEN TABLES WHERE In_use > 0;
```