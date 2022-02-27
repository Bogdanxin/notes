# spring 源码解析

请搭配[Spring.xmind](Spring.xmind)和[Spring 注解驱动.xmind](Spring注解驱动开发.xmind)一起使用。

## AOP 原理

### AOP 使用方法：

1. 声明一个需要被 AOP 切面的 bean。

2. 声明一个被 `@Aspect`注解的类，作为被切面类的增强类，注入到容器中。编写切入逻辑，以下为提供的例子：

    ```java
    @Aspect
    public class LogAspects {
    	// Pointcut 作用就是将切面抽离出来，提供给下面的几个方法一起使用
        @Pointcut("execution(public int spring.test.bean.Calculator.*(..))")
        public void pointCut() {}
    
        @Before("pointCut()")
        public void start() {
            System.out.println("start ...");
        }
    
        @After("pointCut()")
        public void end() {
            System.out.println("end ...");
        }
    
        @AfterThrowing(value = "pointCut()", throwing = "exception")
        public void afterException(JoinPoint joinPoint, Exception exception) {
            System.out.println(joinPoint.getSignature().getName() + " after exception ...:" + "{"+exception+"}");
        }
    
        @AfterReturning(value = "pointCut()", returning = "value")
        public void afterEnd(JoinPoint joinPoint, Object value) {
            System.out.println(joinPoint.getSignature().getName() + " after end ... return  value :" + value);
        }
    }
    
    ```

3. 声明一个配置类，注入以上两个 bean，然后对配置类添加`@EnableAspectJAutoProxy`注解启用 aop

### AOP 源码分析

#### 组件导入

由于我们需要`@EnableAspectJAutoProxy`注解启用 aop，所以这个注解就是第一个需要关心的地方。进入后，发现`@Import(AspectJAutoProxyRegistrar.class)`这个注解，这就和之前遇到的 `@Import` 注解一样了，是引入了一个 ImportSelector 或者 ImportBeanDefinitionRegistrar 进行相关组件的导入。

AspectJAutoProxyRegistrar就是自定义给 spring 容器进行组件导入

```java
class AspectJAutoProxyRegistrar implements ImportBeanDefinitionRegistrar {

	/**
	 * Register, escalate, and configure the AspectJ auto proxy creator based on the value
	 * of the @{@link EnableAspectJAutoProxy#proxyTargetClass()} attribute on the importing
	 * {@code @Configuration} class.
	 */
	@Override
	public void registerBeanDefinitions(
			AnnotationMetadata importingClassMetadata, BeanDefinitionRegistry registry) {
		// 1. 向容器中注册一个 AspectJAnnotationAutoProxyCreator，如果有必要
		AopConfigUtils.registerAspectJAnnotationAutoProxyCreatorIfNecessary(registry);
		// 2. 然后从容器中取出带有 @EnableAspectJAutoProxy 注解的bean
		AnnotationAttributes enableAspectJAutoProxy =
				AnnotationConfigUtils.attributesFor(importingClassMetadata, EnableAspectJAutoProxy.class);
        // 之后对这个 bean 中的注解属性进行分析，如果有属性就进行相关操作
		if (enableAspectJAutoProxy != null) {
			if (enableAspectJAutoProxy.getBoolean("proxyTargetClass")) {
				AopConfigUtils.forceAutoProxyCreatorToUseClassProxying(registry);
			}
			if (enableAspectJAutoProxy.getBoolean("exposeProxy")) {
				AopConfigUtils.forceAutoProxyCreatorToExposeProxy(registry);
			}
		}
	}

}
```

跟进到 AopConfigUtils#registerOrEscalateApcAsRequired 中。

```java
private static BeanDefinition registerOrEscalateApcAsRequired(
      Class<?> cls, BeanDefinitionRegistry registry, @Nullable Object source) {

   	Assert.notNull(registry, "BeanDefinitionRegistry must not be null");
	// 向容器中获取 org.springframework.aop.config.internalAutoProxyCreator 类bean，如果有就对传入的 cls 和 internalAutoProxyCreator比较优先级，然后对internalAutoProxyCreator 进行定制
  	if (registry.containsBeanDefinition(AUTO_PROXY_CREATOR_BEAN_NAME)) {
      	BeanDefinition apcDefinition = registry.getBeanDefinition(AUTO_PROXY_CREATOR_BEAN_NAME);
      	if (!cls.getName().equals(apcDefinition.getBeanClassName())) {
         	int currentPriority = findPriorityForClass(apcDefinition.getBeanClassName());
         	int requiredPriority = findPriorityForClass(cls);
         	if (currentPriority < requiredPriority) {
          	  apcDefinition.setBeanClassName(cls.getName());
         	}
      	}
      	return null;
   	}
	// 然后对传入 cls 进行装配，最后重新注入到 bean 容器中，默认情况下，cls 是一个 AnnotationAwareAspectJAutoProxyCreator 类，看名称就可以看出来，是一个注解装配 aop 代理的构造类
   	RootBeanDefinition beanDefinition = new RootBeanDefinition(cls);
   	beanDefinition.setSource(source);
   	beanDefinition.getPropertyValues().add("order", Ordered.HIGHEST_PRECEDENCE);
   	beanDefinition.setRole(BeanDefinition.ROLE_INFRASTRUCTURE);
   	registry.registerBeanDefinition(AUTO_PROXY_CREATOR_BEAN_NAME, beanDefinition);
   	return beanDefinition;
}
```

