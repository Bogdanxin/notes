# SpringCloud 组件学习与分析

## Feign + OpenFeign

feign 是声明式 http 客户端，作用就是用来优雅的请求 http 请求

### 使用方法

1. 首先在 Application 类中使用 `@EnableFeignClient` 注解，启用 feign

2. 然后声明 feign 的 client 接口

    ```java
    @FeignClient("user-server") // 这里写的是服务提供端的名称，不是 url 路径
    public interface UserClient {
    
        @GetMapping("/user/now")
        public String now();
    
    
        @GetMapping("/user/{id}")
        public User queryById(@PathVariable("id") Long id);
    }
    ```

3. 在调用时候自动注入 client，调用client 方法即可

#### 自定义 Feign 的配置

![image-20220222213329640](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220222213329640.png)

一般定义日志级别的配置，这样的方法有两种：

1. 配置文件形式：

    * 全局生效：

        ```yaml
        feign:
        	client:
        		config:
        			default: # 使用 default 的配置代表请求全局服务都是使用这个日志级别
        				loggerLevel: FULL
        ```

    * 局部生效：

        ```yaml
        feign:
        	client:
        		config:
        			servername: # 使用 servername 的配置仅代表对某个服务设置日志级别，其他服务不会影响
        				loggerLevel: FULL
        ```

2. 使用配置类：

    首先声明一个 bean，设置 logger 的级别

    ```java
    public class FeignClientConfiguration {
        
        @Bean
        public Logger.Level feignLogLevel() {
            return Logger.Level.BASIC;
        }
    }
    ```

    如果是全局配置，则把它放到 `@EnableFeignClients` 这个注解中，代表启用 feign 的同时也对 logger level 进行设置

    `@EnableFeignClients(defaultConfiguration = FeignClientConfiguration.class)` 

    如果使用局部配置，则把它放到 `@FeignClient` 注解中，代表的是进队这个 client 生效

    `@FeignClient(value = "servername", configuration = FeignClientConfiguration.class)`

### Feign 的性能优化

Feign 的底层实现还是通过 HTTP 客户端实现，有以下这些实现：

* URLConnection：是默认实现，jdk 自带 connection，不支持连接池
* Apache HttpClient：支持连接池
* OKHttp：支持连接池

优化的方向：

* 使用连接池代替默认的 URLConnection
* 修改日志级别，最好用 basic 和 none





### OpenFeign 的自动加载以及生成动态代理

在 Spring 应用启动时，需要将 OpenFeign 组件注入到 spring 容器中。

在 app 启动类通过 `@EnableFeignClients` 注解，这个注解中有 `@Import` 注解，引入了 FeignClientsRegistrar 类，这个类就是在 Spring 初始化时调用自身方法，扫描指定 package 下的所有带有 `@FeignClient` 注解的类，生成对应的动态代理类，并将其注册为 bean。

这里重点关注：如何将带有 `@FeignClient` 注解的类，生成动态代理，并注入到 Spring 容器中。

1. 注入 Spring 容器的步骤很简单，就在 FeignClientsRegistrar 类的 registerFeignClient 方法中，将生成的动态代理包装成 bean，注入到容器中。

    ```java
    private void registerFeignClient
        (BeanDefinitionRegistry registry, 
         AnnotationMetadata annotationMetadata, 
         Map<String, Object> attributes) {
        	// ... 省略
        	FeignClientFactoryBean factoryBean = new FeignClientFactoryBean();
    		BeanDefinitionBuilder definition = 
                BeanDefinitionBuilder.genericBeanDefinition(clazz, () -> {
    			// 省略
    			Object fallbackFactory = attributes.get("fallbackFactory");
    			if (fallbackFactory != null) {
    				factoryBean.setFallbackFactory(fallbackFactory instanceof Class ? 
                                                   (Class<?>) fallbackFactory
    						: ClassUtils.resolveClassName(fallbackFactory.toString(), null));
    			}
                // 这段代码就是生成动态代理，然后再将拿到的动态代理类注入到容器中
    			return factoryBean.getObject();
    		});
    		
        	// 注入 spring 容器中
    		BeanDefinitionHolder holder = new BeanDefinitionHolder(beanDefinition, className, new String[] { alias });
    		BeanDefinitionReaderUtils.registerBeanDefinition(holder, registry);
    	}
    ```

2. 跟进到 getObject 方法中，发现调用方法链，整个链路贯穿 open-feign 组件到核心组件 feign。

    ```java
    FeignClientFactoryBean#getObject -> FeignClientFactoryBean#getTarget -> DefaultTargeter#target -> Builder#target(feign.Target<T>) -> ReflectiveFeign#newInstance -> InvocationHandlerFactory.Default#create
    static final class Default implements InvocationHandlerFactory {
    
        @Override
        public InvocationHandler create(Target target, Map<Method, MethodHandler> dispatch) {
          return new ReflectiveFeign.FeignInvocationHandler(target, dispatch);
        }
      }
    ```

    整个流程比较清晰，在初始化过程中扫描的 `@FeignClient` 中的信息（包括被代理的类的类名、全路径类名，代理方法的url等等）作为数据生成到对应的动态代理类中，然后添加到容器中。之后只需要等待被调用即可。

