---
layout: post
title: "Shortest Coursera Course Ever"
date: 2015-03-18T06:16:29+00:00
categories: blog
tags: [ruby, rails, coursera]
comments: on
---

I've just finished [Web Applications Architectures](https://www.coursera.org/course/webapplications) course by *Greg Heileman*, 
*University of New Mexico*. It took only 2 evenings (~ 10 hours) to complete this course with the **100% grade**. Grades are, of course, not yet avaliable, but I've got 100% in every assignment and quiz, so it's not hard to do the math.

As an overview of this course, I can say that though it's designed for beginners without any development experience, lectures are quite confusing. Lots of low-level stuff get mixed with high-level stuff in a way that doesn't help to understang what's going on in the Rails application.

Quizzes of this course are not challenging at all, they do not cover even a half of lectures material, but sometimes include something that was not in lectures. And programming assignments are just running some Rails commands and then rewriting the code from the screen.

After all, the last programming assignment contains an egregious example of a very bad code:

``` javascript
var new_comment = $("<%= escape_javascript(render(:partial => @comment)) %>");
new_comment.hide();
$('#comments').prepend(new_comment);
$('#comment_<%= @comment.id %>').fadeIn('slow');
$('#new_comment')[0].reset();
```

That's just how you should NOT write your code.

In addition, the course is full of typos and inaccuracies.

In conclusion, I would not recomend this course to the beginners, though can be useful for the web developers who want to learn some *Ruby on Rails* as well as web application basics. But if you are only interested in *Ruby on Rails*, you might want to take a look at [Rails for Zombies](http://railsforzombies.org/) after (or instead of) this course.
