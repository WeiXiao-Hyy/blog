## 引言

## Tomcat相关接口和方法

### Pipeline

servlet容器调用invoke方法来开始调用管道中的阀和基础阀

```java

// Pipeline 
public void invoke(Request request, Response response)
        throws IOException, ServletException;


// StandardPipeline 
public void invoke(Request request, Response response)
        throws IOException, ServletException {
    // Invoke the first Valve in this pipeline for this request
    (new StandardPipelineValveContext()).invokeNext(request, response);
}
```

### Valve

阀是Valve接口的实例

```java
public void invoke(Request request, Response response,
                       ValveContext context)
        throws IOException, ServletException;
```

### ValveContext

// TODO: 搞清楚这样设计的好处
tomcat4使用StandardPipelineValveContext内部类,valve和basic均为Pipeline的成员变量。
tomcat5移除了内部类，使用单独的StandValveContext来调用阀。

```java

// ValveContext interface
public void invokeNext(Request request, Response response)
        throws IOException, ServletException;


// StandardPipelineValveContext
public void invokeNext(Request request, Response response)
        throws IOException, ServletException {

    int subscript = stage;
    stage = stage + 1;

    // Invoke the requested Valve for the current request thread
    if (subscript < valves.length) {
        valves[subscript].invoke(request, response, this);
    } else if ((subscript == valves.length) && (basic != null)) {
        basic.invoke(request, response, this);
    } else {
        throw new ServletException
                (sm.getString("standardPipeline.noValve"));
    }

}
```

### Contained

阀可以选择是否实现Contained接口，该接口的实现类可以通过接口方法至多与一个servlet容器相关联。

```java
public Container getContainer();
public void setContainer(Container container);
```

### Wrapper

Wrapper接口继承了Container，Wrapper实现类负责基础servlet类的生命周期。

### Context

Context接口的实例表示一个Web应用程序，一个Context实例可以有一个或多个Wrapper实例作为其子容器。

> 使用Mapper来映射不同的servlet实例

映射器只存在于tomcat4中，tomcat5使用了另一种方法来查找子容器。

## 生命周期

### Lifecycle

单一启动/关闭机制是通过LifeCycle接口来实现。

### LifecycleEvent

### LifecycleListener

## 载入器

### Loader

WebappLoader对象中使用WebappClassLoader类的实例作为其类载入器

> 注意

当某个载入器相关联的容器需要使用某个servlet类时，即当该类的某个方法被调用时，会先调用载入器的getClassLoader
方法来获取该类载入器的实例。然后，容器会调用类载入器的loadClass()来载入这个servlet类。


## WebappClassLoader类

Web应用程序中负责载入类的类载入器是WebappClassLoader类的实例。继承URLClassLoader类，使用URLClassLoader类
来载入应用程序所需要用到的Java类。


### 类缓存

资源是ResourceEntry的实例, 所有缓存的类会存储在resourceEntries集合中，那些载入失败的类存储到另一个notFoundResources集合中。

```java
/**
 * The cache of ResourceEntry for classes and resources we have loaded,
 * keyed by resource name.
 */
protected HashMap resourceEntries = new HashMap();


/**
 * The list of not found resources.
 */
protected HashMap notFoundResources = new HashMap();
```