可以看到，这个方法就是用来生成一个 AOP 相关的bean。并且注册到容器中。

综上，我们可以看出，``AspectJAutoProxyRegistrar#registerBeanDefinitions`` 方法是用来向容器中注入一个AnnotationAwareAspectJAutoProxyCreator 类定义信息，用于之后创建 AOP 代理。根据这些分析，我们就可以认识到，AnnotationAwareAspectJAutoProxyCreator 类就是声明式 AOP 的核心类，接下来就是对他的进一步分析。

> 注意，在注册过程中，将 AnnotationAwareAspectJAutoProxyCreator 对应的 bean 名称设置为「org.springframework.aop.config.internalAutoProxyCreator」。这里有比较重要的意义，要留心。

#### AnnotationAwareAspectJAutoProxyCreator 组件

先看整体继承关系和逻辑： ![image-20220224132801776](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220224132801776.png)

由于 AnnotationAwareAspectJAutoProxyCreator 是 BeanPostProcessor 和 BeanFactoryAware 的实现类，所以可以料想到，AnnotationAwareAspectJAutoProxyCreator 的创建其实就是这两个的创建。我们在相关的方法上打上断点

```java
AbstractAutoProxyCreator#postProcessBeforeInstantiation
AbstractAutoProxyCreator#postProcessAfterInitialization
    
AbstractAdvisorAutoProxyCreator#setBeanFactory  -调用-> AbstractAdvisorAutoProxyCreator#initBeanFactory
    
AnnotationAwareAspectJAutoProxyCreator#initBeanFactory 重写父类方法
```

进入到方法后，发现优先执行的是 setBeanFactory 方法，查看方法调用栈可以了解到，在容器启动时候，会在 `AbstractApplicationContext#refresh` 方法调用的 同类的 `registerBeanPostProcessors` 方法，先将容器中的 BeanPostProcessor 注册到容器中。注册过程省略，之后的 bean 注册可以详细分析。大体过程就是 

```
registerBeanPostProcessors -> AbstractBeanFactory#getBean() -> AbstractBeanFactory#doGetBean -> AbstractAutowireCapableBeanFactory#createBean -> AbstractAutowireCapableBeanFactory#doCreateBean -> AbstractAutowireCapableBeanFactory#initializeBean -> AbstractAutowireCapableBeanFactory#invokeAwareMethods -> setBeanFactory -> initBeanFactory
```

这就是大体流程，这里并不是创建自行编写的 bean 并注入到容器，而是。对 Spring 中核心组件、BeanPostProcessor进行注册。

注意，在 doCreateBean 方法中，还有其他比较重要的方法，以下就是省略其他代码后，显示的重要流程

```java
AbstractAutowireCapableBeanFactory#doCreateBean 
protected Object doCreateBean(final String beanName, final RootBeanDefinition mbd, final @Nullable Object[] args)
			throws BeanCreationException {
		
		// ...
    	// 根据 bean 注册信息，创建 bean 实例对象
		if (instanceWrapper == null) {
			instanceWrapper = createBeanInstance(beanName, mbd, args);
		}
		
		// Allow post-processors to modify the merged bean definition.
		synchronized (mbd.postProcessingLock) {
			if (!mbd.postProcessed) {
				try {
					applyMergedBeanDefinitionPostProcessors(mbd, beanType, beanName);
				}
				catch ...
			}
		}

		// Initialize the bean instance.
		Object exposedObject = bean;
		try {
            // 先对 bean 赋值
			populateBean(beanName, mbd, instanceWrapper);
            // 对 bean 初始化，执行自定义初始化(init)操作方法
			exposedObject = initializeBean(beanName, exposedObject, mbd);
		}
		catch ...

		try {
            // 销毁 bean，执行自定义销毁的方法
			registerDisposableBeanIfNecessary(beanName, bean, mbd);
		}
		catch ...
		return exposedObject;
	}

```

