---
layout: post
title: "Introducing Allure in C# project"
modified:
categories: articles
excerpt:
image:
  feature:
tags: [c#, testing, allure]
comments: true
date: 2015-02-25T20:38:24+03:00
---

####Background
About a year ago I worked as a QA automation engineer and, of course, had to deal with lots of test reports. In our company we had both unit- and UI-tests and used MS Test + Team Foundation Server + Microsoft Test Manager 2012 to run our automated tests, collect and view all the reports. But this solution had too many disadvantages for me:

 - It's **expensive** (meaning not free :) )
 - Reports are hard to read and analyse
 - There is no (easy) way to attach anything to test report
 - I personally liked NUnit more than MS Test.

And then I discovered [Allure Framework](http://allure.qatools.ru) - open-source tool which was developed by Yandex test team and it provides really great reports. You can browse their site, or watch [sample report](http://teamcity.qatools.ru/repository/download/allure_core_master_release/lastSuccessful/index.html?guest=1#/home) to convince youself that it's a very good. Allure consists of 2 important parts - adapter and generator. Adapter produces XML files in specific format for generator to generate the final report.

Unfortunately, by the time I found Allure, there was no way to use it in C# project, because there was no adapter for C#. So if I wanted to use Allure, I had to develop a little addon for testing framework (MS Test or NUnit) which would generate XML report.

But that was not a problem for me, I'm an open-source guy, so I quickly decided to develop adapter myself. Long story short, this is the result: [core library](https://github.com/allure-framework/allure-csharp-commons) for .NET and [adapter](https://github.com/allure-framework/allure-nunit) for NUnit 2. Core library is reusable which makes possible to develop adapters for any .NET testing framework. For example, [@someuser77](https://github.com/someuser77) has developed [adapter](https://github.com/allure-framework/allure-mstest-adapter) for MS Test.

**Disclaimer:** although core library (allure-csharp-commons) is well developed and tested, adapted itself (allure-nunit) may contain some bugs. In case of any troubles, you are welcome to raise an issue in  [bug tracker](https://github.com/allure-framework/allure-nunit/issues). Pull-requests are of course also welcomed.

Ok, so we are good to go.

####Getting work done

End-to-end configuration is pretty tricky, but it can be simplified in the future by using plugins for TeamCity or Jenkins. The result will be *.bat-script you can use to run tests and generate report as a build step in you build server. I will describe this process for NUnit because I was personally using it. But it should be pretty much the same for MS Test.

So what exactly do we need?

 1. NUnit 2.6.3
 1. [Latest release](https://github.com/allure-framework/allure-nunit/releases) of allure-nunit
 1. [JRE](http://www.oracle.com/technetwork/java/javase/downloads/index.html) for allure-cli
 1. [Latest release](https://github.com/allure-framework/allure-cli/releases) of allure-cli
 1. Web-server, for example [Nginx](http://nginx.org/)
 1. Built \*.dll assemblies with tests

First of all, we need to install NUnit, allure-cli, JRE, Nginx and set environmental variables, for example (replace these values with yours):

{% highlight bat %}
set ASSEMBLIES_DIR=C:\project\bin\debug
set NUNIT_HOME = C:\NUnit-2.6.3
set ALLURE_CLI_HOME = C:\allure-cli
set JAVA_HOME = C:\Program Files\Java\jre-1.7.0_75
set NGINX_HOME=C:\nginx-1.7.0
{% endhighlight %}

Next, we need to install nunit-adapter and configure it. Here are the steps to do it:

 1. Unpack allure-nunit binaries to %NUNIT_HOME%\bin\addins
 1. Addin will NOT be visible in Tools -> Addins.. because it's built against .NET 4.0
 1. In %NUNIT_HOME%\bin\addins\config.xml specify absolute path to any folder (this folder will be created automatically) where XML files will be generated (for example &lt;results-path>C:\test-results\AllureResults&lt;/results-path>)
 1. You can also specify in configuration whether you want to take screenshots after failed tests and whether you want to have test output to be written to attachments

After that we need to add new environmental variable OUTPUT_FOLDER pointing to the folder we specified in adapter's config.xml:

{% highlight bat %}
set OUTPUT_DIR=C:\test-results\AllureResults
{% endhighlight %}

After we set all variables comes the easy part - running tests and generating report. I'll just provide the resulting *.bat-script, it's self-explanatory:

{% highlight bat %}
set ASSEMBLIES_DIR=C:\project\bin\debug
set NUNIT_HOME=C:\NUnit-2.6.3
set ALLURE_CLI_HOME=C:\allure-cli\allure-cli.jar
set JAVA_HOME=C:\Program Files\Java\jre-1.7.0_75
set OUTPUT_DIR=C:\test-results\AllureResults
set NGINX_HOME=C:\nginx-1.7.0

%NUNIT_HOME%\bin\nunit-console.exe %ASSEMBLIES_DIR%\YourAssembly.dll /framework=net-4.0
%JAVA_HOME%\bin\java -jar %ALLURE_CLI_HOME%\allure-cli.jar generate -v 1.4.0 %OUTPUT_DIR% -o %NGINX_HOME%\html\
{% endhighlight %}

You can run as much \*.dll's as you want or create an \*.nuproj project cointaining all assemblies.

Now we need to start Nginx and thats all! If you've done it right, you will see the report at [http://localhost:8080](http://localhost:8080) (depends on Nginx configuration).

Note that this is only the basic configuration and it can of course be extended/modified.

####Problems
There is one [big issue](https://github.com/allure-framework/allure-csharp-commons/issues/3) with allure-csharp-commons, specifically, handling some custom attributes like Attachment, Step. We even have a [pull-request](https://github.com/allure-framework/allure-csharp-commons/pull/15) for this issue, but it's quite complicated and I personally have no time to dig into it.

If you have any questions, you are welcome to ask it in comments.
