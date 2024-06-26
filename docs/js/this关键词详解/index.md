---
theme: github
highlight: github
---
# 引言

学习JS的this关键字往往难以理解和应用，本文详细解读JS中的this关键字，并结合案例给出相应的解释。

PS: [https://github.com/WeiXiao-Hyy/blog](https://github.com/WeiXiao-Hyy/blog)整理了后端开发的知识网络，欢迎Star！

# JS中的this关键字

this提供了一种更优雅的方式来隐式“传递”一个对象的引用，因此可以将API设计得更加简洁并且易于复用。

## this的作用域

this是在运行时进行绑定的，并不是在编写时绑定，它的上下文取决于函数调用时的各种条件。this的绑定和函数声明的位置没有任何关系，只取决于函数的调用方式。

```javascript
function foo() {
  var a = 2;
  this.bar();
}

function bar() {
  console.log(this.a);
}

foo(); // ReferenceError: a is not defined
```

上述代码，看完本文之后再来思考原因。

## 绑定规则

### 默认绑定

思考下面的代码

```javascript
var a = 2;

function foo() {
  console.log(this.a);
}
```

当调用foo()时，this.a被解析成了全局变量a。但是如果使用strict mode，则不能将全局对象用于默认绑定，因此this会绑定到undefined。

### 隐式绑定

```javascript
function foo() {
  console.log(this.a);
}

var obj = {
  a: 2,
  foo: foo
};

obj.foo(); // 2 
```

当foo()被obj调用时，则上下文则绑定到了obj对象中，即this.a=2;

```javascript
function foo() {
    console.log(this.a);
}

var obj2 = {
    a: 42,
    foo: foo
};

var obj1 = {
    a: 2,
    obj2: obj2
};

obj1.obj2.foo(); // 42
```

同时注意对象属性引用链只有上一层中起作用，即this.a=42;

### 隐式丢失

```javascript
function foo() {
    console.log(this.a);
}

var obj = {
    a: 2,
    foo: foo
};

var bar = obj.foo; // 函数别名！

var a = "oops, global"; // a是全局对象的属性

bar(); // "oops, global"
```

虽然bar是obj.foo的一个引用，但是实际上，它引用的是foo函数本身，因此此时的bar()其实是一个不带任何修饰的函数调用，因此应用了默认绑定。

一种更微妙，更常见并且更出乎意料的情况发生在传入回调函数时：

```javascript
function foo() {
    console.log(this.a);
}

function doFoo(fn) {
    // fn其实引用的是foo

    fn(); // <-- 调用位置！
}

var obj = {
    a: 2,
    foo: foo
};

var a = "oops, global"; // a是全局对象的属性

doFoo(obj.foo); // "oops, global"
```

其实上述案例就可以解释setTimeout()函数中this的绑定问题:

```javascript
function setTimeout(fn, delay) {
    // 等待delay毫秒
    fn(); // <-- 调用位置！
}
```

### 显式绑定

当然可以使用函数的call和apply方法来进行显式绑定。如下代码在调用foo时强制将this绑定到obj上。

```javascript
function foo() {
    console.log(this.a);
}

var obj = {
    a:2
};

foo.call(obj); // 2
```

从this绑定的角度来说，call和apply是一样的，它们的区别体现在其它参数上。

> 硬绑定
>

硬绑定的典型应用场景就是创建一个包裹函数，负责接受参数并返回值:

```javascript
function foo() {
    console.log(this.a);
}

var obj = {
    a:2
};

var bar = function() {
    foo.call(obj);
};

bar(); // 2
setTimeout(bar, 100); // 2

// 硬绑定的bar不可能再修改它的this
bar.call(window); // 2
```

上述绑定是一种显式的强制绑定，无法改变其this指向。同时ES5提供了内置的方法Function.prototype.bind，用法如下:

```javascript
function foo(something) {
    console.log(this.a, something);
    return this.a + something;
}

var obj = {
  a:2
};

var bar = foo.bind(obj);

var b = bar(3); // 2 3
console.log(b); // 5
```

> API调用的上下文
>

在第三方库函数，以及JS许多新的内置函数中，都提供了一个可选的参数，通常被称为上下文(Context)，比如forEach()函数。

```javascript
function foo(el) {
    console.log(el, this.id);
}

var obj = {
    id: "awesome"
};

// 调用foo(..)时把this绑定到obj
[1, 2, 3].forEach(foo, obj);
// 1 awesome 2 awesome 3 awesome
```

> new绑定
>


首先需要明确的是JS的new和其他面向对象语言的new含义不太一样。JS中只是被new调用的普通函数而已。考虑以下代码:

```javascript
function foo(a) {
    this.a = a;
}

var bar = new foo(2);
console.log(bar.a); // 2
```

使用new来调用foo()时，会构造一个新对象并把它绑定到foo()调用中的this上。

## 优先级

直接说结论，其实也很显然：new>显式绑定>隐式绑定>默认绑定。

1. 函数是否在new中调用（new绑定）？如果是的话this绑定的是新创建的对象。
2. 函数是否通过call、apply（显式绑定）或者硬绑定调用？如果是的话，this绑定的是指定的对象。
3. 函数是否在某个上下文对象中调用（隐式绑定）？如果是的话，this绑定的是那个上下文对象。
4. 如果都不是的话，使用默认绑定。如果在严格模式下，就绑定到undefined，否则绑定到全局对象。

## 被忽略的this

如果你把null或者undefined作为this的绑定对象传入call、apply或者bind，这些值在调用时会被忽略，实际应用的是默认绑定规则：一种常见的做法是使用apply(..)来展开一个数组，并当作参数传入一个函数。

```javascript
function foo(a, b) {
console.log("a:" + a + ", b:" + b);
}

// 把数组“展开”成参数
foo.apply(null, [2, 3]); // a:2, b:3

// 使用bind(..)进行柯里化
var bar = foo.bind(null, 2);
bar(3); // a:2, b:3
```

然而，总是使用null来忽略this绑定可能产生一些副作用。如果某个函数确实使用了this，那么默认绑定规则会把this绑定到全局对象。

## 更安全的this

一种更加安全的做法是传入一个特殊的对象，使用`Object.create(null)`创建一个空对象。

```javascript
function foo(a, b) {
    console.log("a:" + a + ", b:" + b);
}

// 空对象
var ø = Object.create(null);

// 把数组展开成参数
foo.apply(ø, [2, 3]); // a:2, b:3

// 使用bind(..)进行柯里化
var bar = foo.bind(ø, 2);
bar(3); // a:2, b:3
```

## 箭头函数this

箭头函数不使用this的四种标准规则，而是根据外层（函数或者全局）作用域来决定this。

```javascript
function foo() {
  // 返回一个箭头函数
  return (a) => {
    //this继承自foo()
    console.log(this.a);
  };
}

var obj1 = {
  a:2
};

var obj2 = {
  a:3
};

var bar = foo.call(obj1);
bar.call(obj2); // 2, 不是3!
```

foo()内部创建的箭头函数会捕获调用时foo()的this。

# 参考资料

- [你不知道的JavaScript（上卷）](https://www.douban.com/link2/?url=https%3A%2F%2Fbook.douban.com%2Fsubject%2F26351021%2F&query=javascript&cat_id=1001&type=search&pos=3)