```java
AbstractAutowireCapableBeanFactory#initializeBean 
protected Object initializeBean(final String beanName, final Object bean, @Nullable RootBeanDefinition mbd)
	{
		// 如果 bean 实现了 Aware 接口，调用 Aware 接口的相关方法
		invokeAwareMethods(beanName, bean);
		
		// 调用对核心组件的 BeanPostProcessorBefore 方法
		Object wrappedBean = bean;
		if (mbd == null || !mbd.isSynthetic()) {
			wrappedBean = applyBeanPostProcessorsBeforeInitialization(wrappedBean, beanName);
		}

    	// 调用自定义的 init-method 相关的方法
		try {
			invokeInitMethods(beanName, wrappedBean, mbd);
		}
		// 调用 BeanPostProcessorAfter 方法
		if (mbd == null || !mbd.isSynthetic()) {
			wrappedBean = applyBeanPostProcessorsAfterInitialization(wrappedBean, beanName);
		}

		return wrappedBean;
	}

```

以上就是将一个 AnnotationAwareAspectJAutoProxyCreator 类，也是一个 BeanPostProcessor 实现类，注册到 spring 容器中的整个过程。同时这个过程还伴随着对 AnnotationAwareAspectJAutoProxyCreator bean 的初始化，属性赋值，init 方法调用，BeanPostProcessor 等方法的调用。目的只有一个，为了丰富核心组件类的属性。

#### AnnotationAwareAspectJAutoProxyCreator 调用流程

上面我们了解到，如何将一个 AnnotationAwareAspectJAutoProxyCreator 创建并注册到 spring 容器中。由于 AnnotationAwareAspectJAutoProxyCreator 是一个BeanPostProcessor 实现类，在他创建到 spring 容器后，就可以对之后创建的 bean（一般是自行编写的 bean） 进行拦截，然后实现逻辑。

继续跟进代码，到``AbstractAutoProxyCreator#postProcessBeforeInstantiation``方法中，查看其方法栈

```java
ConfigurableListableBeanFactory#preInstantiateSingletons 
-> AbstractBeanFactory#getBean -> AbstractBeanFactory#doGetBean 
-> AbstractAutowireCapableBeanFactory#createBean
-> AbstractAutowireCapableBeanFactory#resolveBeforeInstantiation
```

前面都是一样的，直到 createBean这个方法

```java
@Override
	protected Object createBean(String beanName, RootBeanDefinition mbd, @Nullable Object[] args)
			throws BeanCreationException {

		// ...
		try {
			// Give BeanPostProcessors a chance to return a proxy instead of the target bean instance.
			Object bean = resolveBeforeInstantiation(beanName, mbdToUse);
			if (bean != null) {
				return bean;
			}
		}
		

		try {
			Object beanInstance = doCreateBean(beanName, mbdToUse, args);
			return beanInstance;
		}
        
		//...
	}
```

之前我们在创建AnnotationAwareAspectJAutoProxyCreator 的时候，调用了 doCreateBean。但现在转到了 

resolveBeforeInstantiation 方法。首先先看一下这个方法做了什么

```java
@Nullable
protected Object resolveBeforeInstantiation(String beanName, RootBeanDefinition mbd) {
   Object bean = null;
   if (!Boolean.FALSE.equals(mbd.beforeInstantiationResolved)) {
      // Make sure bean class is actually resolved at this point.
      if (!mbd.isSynthetic() && hasInstantiationAwareBeanPostProcessors()) {
         Class<?> targetType = determineTargetType(beanName, mbd);
         if (targetType != null) {
            bean = applyBeanPostProcessorsBeforeInstantiation(targetType, beanName);
            if (bean != null) {
               bean = applyBeanPostProcessorsAfterInitialization(bean, beanName);
            }
         }
      }
      mbd.beforeInstantiationResolved = (bean != null);
   }
   return bean;
}

	@Nullable
	protected Object applyBeanPostProcessorsBeforeInstantiation(Class<?> beanClass, String beanName) {
		for (BeanPostProcessor bp : getBeanPostProcessors()) {
			if (bp instanceof InstantiationAwareBeanPostProcessor) {
				InstantiationAwareBeanPostProcessor ibp = (InstantiationAwareBeanPostProcessor) bp;
				Object result = ibp.postProcessBeforeInstantiation(beanClass, beanName);
				if (result != null) {
					return result;
				}
			}
		}
		return null;
	}
// After* 类似就不多贴了
最后调到了这里
-> AbstractAutoProxyCreator#postProcessBeforeInstantiation
```