至此就过了一遍从项目初始化到生成对应动态代理类的过程。但是，我们并没有实际调用，所以接下来是对代理类的调用过程。

### 执行远程调用

这个比较简单，在调用时，只需要知道被调用对象的 url、全类名等信息后，通过 feign 定义的方法进行网络请求，得到响应后，对响应进行解析，动态代理类最后返回给调用的服务。





## Ribbon 负载均衡

### 基本流程：

![image-20220222135726713](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220222135726713.png)

在消费端通过 `@LoadBalanced` 注解在 RestTemplate 的 bean 上，使得在向服务端进行请求时，会先向注册中心拉取相关服务列表，然后通过「负载均衡」选择一个合适服务，进行请求。

> 由于发起请求的时候，并不是在向 host 地址请求，而是向服务名称发请求，这就说明在「负载均衡」的时候，会对请求进行解析。

### 分析：

#### 负载均衡流程：

`@LoadBalanced` 注解实现负载均衡的过程，主要在 LoadBalancerInterceptor 类的 intercept 方法中。

> LoadBalancerInterceptor 类实现了 ClientHttpRequestInterceptor 接口，用于拦截客户端的请求。那么 LoadBalancerInterceptor 拦截的请求，就可以在 intercept 方法中实现上述的流程

```java
public class LoadBalancerInterceptor implements ClientHttpRequestInterceptor {

	@Override
	public ClientHttpResponse intercept(final HttpRequest request, final byte[] body,
			final ClientHttpRequestExecution execution) throws IOException {
        // 获取到 url
		final URI originalUri = request.getURI();
        // 根据 url 获取到 server 的名称，也就是 这里的 userservice
		String serviceName = originalUri.getHost();
		// 这里是关键调用 loadBalancer 的 execute 方法
		return this.loadBalancer.execute(serviceName,
				this.requestFactory.createRequest(request, body, execution));
	}

}
```

一直跟进，到达RibbonLoadBalancerClient#execute 方法，发现在这里获取了真正执行「负载均衡」的 loadbalancer，然后通过 loadbalancer 选择从注册中心拉取的服务列表中的一个服务，最后执行向这个服务发起请求。

```java
public <T> T execute(String serviceId, LoadBalancerRequest<T> request, Object hint)
			throws IOException {
    // 获取负载均衡类，并且从注册中心拉取到服务列表（allServerList属性）
		ILoadBalancer loadBalancer = getLoadBalancer(serviceId);
    // 从列表中选择一个服务，这里就需要选择不同的策略（可以关注 IRule 接口的实现类）
		Server server = getServer(loadBalancer, hint);
    // 实例化服务
		RibbonServer ribbonServer = new RibbonServer(serviceId, server,
				isSecure(server, serviceId),
				serverIntrospector(serviceId).getMetadata(server));
	// 向服务发出请求
		return execute(serviceId, ribbonServer, request);
	}
```

流程的总结图：

![image-20220222144810618](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220222144810618.png)

#### 负载均衡策略

继承关系如图所示：

![image-20220222145352254](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220222145352254.png)

常见的策略类，以及描述：

![image-20220222145647554](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220222145647554.png)

##### 修改策略

想要使用其他的描述规则，或者改变当前的负载均衡规则，

1. 只需要在在 spring 容器中注入一个其他的规则 bean，然后就可以了

```java
@Configuration
public class Config {
    public IRule randomRule() {
        return new RandomRule();
    }
}
```

2. 修改配置文件

```
user-server:
	ribbon:
		NFLoadBalancerRuleClassName: com.netflix.loadbalancer.RandomRule
```

> 注意，两者有一些区别，前者使用 bean 注入规则后，会对所有的服务都生效，也就是说除了user-server ，如果其他服务也有多个服务实体，也会按照这个规则进行选择；后者则只是单独指出使用负载均衡规则的服务名称，这样只有这个服务会使用

#### Ribbon 的懒加载

Ribbon 模式使用懒加载，也就是在进行第一次请求时，才会访问配置中心创建 LoadBalanceClient 进行缓存，之后再次请求时候，就会从缓存中读取数据（当然配置中心也会定时 ping 服务，保证服务可用）。所以显而易见，第一次请求会有较长的访问时间。

如果要修改为饥饿加载，需要在配置文件中修改：

```
ribbon:
  eager-load:
    enabled: true
    clients: 
    	- xxx # 这里需要懒加载的服务，也就是说，指定某个服务时饥饿加载
    	- xxxServer
```

## Nacos

### Nacos 服务分级模型

![image-20220222160453353](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220222160453353.png)

