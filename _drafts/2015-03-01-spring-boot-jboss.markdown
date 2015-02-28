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

But here comes the big BOOM:

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

{% highlight java %}
{% endhighlight %}

{% highlight java %}
{% endhighlight %}

{% highlight java %}
{% endhighlight %}