根据上面的代码可以看到，在 createBean 方法调用 doCreateBean 之前，先进入了 resolveBeforeInstantiation 方法，这里又调用了 BeanPostProcesso*Instantiation 方法，这个方法最后调到了 AbstractAutoProxyCreator#postProcessBeforeInstantiation。我们查看AbstractAutoProxyCreator 类发现，他实现的是InstantiationAwareBeanPostProcessor 的方法，BeanPostProcessor 的方法由 InstantiationAwareBeanPostProcessor代替实现称为了 default 方法。

由此我们可以得出结论：

1. InstantiationAwareBeanPostProcessor 实现了 BeanPostProcessor 接口，代替实现相关方法。
2. InstantiationAwareBeanPostProcessor 作用于 doCreateBean 之前，说明这个接口的实现类是在创建 bean 实例之前就已经开始对 bean 进行操作了。一般这种操作就是实现 bean 的动态代理。

综上，我们有进一步得知了，AbstractAutoProxyCreator在作为 BeanPostProcessor 组件率先在容器中创建，然后作为 InstantiationAwareBeanPostProcessor 在其他 bean 需要被创建代理对象时候通过 postProcess*Instantiation 进行相关逻辑的编写。

##### 生成动态代理类

先看 Before 方法

```java
	@Override
	public Object postProcessBeforeInstantiation(Class<?> beanClass, String beanName) {
		Object cacheKey = getCacheKey(beanClass, beanName);

		if (!StringUtils.hasLength(beanName) || !this.targetSourcedBeans.contains(beanName)) {
            // 如果增强的 bean 缓存中有这个 bean 的代理对象，无需创建代理对象了，直接返回 null 就可以了
			if (this.advisedBeans.containsKey(cacheKey)) {
				return null;
			}
            // 判断这个类是否是了切面相关接口的类，或者是否需要跳过代理这个类
			if (isInfrastructureClass(beanClass) || shouldSkip(beanClass, beanName)) {
				this.advisedBeans.put(cacheKey, Boolean.FALSE);
				return null;
			}
		}

		// Create proxy here if we have a custom TargetSource.
		// Suppresses unnecessary default instantiation of the target bean:
		// The TargetSource will handle target instances in a custom fashion.
		TargetSource targetSource = getCustomTargetSource(beanClass, beanName);
		if (targetSource != null) {
			if (StringUtils.hasLength(beanName)) {
				this.targetSourcedBeans.add(beanName);
			}
			Object[] specificInterceptors = getAdvicesAndAdvisorsForBean(beanClass, beanName, targetSource);
			Object proxy = createProxy(beanClass, beanName, specificInterceptors, targetSource);
			this.proxyTypes.put(cacheKey, proxy.getClass());
			return proxy;
		}

		return null;
	}
```

一般 Before 不会创建相关的代理类。往往是 After 创建，在 wrapIfNecessay 中判断是否需要进行代理，如果需要就进行代理的构建。

```java
	@Override
	public Object postProcessAfterInitialization(@Nullable Object bean, String beanName) {
		if (bean != null) {
			Object cacheKey = getCacheKey(bean.getClass(), beanName);
			if (this.earlyProxyReferences.remove(cacheKey) != bean) {
				return wrapIfNecessary(bean, beanName, cacheKey);
			}
		}
		return bean;
	}

```

跟进到 wrapIfNecessary 方法

```java
	protected Object wrapIfNecessary(Object bean, String beanName, Object cacheKey) {
		if (StringUtils.hasLength(beanName) && this.targetSourcedBeans.contains(beanName)) {
			return bean;
		}
		if (Boolean.FALSE.equals(this.advisedBeans.get(cacheKey))) {
			return bean;
		}
        // 判断是否需要跳过
		if (isInfrastructureClass(bean.getClass()) || shouldSkip(bean.getClass(), beanName)) {
			this.advisedBeans.put(cacheKey, Boolean.FALSE);
			return bean;
		}

		// Create proxy if we have advice.
        // 判断 bean 是否需要创建代理，并且筛选出代理的增强。
		Object[] specificInterceptors = getAdvicesAndAdvisorsForBean(bean.getClass(), beanName, null);
        // 根据增强进行代理的创建
		if (specificInterceptors != DO_NOT_PROXY) {
			this.advisedBeans.put(cacheKey, Boolean.TRUE);
			Object proxy = createProxy(
					bean.getClass(), beanName, specificInterceptors, new SingletonTargetSource(bean));
			this.proxyTypes.put(cacheKey, proxy.getClass());
			return proxy;
		}

		this.advisedBeans.put(cacheKey, Boolean.FALSE);
		return bean;
	}
```