如图所示，服务、集群、实例的关系就是这样。但是之前是没集群这个划分的。也就是一个服务有多个实例作为支撑，访问这个服务，就是从这个服务中挑选一个实例即可。但是现在由于服务的规模扩大，不能将多个实例同时部署在同一个机房（或者地点），这时就引入了一个集群的划分，这样一个集群就可以代表一个地区或者机房，以集群的规模给服务提供支持。

集群的划分更是为了防止跨地域进行调用，尽量使本地消费者调用本地服务，只有在本地服务不可用时才会调用其他集群的服务。

#### 设置访问相同集群：

##### 1. 在配置文件中设置相同集群：

```
spring:
  cloud:
    nacos:
      server-addr: localhost:8848 # 设置 nacos 地址
      discovery:
        cluster-name: hangzhou # 设置集群名称（用于分隔不同集群）
```

也可以在启动配置添加配置信息：

``-Dspring.cloud.nacos.discovery.cluster-name=hangzhou``

##### 2. 在负载均衡中配置相关负载均衡规则

和上面的负载均衡规则配置一样，也是两种方式，只不过规则设置为 NacosRule 类。

一种是在配置类中设为全局配置

```java
 @Bean
    public IRule randomRule( ) {
        return new NacosRule();
    }
```

另一中在配置文件中为某个服务单独设置规则类

```
user-server:
  ribbon:
    NFLoadBalancerRuleClassName: com.alibaba.cloud.nacos.ribbon.NacosRule # 负载均衡规则
```

#### 设置权重

![image-20220222170712641](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220222170712641.png)

对同一个集群下的不同实例进行权重的设置：

1. 可以实现不同性能的实例服务器承担不同的任务流量
2. 在升级应用过程中，可以对升级应用进行权重的调整，实现平滑升级

### 环境隔离

略。。

### Nacos 和 Eureka 区别

* 相同处：两者在作为配置中心时，在消费者端都是通过定时拉取 pull 的方式获取服务列表。服务提供端都是主动向注册中心注册服务信息
* 不同处：在服务提供端，nacos 分为两种实例：临时实例和非临时实例，临时实例只会由服务提供端定时向 nacos 发送心跳检测，非临时实例除了向 nacos 发送心跳，nacos 也会主动会询问，如果一旦没有响应，nacos 就会主动向消费端推送消息（所以 nacos 是 pull 和 push 结合的）。但是非临时实例不会被 nacos 主动删除

![image-20220222193859573](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220222193859573.png)

配置信息：

```java
spring:
  cloud:
    nacos:
      discovery:
        ephemeral: false
```



![image-20220222194028110](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220222194028110.png)

### Nacos 配置管理

nacos 除了能够作为注册中心，还可以作为配置中心。存放其他实例服务的配置信息，提供给多台服务使用，在实例服务启动的时候配合本地配置和 nacos 的配置一并启动。当需要修改某些配置的时候，nacos 会主动告知注册的服务，让其重新读取改动数据，实现热更新。

一般只会将一些类开关的配置存放到 nacos 中，都是一些有热更新需求的。

#### 设置配置

![image-20220222195720442](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220222195720442.png)

设置配置的步骤如上，先读取 nacos 上的配置文件，然后在读取本地的 application.yml 文件。但是由于 nacos 是远程服务，本地服务启动时，需要先知道nacos 的相关配置，所以，需要先读取这些配置，那么这些配置就应该配置到优先于 application.yml 的配置。也就是 bootstrap.yml

> 在配置 bootstrap.yml 时，配置的是 nacos 作为配置中心的信息，部分信息是可以代替 application.yml 中的 nacos 配置的（这里既可以作为注册中心，也有连接nacos地址的配置）。但是有一部分信息是必须不能在 application.yml 设置，比如之前的非临时实例，经过实验就不可以设置，因为有冲突，但是具体是什么还没来得及检查，应该是有问题的

同时，nacos 的配置名称是有讲究的 DataID 需要需要设置为 "[spring.application.name]-[spring.profiles.active].[spring.cloud.nacos.config.file-extension]" 的类型

```
spring:
  application:
    name: 应用名称

  profiles:
    active: xxx (这里的 active 指的是nacos 的 namespace)

  cloud:
    nacos:
      server-addr: localhost:8848
      config:
        file-extension: 后缀名
```

#### 配置热更新

1. 我们一般对配置进行读取的时候，需要对使用 `@Value` 注解属性的类使用 `@RefreshScope` 注解保证热更新。

2. 使用 `@ConfigurationProperties` 注解，prefix 代表配置前缀，定义的类属性名就是配置后缀，进行拼接就得到完整的配置，配置的值就是读取 nacos 配置中的值
    ```java
    @Compont
    @Data
    @ConfigurationProperties(prefix = "pattern")
    public class PatternProperties {
        private String dateformat;
    }
    
    对应的配置就是 
    pattern:
    	dateformat: xxx(具体的值，对应就是 dateformat 属性)
    ```

