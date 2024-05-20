## 引言

学习数据库设计范式以及设计数据表的经验总结

## 六大范式

关系数据库有六种，一二三四五和BCNF。一般数据库只需要满足第三范式即可;

### 第一范式

为了确保原子性，存储的数据列具备不可再分性。

> 如果不遵守第一范式会有什么问题

1. 客户端语言和表无法很好的生成映射关系
2. 查询到数据后，还需要对字段进行额外拆分
3. 插入数据时，对于字段需要先拼装才能进行写入

### 第二范式

表中的所有列，其数据都必须依赖于主键，也就是一张表只存储同一类型的数据，不能有任何一列数据与主键没有关系。

```sql
student: id, name, sex, height, course, score
```

很明显course,score与主键没有关键, 并且会导致前面几列数据的冗余。

```sql
student: id, name, sex, height

course: id, name

score: id,student_id,course_id,score
```

这样拆分之后每张表中的id字段作为主键，其他字段都依赖这个主键。


### 第三范式

表中每一列数据都不能与主键之外的字段有直接关系。

```sql
student: id, name, sex, height, department, boss
```

boss代表了department的院长是谁，department和boss存在着依赖关系，因此需要进一步调整表结构关系。

```sql
department: id, name, boss

student: id, name, sex, height, department_id
```

### 巴斯-科德范式(BCNF)

第三范式：任何非主键字段不能与其他非主键字段间存在依赖关系。

巴斯-科德范式(3.5范式): 任何主属性(联合主键)不能对其他主键子集存在依赖。

> 如何选择联合主键

1. 因为主键一般都是用于区分不同行数据的，必须要确保唯一性。
2. 满足巴斯-科德范式

```sql
student: classes, class_adviser, name, sex, height
```

如果选用(classes, class_advisor, name)作为联合主键

1. 满足唯一性，
2. 不满足巴斯-科德范式(班主任名称其实也依赖于班级字段)

> 有什么问题

1. 班主任换人，需要同时修改学生表中的多条数据;
2. 班主任离职后，需要删除该老师的记录，会同时删除多条学生信息;
3. 想要增加班级时，同时必须添加学生姓名数据，因为主键不能为空;

联合主键不常用。

```sql
adviser: id, name

classes: id, adviser_id, name

student: class_id, name, sex, height
```

使用class_id和name作为联合主键(其实一般student表会有id作为主键，因为一个班级也有同名的学生)

### 第四范式

第四范式是基于BC范式之上的

> 多值依赖

一个表至少需要三个独立的字段才会出现多值依赖问题，指表中的字段之间存在多个一对多的关系，也就是一个字段的具体值会由多个字段来决定。

```sql
user_role_permission: name, sex, role, permission
```

一个用户可以拥有多个角色，同时一个角色可以拥有多个权限，所以无法单独根据用户名去确定权限值。这种字段的值取决于多个字段才能确定的情况，就称为多值依赖。

看下Shiro框架如何管理用户角色权限表

```sql
user: id, name, sex, password, register_time;

roles: id, name, created_time;

permissions: id, name, created_time;

user_roles: id, user_id, role_id;

roles_permissions: id, role_id, permission_id;
```

### 第五范式(完美范式)

在第四范式的基础上，进一步消除表中的连接依赖，直到表中的连接依赖都是主键所蕴含的。

```sql
emp: empname(名称), empskill(技能), empjob(工作)
```

上表可以拆分为以下三个表，因此不符合第五范式

```sql
emp_skill: name, skill

emp_job: name, job

job_skill: skill, job
```

简单理解为A-B-C可以拆分为A-B,A-C,B-C三个关系时，则不符合第五范式。

## 参考资料

- [https://juejin.cn/post/7146474739018498062](https://juejin.cn/post/7146474739018498062)
- [https://www.liaoxuefeng.com/wiki/1177760294764384/1218728391867808](https://www.liaoxuefeng.com/wiki/1177760294764384/1218728391867808)
- [https://www.nhooo.com/note/qa0mvl.html](https://www.nhooo.com/note/qa0mvl.html)