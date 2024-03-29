---
layout: post
title: "Running a Spring Boot application on JBoss 7.1.1"
categories: articles
tags: [java, jboss, spring]
comments: true
date: 2015-03-03T20:38:24+03:00
---

Background
----------

<!-- TEASER START -->

One of the projects which I was developing used the [Spring Boot](http://projects.spring.io/spring-boot/) for configuration, assembling, testing and property managing. Everything was pretty great, we were completely satisfied with Spring Boot and our application ran without any problems on Tomcat 7. But when this project was coming to the end, it turned out that we will have JBoss instead of Tomcat in production. It should not have caused any troubles for us, but we ended up spending lots of time on this migration. And here is one of the reasons why this happened.

<!-- TEASER STOP -->

Of course, I can't share the source code of our project, so I created a little example that reveals the underlying problem.

The problem
-----------

Let's take a look at a typical Spring Boot web application. Say we have only a controller, a filter and some component which is autowired into the filter (hereinafter imports omitted for brevity):

``` java
@RestController
public class HelloController {
    @RequestMapping("/")
    public String index() {
        return "Greetings from Spring Boot!";
    }
}
```

``` java
@Component
public class HelloComponent {
    public void go() {
        System.out.println("Inside filter's component");
    }
}
```

``` java
@Component
public class HelloFilter extends GenericFilterBean {
    @Autowired
    private HelloComponent component;

    @Override
    public void doFilter(ServletRequest servletRequest, ServletResponse servletResponse,
                         FilterChain filterChain) throws IOException, ServletException {
        component.go();
        filterChain.doFilter(servletRequest, servletResponse);
    }
}
```

The main Application class:

``` java
@SpringBootApplication
public class Application extends SpringBootServletInitializer {
    public static void main(String[] args) {
        SpringApplication.run(Application.class);
    }

    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder application) {
        return application.sources(Application.class);
    }
}
```

You can see the entire project [here](https://github.com/ilya-murzinov/spring-boot-jboss/tree/master/spring-boot-jboss-initial).

Ok, let's build it and run on Tomcat 7:

``` bash
$ mvn clean install
$ cp ./spring-boot-jboss-initial/target/spring-boot-jboss-initial-1.0-SNAPSHOT.war ~/apache-tomcat-7.0.57/webapps/boot.war
$ ~/apache-tomcat-7.0.57/bin/startup.sh
```

And it works just fine:

``` bash
$ curl http://localhost:8080/boot
Greetings from Spring Boot!
```

Now we deploy it on JBoss-7.1.1 (do not forget to stop Tomcat) and expect it to work fine as well:

``` bash
$ cp ./spring-boot-jboss-initial/target/spring-boot-jboss-initial-1.0-SNAPSHOT.war ~/jboss-7.1.1-Final/standalone/deployments/boot.war
$ ~/jboss-7.1.1-Final/bin/standalone.sh
```

But here comes the big problem:

``` bash
$ curl http://localhost:8080/boot
<html><head><title>JBoss Web/7.0.13.Final - Error report</title></head>
<body><h1>HTTP Status 500 - The server encountered an internal error () that prevented it from fulfilling this request.
<pre>java.lang.NullPointerException
com.github.ilyamurzinov.springbootjboss.HelloFilter.doFilter(HelloFilter.java:29)
org.springframework.web.filter.CharacterEncodingFilter.doFilterInternal(CharacterEncodingFilter.java:88)
org.springframework.web.filter.OncePerRequestFilter.doFilter(OncePerRequestFilter.java:107)
org.springframework.boot.context.web.ErrorPageFilter.doFilter(ErrorPageFilter.java:108)
org.springframework.boot.context.web.ErrorPageFilter.access$000(ErrorPageFilter.java:59)
org.springframework.boot.context.web.ErrorPageFilter$1.doFilterInternal(ErrorPageFilter.java:88)
org.springframework.web.filter.OncePerRequestFilter.doFilter(OncePerRequestFilter.java:107)
org.springframework.boot.context.web.ErrorPageFilter.doFilter(ErrorPageFilter.java:101)
</pre>
</body></html>
```

What happened?

Analysis
--------

Line 29 (== line 9 in the above snippet) of *HelloFilter* is where *HelloComponent*'s method *go()* is called. It's quite obvious that *HelloComponent* did not get autowired into the *HelloFilter* and thus *component == null*. This kind of situation commonly occures when some Spring's component gets instantiated not by Spring.

And that's exactly what happens here. By adding a breakpoint to the *HelloComponent*'s constructor, we find out that *HelloComponent* gets instantiated two times: first time by Spring and the second time by JBoss. And when JBoss registers filters it takes *HelloComponent*'s instance that it created instead of the one created by Spring.

JBoss uses *Apache Catalina* inside, but a modified version, and it causes all the problems. Let's take a look at *org.apache.catalina.core.StandardContext* from *org.jboss.web:jbossweb:7.0.13.Final*:

``` java
protected boolean filterStart() {
        if (getLogger().isDebugEnabled())
            getLogger().debug("Starting filters");
        // Instantiate and record a FilterConfig for each defined filter
        boolean ok = true;
        Iterator<ApplicationFilterConfig> filterConfigsIterator = 
            filterConfigs.values().iterator();
        while (filterConfigsIterator.hasNext()) {
            ApplicationFilterConfig filterConfig = filterConfigsIterator.next();
            try {
                filterConfig.getFilter();
            } catch (Throwable t) {
                getLogger().error
                (sm.getString("standardContext.filterStart", name), t);
                ok = false;
            }
        }
        Iterator<String> names = filterDefs.keySet().iterator();
        while (names.hasNext()) {
            String name = names.next();
            if (getLogger().isDebugEnabled())
                getLogger().debug(" Starting filter '" + name + "'");
            ApplicationFilterConfig filterConfig = null;
            try {
                filterConfig = new ApplicationFilterConfig
                (this, (FilterDef) filterDefs.get(name));
                filterConfig.getFilter();
                filterConfigs.put(name, filterConfig);
            } catch (Throwable t) {
                getLogger().error
                (sm.getString("standardContext.filterStart", name), t);
                ok = false;
            }
        }
        return (ok);
    }
```

This class has two fields - *filterConfigs* and *filterDefs*, by the time it enters this method, the *filterConfigs* contains filters created by Spring, and the *filterDefs* contains only names and class names of those filters. The first loop, starting at line 8 gets correct filters from *filterConfigs* and registers them. But then the second loop, starting at line 19 instantiates filters again and then registers them with the same filterNames. Thus, correct filters get overwritten.

Solution
--------

The idea is to disable the filter after Spring has created it (so JBoss wouldn't register it) and then create a proxy that delegate calls to the filter taken from Spring context. I used *FilterRegistrationBean* and *BeanPostProcessor* to disable the filter.

``` xml
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans
	http://www.springframework.org/schema/beans/spring-beans.xsd">
    <bean id="helloFilter" 
          class="com.github.ilyamurzinov.springbootjboss.HelloFilter"/>
    <bean id="helloFilterRegistrationBean" 
	  class="org.springframework.boot.context.embedded.FilterRegistrationBean">
        <property name="filter" ref="helloFilter"/>
        <property name="enabled" value="true" />
    </bean>
</beans>
```

``` java
@Component
public class JBossProxyInitializer implements BeanFactoryPostProcessor {

    @Override
    public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
        // Disabling filters created by Spring so JBoss wouldn't register them as well
        for (String name : beanFactory.getBeanDefinitionNames()) {
            if (!name.contains("FilterRegistrationBean")) {
                continue;
            }
            BeanDefinition definition = beanFactory.getBeanDefinition(name);
            definition.getPropertyValues().add("enabled", false);
        }

        FilterRegistrationBean filterRegistrationBean = new FilterRegistrationBean();
        filterRegistrationBean.setFilter(new Application.HelloFilterProxy());
        filterRegistrationBean.setUrlPatterns(Collections.singletonList("/*"));

        beanFactory.registerSingleton("helloFilterProxyFilterRegistrationBean", filterRegistrationBean);
    }
}
```

``` java
@SpringBootApplication
@ImportResource("classpath:context.xml")
public class Application extends SpringBootServletInitializer {

    private volatile static WebApplicationContext webApplicationContext;

    @Override
    protected WebApplicationContext createRootApplicationContext(ServletContext servletContext) {
        webApplicationContext = super.createRootApplicationContext(servletContext);
        return webApplicationContext;
    }

    @Override
    protected SpringApplicationBuilder configure(SpringApplicationBuilder builder) {
        return builder.sources(Application.class, JBossProxyInitializer.class);
    }

    public static void main(String[] args) {
        SpringApplication.run(Application.class);
    }

    public static class HelloFilterProxy extends DelegatingFilterProxy {
        @Override
        protected Filter initDelegate(WebApplicationContext wac) throws ServletException {
            return Application.webApplicationContext.getBean(HelloFilter.class);
        }
    }
```

If you need to use more filters you should use (if not using already) *org.springframework.web.filter.CompositeFilter*.

Now we have our filter instantiated and registered correctly, let's test it:

``` bash
$ curl http://localhost:8080/boot
<html><head><title>JBoss Web/7.0.13.Final - Error report</title>
</head><body><h1>HTTP Status 404 - /boot/</h1>
<p><b>type</b> Status report</p><p>
<b>message</b> <u>/boot/</u></p><p><b>description</b> 
<u>The requested resource (/boot/) is not available.</u></p>
<h3>JBoss Web/7.0.13.Final</h3></body></html>
```

That's definitely better than NPE, but still not what we expected. Why did that happen?

Appears that JBoss treats servlets just like filters and thus Spring's *DispatcherServlet* does not get instantiated properly. So we need to add a proxy for this servlet to *JBossProxyInitializer* as well:

``` java
@SpringBootApplication
@ImportResource("classpath:context.xml")
public class Application extends SpringBootServletInitializer {
    /* ... */

    public static class DispatcherServletProxy implements Servlet {

        private Servlet delegate;

        @Override
        public void init(ServletConfig config) throws ServletException {
            delegate = Application.webApplicationContext.getBean(DispatcherServlet.class);
            delegate.init(config);
        }

        @Override
        public ServletConfig getServletConfig() {
            return delegate.getServletConfig();
        }

        @Override
        public void service(ServletRequest req, ServletResponse res) throws ServletException, IOException {
            delegate.service(req, res);
        }

        @Override
        public String getServletInfo() {
            return delegate.getServletInfo();
        }

        @Override
        public void destroy() {
            delegate.destroy();
        }
    }
}
```

``` java
@Component
public class JBossProxyInitializer implements BeanFactoryPostProcessor {

    @Override
    public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
        /* ... */

        ServletRegistrationBean servletRegistrationBean = new ServletRegistrationBean();
        servletRegistrationBean.setServlet(new Application.DispatcherServletProxy());
        servletRegistrationBean.setUrlMappings(Collections.singletonList("/*"));

        beanFactory.registerSingleton("dispatcherServletProxyRegistrationBean", servletRegistrationBean);
    }
}
```

And finally:

``` bash
$ cp ./spring-boot-jboss-final/target/spring-boot-jboss-final-1.0-SNAPSHOT.war ~/jboss-7.1.1-Final/standalone/deployments/boot.war
$ ~/jboss-7.1.1-Final/bin/standalone.sh
$ curl http://localhost:8080/boot
Greetings from Spring Boot!
```

Conclusion
----------

Although, the strange JBoss's behaviour still remains a mystery to me, the workaround described above lets an application run normally on this application server. The only drawback of this solution (except it being an ugly hack :) ) is that it doesn't scale when it comes to servlets. This means that you *have* to create a proxy for every servlet in your application.

Any questions are welcome in comments.