#### 多环境配置共享

之前的配置的 Date ID 都是 [spring.application.name]-[spring.profiles.active].后缀名" 的类型，也就只能对一个 namespace 起作用，如果需要设置多个环境共享，那么可以可以改为："[spring.application.name].后缀名" 的形式，没有了 active 的属性，多个环境就可以共享了

> 多配置的优先级：
>
> 服务名.profile.yaml > 服务名.yaml > 本地配置

总结：

![image-20220222205626708](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220222205626708.png)

## 统一网关 Gateway

网关的作用：

1. 对用户做身份认证、权限校验
2. 将用户请求路由到微服务，实现负载均衡
3. 对用户请求进行限流

> 这里的「负载均衡」和在远程调用中实现的「负载均衡」有所不同，前者作用与进入服务的请求进行服务的选择，后者作用于对从配置中心拉取的服务进行选择

### 网关配置

网关路由可以配置内容包括：

* 路由 id：路由唯一标识
* uri：路由目的地之，支持 lb（指定服务） 和 http（指定地址） 两种
* predicates：路由断言，判断请求是否符合要求，符合则转发到路由目的地
* filters：路由过滤器，处理请求或者响应

```yaml
server:
  port: 10010

spring:

  application:
    name: gateway

  cloud:
    nacos:
      server-addr: localhost:8848
	# ====== 以上均为正常的配置，当然也需要设置 nacos 地址 ====== # 
    gateway:
      routes:
      	# 设置的服务唯一的名称（id 可以和在注册中心服务名称不同）
        - id:  user-service
          # 设置服务的 uri，user-server 就是在注册中心中的名称，和 id 不同
          uri: lb://user-server
          predicates: # 路由断言，判断请求是否符合规则
            - Path=/user/**

        - id: order-server
          uri: lb://order-server
          predicates:
            - Path=/order/**

```

#### 路由断言

是由 spring cloud 中的断言工厂进行处理：

![image-20220223115917014](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220223115917014.png)

### 路由过滤器 GatewayFilter

GatewayFilter 是网关提供的一个过滤器 ，可以对进入网关的请求和微服务返回响应进行处理

![image-20220223120411298](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220223120411298.png)

过滤器工厂 GatewayFliterFactory

![image-20220223122051417](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220223122051417.png)



对某个服务实现过滤拦截的配置，只需要在这个服务下的filters配置拦截类即可，如果想要对全局服务都生效，则设置在 gateway 下的 default-filters 生效。

```yaml
spring:
  cloud:
    nacos:
      server-addr: localhost:8848

    gateway:
      routes:
        - id:  user-service          
          filters:
            - AddRequestHeader=Truth, Time Limit ...
      default-filters:
      	- AddRequestHeader=Truth, Time...
```

#### 自定义过滤器：

如果想要实现自定义逻辑，需要实现 GlobalFilter 接口，并重写方法，exchange 参数保留了整个请求的上下文， chain 变量作为整个过滤链对象，起到传递上下文的作用。

> 注意：过滤器需要设置执行顺序，也就是 Order 接口或者 Order 注解

```java
@Component
@Order(-1)
public class AuthorizeFilter implements GlobalFilter {
    @Override
    public Mono<Void> filter(ServerWebExchange exchange, GatewayFilterChain chain) {
        ServerHttpRequest request = exchange.getRequest();
        MultiValueMap<String, String> params =
                request.getQueryParams();
        String admin = params.getFirst("authorization");
        if ("admin".equals(admin)) {
            return chain.filter(exchange);
        }

        ServerHttpResponse response = exchange.getResponse();
        response.setStatusCode(HttpStatus.UNAUTHORIZED);
        return exchange.getResponse().setComplete();
    }
}
```

#### 过滤器执行顺序（源码）

源码参考 `RouteDefinitionRouteLocator#getFilter() `和 `FilteringWebHandler#handle() `方法

**结论**：

过滤器的兼容问题:

GatewayFilter 有三种过滤器，分别是①路由过滤器、②defaultFilter、③全局过滤器。三个配置方式不相同：①是在Gateway 的配置文件中 routes 进行 filter 配置；②是在 Gateway 的 default-filters 配置；③是通过实现 GlobalFilter 配置。

spring 会在启动过程中，将三种过滤器以链式结构（list）装配在一起，由于 GlobalFilter 接口并不兼容前两种的 GatewayFilter，所以特地使用适配器设计模式创建了 GatewayFilterAdapter 类来兼容 GatewayFilter，所以三者可以作为同一个链上的过滤器。

过滤器的执行顺序问题：

在配置文件中，每类过滤器都有默认的 order 值，如果不指定，那么就是每种都按照1 2 3...的顺序排序，这样就会出现路由过滤器和 defaultFilter 都有 1 2 3 的排序值。下面就是排序的规则

三种过滤器执行顺序按照两种规则排序