`getAdvicesAndAdvisorsForBean(bean.getClass(), beanName, null);`方法就不过多进行分析了，其实就是在找可用的增强。首先找能被创建的增强，然后找@Aspect 注解的增强类，内部对应的增强方法，把这些增强advise汇聚到一个list 中，按照执行顺序排序。这样的一个 list 就可以用于之后的动态代理了。详细逻辑可以通过 debug 查看。

跟进到 createProxy 方法。中间夹杂着代理工厂创建以及相关判断的逻辑

```
AbstractAutoProxyCreator#createProxy -> ProxyFactory#getProxy(java.lang.ClassLoader) -> 
ProxyCreatorSupport#createAopProxy -> DefaultAopProxyFactory#createAopProxy
```

进入到 creatAopProxy，发现这里就是创建动态代理规则方式的地方，要么创建 jdk 动态代理要么就是 cglib。

```java
@Override
public AopProxy createAopProxy(AdvisedSupport config) throws AopConfigException {
   if (config.isOptimize() || config.isProxyTargetClass() || hasNoUserSuppliedProxyInterfaces(config)) {
      Class<?> targetClass = config.getTargetClass();
      if (targetClass == null) {
         throw new AopConfigException("TargetSource cannot determine target class: " +
               "Either an interface or a target is required for proxy creation.");
      }
      if (targetClass.isInterface() || Proxy.isProxyClass(targetClass)) {
         return new JdkDynamicAopProxy(config);
      }
      return new ObjenesisCglibAopProxy(config);
   }
   else {
      return new JdkDynamicAopProxy(config);
   }
}
```

选择 jdk代理 或者cglib 的规则：

