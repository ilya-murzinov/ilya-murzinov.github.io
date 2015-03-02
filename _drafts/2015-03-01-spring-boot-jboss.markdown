---
layout: post
title: "Running Spring Boot application on JBoss 7.1.1"
modified:
categories: article
excerpt:
image:
  feature:
tags: [java, jboss, spring]
comments: true
date: 2015-03-01T20:38:24+03:00
---

####Background

One of the projects which I was developing used Spring Boot for configuration, assembling, testing and property managing. Everything was pretty great, we were completely satisfied with Spring Boot and our application ran without any peoblems on Tomcat. But when this project was close to the end, it turned out that we will have JBoss instead of Tomcat in production. It should not have caused any troubles for us, but we ended up spending lots of time on this migration. And here is one of the reasons why this happend.

Of course, I can't share the source code of our project, so I created a little example that reveals the underlying problem.

####The problem
Let's take a look at typical Spring Boot web application. Say we have a only a controller, a filter and some component which is autowired into the filter (imports omitted for brevity):

{% highlight java %}
@RestController
public class HelloController {
    @RequestMapping("/")
    public String index() {
        return "Greetings from Spring Boot!";
    }
}
{% endhighlight %}

{% highlight java %}
@Component
public class HelloComponent {
    public void go() {
        System.out.println("Inside filter's component");
    }
}
{% endhighlight %}

{% highlight java %}
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
{% endhighlight %}

The main Application class:

{% highlight java %}
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
{% endhighlight %}