1. order 值越小，优先级越高（对所有过滤器、都生效）
2. order 值相同，那么按照 defaultFilter -> 局部路由过滤器 -> 全局过滤器 顺序。

### 跨域问题处理

跨域：域名不一致就是跨域，主要包括：

* 域名不同：taobao.com 和 taobao.org、 jd.org 、store.jd.com
* 域名相同，端口不同：localhost:8080 和 localhost:8081

跨域问题：浏览器禁止请求发起者与服务端发生跨域 ajax 请求，请求被浏览器拦截的问题

解决方法：CORS

## 消息队列 MQ

### 同步异步调用

同步调用：

时效性强，能立即得到结果。但是耦合度高，性能吞吐能力差，会有额外资源消耗，有级联失败的风险

异步调用（事件驱动型）：

优点：

1. 实现解耦，由于出现了 Broker 这个中间件，调用方只需要对 Broker 中间件发送事件消息即可，剩下的就由服务方订阅监听事件通知即可
2. 提升吞吐量，由于之前的解耦，我们可以保证一旦调用方发布事件后就可以返回，相对于同步调用等待服务方响应，性能会提升很多
3. 没有级联失败问题，一个服务方出现问题，不会影响调用方等待。
4. 流量削峰，broker 可以起到缓存的作用，能够将服务方处理不了的消息暂存起来等待能够处理后进行下一步处理。

缺点：

依赖于 Broker 的可靠性，如果 broker 性能差，会对整个系统有很大影响。

### RabbitMQ

mq 通常作为 broker 支持异步通信，以下为常见 mq：

![image-20220223155413551](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220223155413551.png)

### RabbitMQ 的整体架构

![image-20220223180634865](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220223180634865.png)

#### 快速入门

发布端：

```java
public class PublisherTest {
    @Test
    public void testSendMessage() throws IOException, TimeoutException {
        // 1.建立连接
        ConnectionFactory factory = new ConnectionFactory();
        // 1.1.设置连接参数，分别是：主机名、端口号、vhost、用户名、密码
        factory.setHost("localhost");
        factory.setPort(5672);
        factory.setVirtualHost("/");
        factory.setUsername("guest");
        factory.setPassword("guest");
        // 1.2.建立连接
        Connection connection = factory.newConnection();

        // 2.创建通道Channel
        Channel channel = connection.createChannel();

        // 3.创建队列
        String queueName = "simple.queue";
        channel.queueDeclare(queueName, false, false, false, null);

        // 4.发送消息
        String message = "hello, rabbitmq!";
        channel.basicPublish("", queueName, null, message.getBytes());
        System.out.println("发送消息成功：【" + message + "】");

        // 5.关闭通道和连接
        channel.close();
        connection.close();

    }
}

```

消费端

```java
public class ConsumerTest {

    public static void main(String[] args) throws IOException, TimeoutException {
        // 1.建立连接
        ConnectionFactory factory = new ConnectionFactory();
        // 1.1.设置连接参数，分别是：主机名、端口号、vhost、用户名、密码
        factory.setHost("localhost");
        factory.setPort(5672);
        factory.setVirtualHost("/");
        factory.setUsername("guest");
        factory.setPassword("guest");
        // 1.2.建立连接
        Connection connection = factory.newConnection();

        // 2.创建通道Channel
        Channel channel = connection.createChannel();

        // 3.创建队列
        String queueName = "simple.queue";
        channel.queueDeclare(queueName, false, false, false, null);

        // 4.订阅消息，通过添加回调函数，在触发这个事件时候会被调用
        channel.basicConsume(queueName, true, new DefaultConsumer(channel){
            @Override
            public void handleDelivery(String consumerTag, Envelope envelope,
                                       AMQP.BasicProperties properties, byte[] body) throws IOException {
                // 5.处理消息
                String message = new String(body);
                System.out.println("接收到消息：【" + message + "】");
            }
        });
        System.out.println("等待接收消息。。。。");
    }
}

```

![image-20220223201118648](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220223201118648.png)

#### SpringAMQP

AMQP 是指在应用程序或者传递业务消息的开放标准，协议与语言平台无关，符合微服务中的独立性要求

Spring AMQP 是在 AMQP 基础上定义的一套 api 规范，提供模板接收发送消息。spring-amqp 是基础抽象，spring-rabbit 是默认实现。

#### HelloWorld queue使用方法

![img](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/python-one.png)

##### publisher：

配置

```yaml
spring:
  rabbitmq:
    addresses: localhost:5672 # rabbitmq 地址
    virtual-host: / # 虚拟主机（隔离）
    username: guest
    password: guest
```

发送消息代码：

```java
@RunWith(SpringRunner.class)
@SpringBootTest
public class SpringAmqpTest {

    @Autowired
    private RabbitTemplate rabbitTemplate;

    @Test
    public void testSimpleQueue() {
        String queueName = "simple.queue";
        String message = "hello";

        rabbitTemplate.convertAndSend(queueName, message);
    }
}
```