[java - When is CGLIB proxy used by Spring AOP? - Stack Overflow](https://stackoverflow.com/questions/51795511/when-is-cglib-proxy-used-by-spring-aop)



获取到代理工具后，进行代理对象的创建：

```java
AbstractAutoProxyCreator#createProxy -> ProxyFactory#getProxy -> 
ProxyCreatorSupport#createAopProxy -> AopProxy#getProxy
```

具体创建不分析了，进入到代理方法的创建上。

#### 增强方法执行流程

在创建代理对象之后，代理对象除了会有原对象的方法，还会包装对应的增强器，以及相关信息。

调用代理对象的方法，并不会立刻执行，而是先进入代理工具的 intercept 方法。执行增强方法的流程又分为两大部分，一是获取到拦截器链，二是对拦截器链进行调用从而达到增强方法的目的。所以就先进入 intercept 方法查看

```java
		@Override
		@Nullable
		public Object intercept(Object proxy, Method method, Object[] args, MethodProxy methodProxy) throws Throwable {
			
			try {
				// 省略一些对变量赋值的逻辑。
                // 1. 这就是第一步，获取拦截器链
				List<Object> chain = this.advised.getInterceptorsAndDynamicInterceptionAdvice(method, targetClass);
				Object retVal;
				// Check whether we only have one InvokerInterceptor: that is,
				// no real advice, but just reflective invocation of the target.
				if (chain.isEmpty() && Modifier.isPublic(method.getModifiers())) {
					// We can skip creating a MethodInvocation: just invoke the target directly.
					// Note that the final invoker must be an InvokerInterceptor, so we know
					// it does nothing but a reflective operation on the target, and no hot
					// swapping or fancy proxying.
                    // 如果没有拦截器，那么就直接调用原来的方法，返回返回值
					Object[] argsToUse = AopProxyUtils.adaptArgumentsIfNecessary(method, args);
					retVal = methodProxy.invoke(target, argsToUse);
				}
				else {
                    // 2. 如果拦截器链不为空，调用拦截器链，以及对应方法
					// We need to create a method invocation...
					retVal = new CglibMethodInvocation(proxy, target, method, args, targetClass, chain, methodProxy).proceed();
				}
				retVal = processReturnType(proxy, target, method, retVal);
				return retVal;
			}
			finally {
				// 释放资源。。。
			}
		}
```



##### 获取拦截器链

根据上述代码，我们首先进入到`advised.getInterceptorsAndDynamicInterceptionAdvice(method, targetClass);`方法，获取拦截器链。

```java
AdvisedSupport#getInterceptorsAndDynamicInterceptionAdvice -> 
DefaultAdvisorChainFactory#getInterceptorsAndDynamicInterceptionAdvice

	@Override
	public List<Object> getInterceptorsAndDynamicInterceptionAdvice(
			Advised config, Method method, @Nullable Class<?> targetClass) {

		// This is somewhat tricky... We have to process introductions first,
		// but we need to preserve order in the ultimate list.
    	// 获取到增强的注册中心
		AdvisorAdapterRegistry registry = GlobalAdvisorAdapterRegistry.getInstance();
    	// 从 config 中获取到增强，也就是声明增强类中的增强
		Advisor[] advisors = config.getAdvisors();
    	// 声明保存将增强转换为拦截器的 list 集合
		List<Object> interceptorList = new ArrayList<>(advisors.length);
    	// 声明代理类类型
		Class<?> actualClass = (targetClass != null ? targetClass : method.getDeclaringClass());
		Boolean hasIntroductions = null;
		// 遍历每个增强
		for (Advisor advisor : advisors) {
            // 如果是切面增强（一般都是这个）
			if (advisor instanceof PointcutAdvisor) {
				// Add it conditionally.
                // 获取到指定的切面（pointCut）
				PointcutAdvisor pointcutAdvisor = (PointcutAdvisor) advisor;
				if (config.isPreFiltered() || pointcutAdvisor.getPointcut().getClassFilter().matches(actualClass)) {
                    // 通过 pointcut 生成对应的匹配器
					MethodMatcher mm = pointcutAdvisor.getPointcut().getMethodMatcher();
					boolean match;
                    // 如果匹配器是需要对方法进行匹配的，就进入下个分支
                    // （其实就是除了 @PointCut 注解，其他的都进入这个分支）
					if (mm instanceof IntroductionAwareMethodMatcher) {
						if (hasIntroductions == null) {
							hasIntroductions = hasMatchingIntroductions(advisors, actualClass);
						}
                        // 拿着方法名和增强的切面进行匹配
						match = ((IntroductionAwareMethodMatcher) mm).matches(method, actualClass, hasIntroductions);
					}
					else {
                        // 如果是 @PointCut，直接进入这个分支，然后返回 true
						match = mm.matches(method, actualClass);
					}
					if (match) {
                        // 如果匹配，说明这个方法就是需要增强的方法，进入到 getInspectors 方法，将增强转换为拦截器
						MethodInterceptor[] interceptors = registry.getInterceptors(advisor);
						if (mm.isRuntime()) {
							// Creating a new object instance in the getInterceptors() method
							// isn't a problem as we normally cache created chains.
							for (MethodInterceptor interceptor : interceptors) {
								interceptorList.add(new InterceptorAndDynamicMethodMatcher(interceptor, mm));
							}
						}
						else {
							interceptorList.addAll(Arrays.asList(interceptors));
						}
					}
				}
			}
			else if (advisor instanceof IntroductionAdvisor) {
				IntroductionAdvisor ia = (IntroductionAdvisor) advisor;
				if (config.isPreFiltered() || ia.getClassFilter().matches(actualClass)) {
					Interceptor[] interceptors = registry.getInterceptors(advisor);
					interceptorList.addAll(Arrays.asList(interceptors));
				}
			}
			else {
				Interceptor[] interceptors = registry.getInterceptors(advisor);
				interceptorList.addAll(Arrays.asList(interceptors));
			}
		}

		return interceptorList;
	}


```

重点关注 `registry.getInterceptors(advisor);`这句代码，它的作用就是将 advisor 转换为 Interceptor ，跟进到里面

```java
	@Override
	public MethodInterceptor[] getInterceptors(Advisor advisor) throws UnknownAdviceTypeException {
		List<MethodInterceptor> interceptors = new ArrayList<>(3);
		Advice advice = advisor.getAdvice();
        // 首先判断是不是方法拦截器，如果是，添加到列表中
		if (advice instanceof MethodInterceptor) {
			interceptors.add((MethodInterceptor) advice);
		}
        // 拿到三个已经装填好的适配器，判断是否需要适配，需要就进行适配，转换成拦截器
		for (AdvisorAdapter adapter : this.adapters) {
			if (adapter.supportsAdvice(advice)) {
				interceptors.add(adapter.getInterceptor(advisor));
			}
		}
		if (interceptors.isEmpty()) {
			throw new UnknownAdviceTypeException(advisor.getAdvice());
		}
		return interceptors.toArray(new MethodInterceptor[0]);
	}

```

综上，一个方法在调用过程中，首先会被拦截，然后查看这个方法中的增强声明。一般有五种增强：@PointCut、@Before、@After、@AfterThrowing、@AfterReturning。第一种是对切面方法的声明，常用于对方法增强前的匹配判断，也就是 match 操作。其他的增强有可能会引用@PointCut 的声明，然后与方法匹配，匹配成功，在进行下一步的增强转为拦截器。

##### 调用拦截器链

创建完成拦截器链后，会执行`retVal = new CglibMethodInvocation(proxy, target, method, args, targetClass, chain, methodProxy).proceed();` 方法，首先创建动态代理的工具类，然后通过工具类调用方法以及相关拦截链，从而实现方法的增强。

直接跟进到到 proceed 方法

```java
CglibAopProxy.CglibMethodInvocation#proceed -> ReflectiveMethodInvocation#proceed
	@Override
	@Nullable
	public Object proceed() throws Throwable {
		// We start with an index of -1 and increment early.
    	// currentInterceptorIndex 默认是 -1，当 size = 0 的时候为 true，执行 invokeJoinpoint 方法，也就是直接调用目标方法。
		if (this.currentInterceptorIndex == this.interceptorsAndDynamicMethodMatchers.size() - 1) {
			return invokeJoinpoint();
		}

		Object interceptorOrInterceptionAdvice =
				this.interceptorsAndDynamicMethodMatchers.get(++this.currentInterceptorIndex);
    	// if 分支基本进入不了，就不进行判断了，主要进入到的是 else 分支
		if (interceptorOrInterceptionAdvice instanceof InterceptorAndDynamicMethodMatcher) {
			
		}
		else {
			// It's an interceptor, so we just invoke it: The pointcut will have
			// been evaluated statically before this object was constructed.
			return ((MethodInterceptor) interceptorOrInterceptionAdvice).invoke(this);
		}
	}


```



![image-20220226174012614](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220226174012614.png)

这个是根据拦截器链拦截调用的方法栈。在进入 ReflectiveMethodInvocation#proceed 方法后，利用递归的方式，进入到每个拦截器中调用他们的拦截方法 invoke。一步一步跟进

首先进入的是 ExposeInvocationInterceptor#invoke 方法，也就是拦截器链中的第一个拦截器。

```java
	@Override
	public Object invoke(MethodInvocation mi) throws Throwable {
        // 从本地线程中获取副本，然后把传入的 invocation（就是调用proceed 方法的动态代理工具对象） 设置到本地线程中。
		MethodInvocation oldInvocation = invocation.get();
		invocation.set(mi);
		try {
            // 然后再递归调用 proceed 方法
			return mi.proceed();
		}
		finally {
			invocation.set(oldInvocation);
		}
	}
```

proceed 对 index 做了++操作，继续进入下一个拦截器（AspectJAfterThrowingAdvice）的 invoke 方法中

```java
AspectJAfterThrowingAdvice#invoke
    
	@Override
	public Object invoke(MethodInvocation mi) throws Throwable {
		try {
            // 继续调用 proceed 方法，重新进入 ReflectiveMethodInvocation#proceed
			return mi.proceed();
		}
		catch (Throwable ex) {
			if (shouldInvokeOnThrowing(ex)) {
				invokeAdviceMethod(getJoinPointMatch(), null, ex);
			}
			throw ex;
		}
	}

```

这时候应该就能看出一点端倪了，我们通过递归，依次调用拦截链中的拦截器，拦截器会根据自身定义逻辑执行方法，接下来全部放出剩下的拦截器

```java

	AfterReturningAdviceInterceptor#invoke
	@Override
	public Object invoke(MethodInvocation mi) throws Throwable {
		Object retVal = mi.proceed();
        // 在调用完毕后，调用 afterReturning 方法，如果出现异常，则直接抛出，进入到 AspectJAfterThrowingAdvice#invoke 中，执行异常处理
		this.advice.afterReturning(retVal, mi.getMethod(), mi.getArguments(), mi.getThis());
		return retVal;
	}

    AspectJAfterAdvice#invoke
	@Override
	public Object invoke(MethodInvocation mi) throws Throwable {
		try {
            // 调用 before 的方法
			return mi.proceed();
		}
		finally {
            // 在before 之后，调用 After 的方法
			invokeAdviceMethod(getJoinPointMatch(), null, null);
		}
	}

	MethodBeforeAdviceInterceptor#invoke
	@Override
	public Object invoke(MethodInvocation mi) throws Throwable {
        // 调用 before 方法
		this.advice.before(mi.getMethod(), mi.getArguments(), mi.getThis());
        // 再次调用Invocation 方法，由于 index==4，所以需要调用目标方法
		return mi.proceed();
	}

	// before 方法会调用目标方法声明的 @Before 方法
	@Override
	public void before(Method method, Object[] args, @Nullable Object target) throws Throwable {
		invokeAdviceMethod(getJoinPointMatch(), null, null);
	}

```

以下就是大体的调用逻辑，每个拦截器类的具体拦截方法的实现就没特殊标明

![image-20220226181400900](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220226181400900.png)

#### AOP 调用流程总结

![ ](https://raw.githubusercontent.com/Bogdanxin/cloudImage/master/image-20220227124025588.png)

## Spring 事务的执行过程



## Spring 容器创建



## Spring 拓展

下面这些都比较简单，所以分析流程就不会特别细致，可以通过 debug 看懂

### BeanFactoryPostProcessor

#### 与BeanPostProcessor 不同之处

- BeanPostProcessor 是 bean 的后置处理器，bean 创建对象初始化前后进行拦截工作
- BeanFactoryPostProcessor 是 BeanFactory 的后置处理器，在 BeanFactory 标准初始化后调用，所有的 bean 定义信息已经加载到 beanFactory，但是还未创建实例

#### 调用流程

1. 在 refresh 方法的invokeBeanFactoryPostProcessors() 调用，所以说优先于其他的 BeanPostProcessor 和自定义 bean
2. 对所有 BeanFactoryPostProcessor 进行排序，然后依次调用他们的 postProcessBeanFactory

### BeanDefinitionRegistryPostProcessor

#### 与 BeanFactoryPostProcessor 关系

BeanDefinitionRegistryPostProcessor是 BeanFactoryPostProcessor的子接口

- BeanDefinitionRegistryPostProcessor 是 bean定义信息后置处理器，在 bean 定义信息将要加载到容器之前执行拦截工作。
- 所以说，BeanDefinitionRegistryPostProcessor 执行顺序还要优先于BeanFactoryPostProcessor，可以利用它向容器中添加新的 bean 定义信息

#### 源码调用流程分析

1. refresh 方法中调用` invokeBeanFactoryPostProcessors() `方法
2. 先调用 BeanDefinitionRegistryPostProcessor 实现类的 `postProcessBeanDefinitionRegistry` 方法
- 然后调用 BeanDefinitionRegistryPostProcessor 继承了 BeanFactoryPostProcessor 的 `postProcessBeanFactory` 方法
- 最后单独从容器中找只实现了 BeanFactoryPostProcessor 的类，调用 `postProcessBeanFactory` 方法

### ApplicationListener

常用于 Spring 发布事件

#### 使用方法

1. 需要自行声明一个 ApplicationListener 接口的类，重写 onApplication 方法，这个方法会在接收到事件后被驱动从而被执行。默认 Spring 容器启动和关闭都会发布事件
2. 如果需要自行发布，可以通过容器的 publishEvent 方法发布事件
3. `@EventListener` 自定义监听事件，可以确定监听事件的类型，以及相关的逻辑

#### 源码分析

##### 发布事件

1. `refresh` 方法中调用 `publishEvent` 方法发布实例初始化完毕的事件；
2. 自行调用 context 的 `publishEvent` 方法，发布自定义事件；
3. 容器关闭调用 `close` 方法，也会向 listener 发布容器关闭的事件

具体实现：`publishEvent` 方法中拿到事件多播器，调用`multicastEvent` 方法，向容器中的 listener 发送事件，调用 ApplicationListener 的重写方法（此时就是对事件的监听了）

在向listener 发送事件时，多播器如果有线程池，可以将任务给线程池，线程池异步发送事件。

##### 事件多播器的初始化

 - `refresh` 方法中的 `initApplicationEventMulticaster(); `
    方法会初始化多播器
 - 如果容器中有自定义的事件多播器实例，则取出实例，并注册到 ApplicationContext 中
- 如果没有，则自行创建SimpleApplicationEventMulticaster 实例，注册到 ApplicationContext 中

##### 事件监听器的初始化

 - refresh 方法中的调用 `registerListeners()`; 会初始化所有的 listener

    - 从容器中取出所有的 listener bean，然后将 listener 注册到多播器中，这样多播器一旦需要发布事件，可以直接向 listener 发布
    - 如果有 early event 会在此时就进行发布

##### 使用 @EventListener 的源码

在@EventListener 中，指定了EventListenerMethodProcessor类。

这个类实现了 SmartInitializingSingleton，BeanFactoryPostProcessor 两个接口

 - `BeanFactoryPostProcessor` 在 bean 定义信息创建完毕后调用重写方法，
    在EventListenerMethodProcessor中收集到所有 EventListenerFactory 类的定义信息，其中就包含 @EventListener 的注解方法，这样就能使得注解监听方法注册到容器中被调用。
 - `SmartInitializingSingleton` 接口作用在创建单实例 bean 完成后，因为此时没有其他 bean 需要创建。就可以进行 listener 的创建，并添加到 springcontext 中

### SmartInitializingSingleton 接口

具体调用分析：

- refresh 方法中调用 finishBeanFactoryInitialization，在所有 bean 完成初始化后调用它的方法
 - 在 beanFactory.preInstantiateSingletons(); 中，获取到所有需要被创建的 bean 名称，然后依次getBean，如果没有就创建。在所有 bean 创建完毕后，再判断每个 bean 是否是SmartInitializingSingleton实现类，如果是就调用接口方法