You can see the whole project with pom.xml [here](https://github.com/ilya-murzinov/spring-boot-jboss/tree/master/spring-boot-jboss-initial).

Ok, now let's build it and run on Tomcat 7:

{% highlight bash %}
$ mvn clean install
$ cp ./spring-boot-jboss-initial/target/spring-boot-jboss-initial-1.0-SNAPSHOT.war ~/apache-tomcat-7.0.57/webapps/boot.war
$ ~/apache-tomcat-7.0.57/bin/startup.sh
{% endhighlight %}

And it works just fine:

{% highlight bash %}
$ curl http://localhost:8080/boot
Greetings from Spring Boot!
{% endhighlight %}

Now we deploy it on JBoss-7.1.1 (do not forget to stop Tomcat) and expect it to work just fine:

{% highlight bash %}
$ cp ./spring-boot-jboss-initial/target/spring-boot-jboss-initial-1.0-SNAPSHOT.war ~/jboss-7.1.1-Final/standalone/deployments/boot.war
$ ~/jboss-7.1.1-Final/bin/standalone.sh
{% endhighlight %}

But here comes the big problem:

{% highlight bash %}
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
{% endhighlight %}

####Analysis

Line 29 is where *HelloComponent*'s method *go()* is called. It's quite obvious that *HelloComponent* did not get autowired into the *HelloFilter* and thus *component == null*. This kind of situation commonly occurres when some some Spring's component is not by Spring.

And that's exactly what happens here. By adding a breakepoint to the *HelloComponent*'s constructor, we find out that *HelloComponent* gets instantiated two times: first time by Spring and the second time by JBoss. And when JBoss registers filters it takes *HelloComponent*'s instance that it created instead of the one created by Spring.

JBoss uses *Apache Catalina* inside, but a modified version, and it causes all the problems. Let's tale a look at *org.apache.catalina.core.StandardContext* in both Tomcat and JBoss.

StandardContext inside org.jboss.web:jbossweb:7.0.13.Final

{% highlight java %}
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
{% endhighlight %}

StandardContext inside org.apache.tomcat.embed:tomcat-embed-core:7.0.57

{% highlight java %}
public boolean filterStart() {
        if (getLogger().isDebugEnabled())
            getLogger().debug("Starting filters");
        // Instantiate and record a FilterConfig for each defined filter
        boolean ok = true;
        synchronized (filterConfigs) {
            filterConfigs.clear();
            Iterator<String> names = filterDefs.keySet().iterator();
            while (names.hasNext()) {
                String name = names.next();
                if (getLogger().isDebugEnabled())
                    getLogger().debug(" Starting filter '" + name + "'");
                ApplicationFilterConfig filterConfig = null;
                try {
                    filterConfig =
                        new ApplicationFilterConfig(this, filterDefs.get(name));
                    filterConfigs.put(name, filterConfig);
                } catch (Throwable t) {
                    t = ExceptionUtils.unwrapInvocationTargetException(t);
                    ExceptionUtils.handleThrowable(t);
                    getLogger().error
                        (sm.getString("standardContext.filterStart", name), t);
                    ok = false;
                }
            }
        }
        return (ok);
    }
{% endhighlight %}

####Solution

**Disclaimer:** I'm aware that this is kind of ugly workaround, but it's the only way we managed to get our application work.

The idea is to disable filter after Spring has created it (so JBoss wouldn't register it) and then create a proxy that delegate calls to the filter taken from Spring context. We will use *FilterRegistrationBean* and *BeanPostProcessor* to disable filter.

{% highlight xml %}
<?xml version="1.0" encoding="UTF-8"?>
<beans xmlns="http://www.springframework.org/schema/beans"
       xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance"
       xsi:schemaLocation="http://www.springframework.org/schema/beans
	   					   http://www.springframework.org/schema/beans/spring-beans.xsd">
    <bean id="helloFilter" class="com.github.ilyamurzinov.springbootjboss.HelloFilter"/>
    <bean id="helloFilterRegistrationBean" class="org.springframework.boot.context.embedded.FilterRegistrationBean">
        <property name="filter" ref="helloFilter"/>
        <property name="enabled" value="true" />
    </bean>
</beans>
{% endhighlight %}

{% highlight java %}
@Component
public class JBossProxyInitializer implements BeanFactoryPostProcessor {
    @Override
    public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
        //Disabling filters created by Spring so JBoss wouldn't register them as well
        for (String name : beanFactory.getBeanDefinitionNames()) {
            if (!name.contains("FilterRegistrationBean")) {
                continue;
            }
            BeanDefinition definition = beanFactory.getBeanDefinition(name);
            definition.getPropertyValues().add("enabled", false);
        }

        FilterRegistrationBean filterRegistrationBean = new FilterRegistrationBean();
        filterRegistrationBean.setFilter(new HelloFilterProxy());
        filterRegistrationBean.setUrlPatterns(Collections.singletonList("/*"));
    }

    public static class HelloFilterProxy extends DelegatingFilterProxy {
        @Override
        protected Filter initDelegate(WebApplicationContext wac) throws ServletException {
            return Application.webApplicationContext.getBean(HelloFilter.class);
        }
    }
}
{% endhighlight %}

{% highlight java %}
@SpringBootApplication
@ImportResource("classpath:context.xml")
public class Application extends SpringBootServletInitializer {

    public volatile static WebApplicationContext webApplicationContext;

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
}
{% endhighlight %}

This should do the job, so now we have our filter instantiated and registered correclty, let's test it:

{% highlight bash %}
$ curl http://localhost:8080/boot
<html><head><title>JBoss Web/7.0.13.Final - Error report</title>
</head><body><h1>HTTP Status 404 - /boot/</h1>
<p><b>type</b> Status report</p><p><b>message</b> <u>/boot/</u></p><p><b>description</b> 
<u>The requested resource (/boot/) is not available.</u></p><h3>JBoss Web/7.0.13.Final</h3></body></html>
{% endhighlight %}

That's definitely better than NPE, but still not what we expected. Why did that happen?

Long story short, it turns out that JBoss treats servlets just like filters and thus Spring's *DispatcherServlet* does not get instantiated properly. So we need to add a proxy for this servlet to *JBossProxyInitializer* as well:

{% highlight java %}
public void postProcessBeanFactory(ConfigurableListableBeanFactory beanFactory) throws BeansException {
	//...
	
	ServletRegistrationBean servletRegistrationBean = new ServletRegistrationBean();
	servletRegistrationBean.setServlet(new DispatcherServletProxy());
	servletRegistrationBean.setUrlMappings(Collections.singletonList("/*"));

	beanFactory.registerSingleton("dispatcherServletProxyRegistrationBean", servletRegistrationBean);
}

//...

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
{% endhighlight %}

And finally:

{% highlight bash %}
$ curl http://localhost:8080/boot
Greetings from Spring Boot!
{% endhighlight %}

Any questions are welcome in comments.

{% highlight java %}
{% endhighlight %}

{% highlight java %}
{% endhighlight %}