##### consumer

同样的配置

接收消息：需要对接收端添加一个 listener，作为「回调函数」编辑消费逻辑，在接收到消息后进行消费

```java
@Component
public class SpringRabbitListener {
	// 声明监听的队列
    @RabbitListener(queues = "simple.queue")
    public void listenSimpleQueue(String msg) {
        System.out.println("接收到消息 ： "  + msg);
    }

}
```

#### Work queues 使用方法

![img](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/python-two.png)

一个队列绑定多个消费者，发布一个消息，消费者只有一个能够进行消费。这样的好处在于当发布者不断发布消息，能够有多个消费者进行消费。

work queue 默认存在一个叫做「消费预取」的特征，也就是不论几个消费者的消费能力，消息的分配是平均的。publisher 发送 100 个消息，c1 消费 50 个，c2 消费 50 个。并不会根据消费能力进行分配。

「消费预取」是：在每个 consumer 进行消费时候，自己的 channel 会预先从 queue 中取出消息，不论 consumer 能不能消费的完，这样就导致进行平均分配。

##### 取消「消费预取」

在消费者配置文件中设置预取值，设为一就是预取 1 个，消费完再取，这样就保证不会出现预取的现象。

```yaml
spring:
  rabbitmq:
    listener:
      simple:
        prefetch: 1
```





以下的模式与 workqueue 的区别在于，publisher 发布消息时，消息能够同时发布给多个 consumer。实现的原理是通过一个 exchange 发布到多个 queue，每个 queue 再有对应的 consumer进行消费（当然这里 queue 上如果有多个消费者，就和 workqueue 上的一样了）

Exchange：用于转发消息，分别有 Fanout(广播)、Direct(路由)、Topic(话题)。但是 exchange 不能存储数据，只负责转发消息，消息发送失败不会重试。

下面之间的区别就在于 exchange 怎么发送消息

#### FanoutExchange 使用

![img](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/python-three.png)

发布端：和之前类似，只不过发布消息时候需要特别注意下，参数列表为[交换机名称、routingkey、消息]
```java
@Test
    public void sendFanoutExchange() {
        String exchange = "test.exchange";
        String msg = "hello everyone";

        rabbitTemplate.convertAndSend(exchange,"" ,msg);
    }
```

接收端：

首先声明一个 exchange 的 bean 和两个 queue 的bean连接到 exchange 上。建立连接也分别需要两个 bean。

```java
@Configuration
public class FanoutConfig {

    @Bean
    public FanoutExchange fanoutExchange() {
        return new FanoutExchange("test.exchange");
    }

    @Bean
    public Queue fanoutQueue1() {
        return new Queue("fanout.queue1");
    }

    @Bean
    public Binding bindingQueue1() {
        return BindingBuilder.bind(fanoutQueue1()).to(fanoutExchange());
    }


    @Bean
    public Queue fanoutQueue2() {
        return new Queue("fanout.queue2");
    }

    @Bean
    public Binding bindingQueue2() {
        return BindingBuilder.bind(fanoutQueue2()).to(fanoutExchange());
    }

}
```

然后就是对每个queue 创建一个 listener 作为监听器，用于接收消息。和之前类似就不写了

#### routes 模式

使用 DirectExchange 会将接收到的消息根据规则路由到指定的 Queue，因此称为「路由模式」

* 每个 Queue 都与 Exchange 设置一个 BindingKey
* 发布者发布消息时，会指定消息的 RoutingKey
* Exchange 会将消息发送到 BindingKey 相同的 queue 上。

![img](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/python-four.png)

 在 routing 模式中，编写代码除了需要设置 bind 的 queue，还需要设置 queue 和 exchange 的 bindingKey。发布方没有特别的改变只需要在发布时候添加一个 routingKey。

```java
@RabbitListener(@QueueBinding(
	value = @Queue(name = "direct.queue"),
    key = {"red", "blue"},
    exchange = @Exchange(name = "direct.exchange", type = ExchangeTypes.DIRECT)
))
public void listenDirectQueue(String msg) {
    处理逻辑..
}
```



#### TopicExchange - 发布订阅

TopicExchange 与 DirectExchange 类似，区别在于 routingKey 必须是多个单词的列表，并且「.」的形式分割。queue 与 exchange 绑定的 key 可以使用通配符：

#：代表0 个或者多个单词

*：代表一个单词

![](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/python-five-20220224200429519.png)

这个和 DirectExchange 不同之处在于，Direct 只能路由一个单词的 key，但是 Topic 可以路由多个。这样可以关注的类型就可以变得更加丰富了。

```java
@RabbitListener(bindings = @QueueBinding(
        value = @Queue(name = "topic.queue1"),
        exchange = @Exchange(name = "topic.exchange", type = ExchangeTypes.TOPIC),
        key = "china.#"
))
public void listenTopicQueue1(String msg) {
    System.out.println("消费者接收到 topic.queue1 的消息 ： "  + msg);
}
```



## Sentinel

微服务的雪崩问题：某个服务被若干其他服务所依赖，这个服务一旦出现问题，无法作出相应，那么其他依赖于他的服务也会相应收到影响，从而大规模出现问题，从而出现雪崩的问题。

对应的解决方案：

1. 超时处理：设置超时的时间，请求一旦超过一定时间没有响应就会返回错误信息，不会无休止等待。但是在等待过程中还是会有流量进入，还是会造成不小的影响
2. 舱壁模式：限定每个业务使用线程的数量，避免完全耗尽服务器资源
3. 熔断降级：由『断路器』统计业务执行的异常比例，如果超过阈值则会**熔断**该业务，拦截访问该业务的一切请求。这个和超时处理有点类似，但是这个会统计当前调用服务的异常数，根据设置的异常阈值决定是否直接拒绝访问
4. 流量控制：限制业务访问的流量，避免因为业务流量徒增而故障。

> 以上1 2 3 是在服务已经出现异常后进行保护，4 是在异常出现前就进行保护

### 引入 Sentinel



![image-20220225195340308](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220225195340308.png)

> sentinel 主要通过「舱壁模式」、「熔断降级」、「流量控制」三个方式解决微服务雪崩的问题。

**簇点链路**：就是项目内调用的链路，链路中被监控的每个接口就是一个资源。默认情况下 sentinel 会监控 Spring MVC 的每个端点（endpoint），如果想要监控其他的接口，需要自行注解控制。

### 限流功能

限流可以通过流控进行管理，主要有以下三种流控模式：

1. 直接模式：统计当前资源的请求，触发阈值时对当前的资源直接限流，也就是默认的模式

2. 关联：统计与当前资源相关的另一个资源，触发阈值时，会当前的资源限流

    常用于「并行」的服务，比如一个数据库既有读服务，也有写服务，如果写服务优先更高，那么就可以对读服务进行关联限流，一旦写服务访问量达到阈值，则对读服务进行限流。

3. 链路：统计从执行链路访问到本资源的请求，触发阈值时，对指定链路限流

    常用于某个服务如果有多个调用者，可以根据服务的能力选择某个调用进行限流，其他的服务不进行限流。 

如果对某个不是 controller 的服务进行限流，需要通过 @SentinelResource 的配置声明，同时要在配置里表明不使用默认配置

```yaml
spring:
  cloud:
	sentinel:
      web-context-unify: false
     
```

#### 失败方式

![image-20220225212944417](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220225212944417.png)

默认模式是快速失败，一旦出现问题就会立刻抛出异常，拒绝访问，下面主要介绍剩下两种

##### WarmUp

warmup 也叫预热模式，是应对冷启动的方案，请求阈值初始值是 threshold / coldFactor，持续指定时间后，逐渐提高到 threshold。从而防止应用冷启动过程中，万一出现大流量直接把服务击垮的问题。

![image-20220225213937375](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220225213937375.png)

##### 排队等待

当请求超过 qps 阈值时，快速失败和 warmup 都会拒绝新的请求并抛出异常。但是排队等待会让所有请求进入一个等待队列，然后按照阈值允许的时间间隔依次执行。后来的请求必须等待前面的执行完成，如果请求预期时间超过最大等待时间，则会被拒绝。

例如下图中，如果 qps=5，意味着一个请求 200ms，超时时间 2s，意味着超时等待 2s 后就会被拒绝。那么开始不论是同时进入还是依次，都会安排在等待队列中，严格按照 200ms 一个请求的顺序执行。这样队列里的请求数量和每个执行时间都是被计算好的。

![image-20220225214135702](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220225214135702.png)

作用：

假设有这样的场景，一个服务流量并不稳定，有可能这一秒的只有一个请求，下一秒就有 10个请求，再一秒没有请求。如果按照快速失败来的话，超过了 QPS 就会拒绝高出阈值的请求。但是因为排队等待存在，可以让没有处理的任务保留到超时时间，尽量让每个任务都能执行。从而达到「流量整形」的效果

![image-20220225214931779](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220225214931779.png)

##### 热点参数限流

这时特殊的限流手段，是对一个资源的某个参数进行限流，并且如果参数值等于额外项的值，则会使用特定的限流阈值。如图所示

![image-20220225220224584](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220225220224584.png)

### 降级服务

降级服务常用在当调用方调用服务时候，如果出现错误，对返回值有设置，可以设为特定的值，从而保证用户体验。

#### 线程隔离

信号量隔离和线程池隔离

信号量隔离：多个服务都是用一个信号量（计数器），当调用服务线程数量超过信号量，则拒绝请求，较为轻量。

线程池隔离：每个调用服务都会有多个线程池作为隔离，当一个服务出现问题，对其他线程池不会有影响

![image-20220226200618357](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220226200618357.png)

### 熔断降级

熔断降级也是解决雪崩的重要手段。思路是由『断路器』统计服务调用的异常比例、满请求比例，如果超过阈值则会『熔断』该服务。即拦截访问该服务的一切请求；当服务恢复时，断路器会开放该服务的请求。

![image-20220226201254809](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220226201254809.png)

熔断策略：慢调用、异常比例、异常数

* 慢调用：业务的响应时长（RT）大于指定时长的请求认定为慢调用请求。在指定时间内，如果请求数量超过设定的
    最小数量，慢调用比例大于设定的阈值，则触发熔断。例如：

    ![image-20220226202029256](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220226202029256.png)

    解读：RT超过500ms的调用是慢调用，统计最近10000ms内的请求，如果请求量超过10次，并且慢调用比例不低于0.5
    则触发熔断，熔断时长为5秒。然后进入half-open状态，放行一次请求做测试。

* 异常比例或异常数：统计指定时间内的调用，如果调用次数超过指定请求数，并且出现异常的比例达到设定的比例阈
    值（或超过指定异常数），则触发熔断。例如：

    ![image-20220226202429176](/Users/gwx/Library/Application Support/typora-user-images/image-20220226202429176.png)

    解读：统计最近1000ms内的请求，如果请求量超过10次，并且异常比例不低于0.5，则触发熔断，熔断时长为5秒。然后进入half-open状态，放行一次请求做测试。

### 授权规则

sentinel 也能起到对请求来源的判断，从而根据不同的来源进行拦截。但是我们已经有 Gateway 了，为什么还要一个 sentinel 做授权规则呢？很简单 Gateway 只能对所有访问他的请求进行拦截，但是无法保证代理的服务不会被恶意流量直接请求。所有 sentinel 就作为每个服务的代理，接收请求流量，一旦鉴权出现问题直接拒绝请求。

使用方法：

创建一个 RequestOriginParser 接口实现类，用来接收 request 并且解析特定的字段作为鉴权；然后在Gateway拦截器中添加一个Request拦截器，并对通过 Gateway 的请求添加一个相同的字段，这样就能保证只有来自 Gateway 的请求有特殊鉴权字段从而保证安全性。

#### 自定义异常结果

默认情况下，发生限流、降级、鉴权异常都会被拦截，抛出异常给调用方。如果需要自定义异常时返回的结果，需要实现 BlockExceptionHandler 接口。

```java
public interface BlockException {
    /**
     * 处理请求被限流、降级、授权拦截时抛出的异常 BlockException
     */
    void handle(HttpServletRequest request, HttpServletResponse response, BlockException e) throw Exception;
}
```

![image-20220226205942453](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220226205942453.png)

#### Sentinel 配置持久化

* 原始模式：将配置文件保存在内存中
* pull 模式：保存在本地文件或者数据库中，定时的读取，容易出现多个服务之间数据不一致问题
* push 模式：保存在配置中心，sentinel 客户端自行监听配置，一旦改变立刻修改

## 基于 seata 的分布式事务

### 理论基础

#### CAP 定理

Consistency（一致性）：用户访问分布式系统中的任意节点，得到的数据必须一致

Availability（可用性）：用户访问集群中任意健康节点，必须能得到响应，而不是超时或者拒绝

Partition（分区）：因为网络故障或者其他原因导致分布式系统中的部分节点与其他节点失去连接，形成独立分区。



![image](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220226213322729.png)

为什么 cap 中只能由两个特性共存呢？

首先，分区是一定会产生的，因为分布式系统的特点就决定了如果出现问题就会导致出现分区。那么如果我们需要保证一致性，两个分区之间数据是无法进行交流的，那么只能使所有分区不接受新数据从而保证数据一致性，但是不能接受新数据就表明这个服务是不可用的，所以 AP 是不可以和 C 共存；如果要保证可用性，同理，只能接收数据的读写，分区之间的数据不一致就会出现；如果一定要 CA，那么只能取消掉分区才能保证，那么也就不再是事务了。

#### BASE 理论

BASE 理论是对 CAP 的一种解决思路

* Basically Available（基本可用）：分布式系统在出现故障时，允许损失部分可用性，保证核心可用。
* Soft State（软状态）：一定时间内，允许出现中间状态，比如临时不一致状态
* Eventually Consistent（最终一致性）：虽然无法保证强一致性，但在软状态结束后，最终达到数据一致性。

而分布式事务最大的问题是各个子事务的一致性问题，因此可以借鉴CAP定理和BASE理论：

* AP模式：各子事务分别执行和提交，允许出现结果不一致，然后采用弥补措施恢复数据即可，实现最终一致
* CP模式：各个子事务执行后互相等待，同时提交，同时回滚，达成强一致。但事务等待过程中，处于弱可用状态。

为了解决分布式事务，需要各个子系统之间能够感知到彼此的事务状态，才能保证状态一致性，需要一个**事务协调者**来协调事务。子系统事务称为**分支事务**，各个分支事务合并称为**全局事务**
