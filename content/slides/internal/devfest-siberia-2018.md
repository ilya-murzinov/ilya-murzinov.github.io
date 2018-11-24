---
title: Beyond the Future with purely functional Scala
layout: true
---

class: center, middle

# $title$

### Ilya Murzinov

<i class="fab fa-twitter" style="color: #00aced"></i> [ilyamurzinov](https://twitter.com/ilyamurzinov)

<i class="fab fa-github"></i> [ilya-murzinov](https://github.com/ilya-murzinov)

<i class="fab fa-telegram" style="color: #0088cc"></i> [ilyamurzinov](https://t.me/ilyamurzinov)

---

class: middle, center

<img src="/images/Revolut.png" style="max-width:100%;"/>

---

layout: true
<div class="my-footer"><span><a href="slides/devfest-siberia-2018.pdf">$root$/slides/devfest-siberia-2018.pdf</a></span></div>

---

# Referential transparency

```scala
def goodFunction() = 2 + 2
```
--

```scala
val v1 = goodFunction() + goodFunction()

val goodResult = goodFunction()
val v2 = goodResult + goodResult
```
--

```scala
v1 == v2 // true
```

---

# Referential transparency

```scala
def badFunction() = {
  sendMessage()
  2 + 2
}
```
--

```scala
val v3 = badFunction() + badFunction()

val badResult = badFunction()
val v4 = badResult + badResult
```
--

```scala
v3 == v4 // true
```

---

# Simple example

```scala
def extract(): Seq[String] = ???
def transform(strings: Seq[String]): Seq[WTF] = ???
def load(wtfs: Seq[WTF]): Unit = ???
```
--

```scala
def etl(): Unit = {
  val strings = extract()
  val wtfs = transform(strings)
  load(wtfs)
}
```

---

# Simple example

```scala
def extract(): Seq[String] = ???
def transform(strings: Seq[String]): Seq[WTF] = ???
def load(wtfs: Seq[WTF]): Unit = ???
```

```scala
def etl(): Unit = {
  val strings = extract()       // <- IO-bound
  val wtfs = transform(strings) // <- CPU-bound
  load(wtfs)                    // <- IO-bound
}
```
???

---

class: middle, center

# Can we do better?

---

class: middle, center

# Yes we can!

---

# Future FTW

```scala
import scala.concurrent.Future

val extractF: Future[Seq[String]] = ???
val transformF: Seq[String] => Future[Seq[WTF]] = ???
val loadF: Seq[WTF] => Future[Unit] = ???
```
--

```scala
val etlF: Future[Unit] = for {
  strings <- extractF
  wtfs <- transformF(strings)
  _ <- loadF(wtfs)
} yield ()
```
--

```
> sbt compile
```

---

# Oops!

```
[error] Main.scala:30:5: Cannot find an implicit ExecutionContext. 
[error] You might pass
[error] an (implicit ec: ExecutionContext) parameter to your method
[error] or import scala.concurrent.ExecutionContext.Implicits.global.
[error]   _ <- loadF(wtfs)
[error]     ^
[error] Main.scala:29:8: Cannot find an implicit ExecutionContext
[error] You might pass
[error] an (implicit ec: ExecutionContext) parameter to your method
[error] or import scala.concurrent.ExecutionContext.Implicits.global.
[error]   wtfs <- transformF(strings)
[error]        ^
[error] Main.scala:28:11: Cannot find an implicit ExecutionContext
[error] You might pass
[error] an (implicit ec: ExecutionContext) parameter to your method
[error] or import scala.concurrent.ExecutionContext.Implicits.global.
[error]   strings <- extractF
[error]           ^
[error] three errors found
[error] (Compile / compileIncremental) Compilation failed
```

---

# ExecutionContext

```scala
val etlF: Future[Unit] = for {
  strings <- extractF
  wtfs <- transformF(strings)
  _ <- loadF(wtfs)
} yield ()
```
--

```scala
val etlF = extractF
  .flatMap(strings => transformF(strings))
  .flatMap(wtfs => loadF(wtfs))
```
--

```scala
def flatMap[S](f: T => Future[S])
              (implicit ec: ExecutionContext): Future[S] = ???
```

---

# Drawbacks of Future
--

- Eager (thus not ref. transparent)

--

- Not cancellable

--

- Always asyncronous

--

- Leaky API

---

class: middle, center

# Can we do even better?

---

class: middle, center

# Yes we can!

---
class: middle, center

<img src="https://monix.io/public/images/monix-logo.png" width="100"/>

# Monix

---

# Monix modules

- `monix-eval` - Task, Coeval, MVar etc.

- `monix-reactive` - Observable, Observer (push-based streaming)

- `monix-tail` - Iterant (pull-based streaming)

- `monix-execution` - Scheduler & bunch of performance hacks

---
class: middle, center

# `Task[A]`

---

# Benefits of Task

- Lazy (ref. transparent)

--

- Cancellable

--

- Not always asyncronous

--

- Never blocks threads

--

- Stack (and heap) safe

---

# Scheduler

Can:

- Schedule delayed execution

- Schedule periodic execution

- Provide cancellation token

- Use different execution models

---

# ExecutionModel

- `AlwaysAsyncExecution`

- `SynchronousExecution`

- `BatchedExecution`

---

# Scheduler

```scala
Scheduler.computation(name = "my-computation")

Scheduler.io(name = "my-io")
```

--
```scala
Scheduler.fixedPool("my-fixed-pool", 10)

Scheduler.singleThread("my-single-thread")
```

---
# Creating a task

```scala
import monix.eval.Task

// eagerly evaluates the argument
Task.now(42)
Task.now(println(42))

// suspends argument evaluation
Task.eval(println(42))

// suspends evaluation + makes it asynchronous
Task(println(42))

...

Task.evalOnce(...)
Task.defer(...)
Task.deferFuture(...)
Task.deferFutureAction(...)

...

```

---

# Thread shifting

```scala
val t = Task.eval(println(42))

t.executeAsync

t.executeOn(io)

t.asyncBoundary(io)
```

---

# Thread shifting

```scala
import monix.execution.Scheduler
import monix.execution.Scheduler.Implicits.global

lazy val io = Scheduler.io(name = "my-io")

val source = Task.eval(println(
  s"Running on thread: $${Thread.currentThread.getName}"))

val async = source.`executeAsync`
val forked = source.`executeOn(io)`

val onFinish = Task.eval(println(
  s"Ends on thread: $${Thread.currentThread.getName}"))

source // executes on main
  .flatMap(_ => source) // executes on main
  .flatMap(_ => async) // executes on global
  .flatMap(_ => forked) // executes on io
  .`asyncBoundary` // switch back to global
  .doOnFinish(_ => onFinish) // executes on global
  .runAsync
```

---

# Composing tasks

```scala
val extractT: Task[Seq[String]] = ???
val transformT: Seq[String] => Task[Seq[WTF]] = ???
val loadT: Seq[WTF] => Task[Unit] = ???

val etl: Task[Unit] = for {
  strings <- extractT
  wtfs <- transformT(strings)
  _ <- loadT(wtfs)
} yield ()
```
--

```scala
val extract1: Task[Seq[String]] = ???
val extract2: Task[Seq[String]] = ???
val extract3: Task[Seq[String]] = ???

val extract =
  Task.parMap3(extract1, extract2, extract3)(_ :+ _ :+ _)
```

---

# Composing tasks

```scala
val comp = Scheduler.computation(name = "my-computation")
val io = Scheduler.io(name = "my-io")

val etl: Task[Unit] = for {
  strings <- extractT`.executeOn(io)`
  wtfs <- transformT(strings)`.executeOn(comp)`
  _ <- loadT(wtfs)`.executeOn(io)`
} yield ()
```

---
# Composing tasks

```scala
val tasks: Seq[Task[A]] = Seq(task1, task2, ...)

// Seq[Task[A]] => Task[Seq[A]]
Task.sequence(tasks)

Task.gather(tasks)

Task.gatherUnordered(tasks)
```
--

```scala
// Seq[Task[A]] => Task[A]
Task.raceMany(tasks)
```

---

# Task cancellation

```scala
val task = ???

val f: CancelableFuture[Unit] = t.runAsync

f.cancel()
```
--

```scala
Task { Thread.sleep(100); println(42) }
  .doOnCancel(Task.eval(println("On cancel")))
  .runAsync
  .cancel()

Thread.sleep(1000)
```

---

# Task cancellation

```scala
import monix.execution.Scheduler.Implicits.global

val sleep = Task(Thread.sleep(100))

val t = sleep.flatMap(_ => Task.eval(println(42)))

t.runAsync.cancel()

Thread.sleep(1000)
```

---

# Task cancellation

```scala
import monix.execution.Scheduler.Implicits.global

val sleep = Task(Thread.sleep(100))`.cancelable`

val t = sleep.`flatMap(_ => Task.eval(println(42)))`

t.runAsync.cancel()

Thread.sleep(1000)
```

---

# References

- [Monix (https://monix.io)](https://monix.io)

- [Monix vs Cats-Effect](https://monix.io/blog/2018/03/20/monix-vs-cats-effect.html)

- [Scalaz 8 IO vs Akka (typed) actors vs Monix @ SoftwareMill](https://blog.softwaremill.com/scalaz-8-io-vs-akka-typed-actors-vs-monix-part-1-5672657169e1)

- [Solution of the example (https://github.com/ilya-murzinov/seuraajaa)](https://github.com/ilya-murzinov/seuraajaa)

---

class: center, middle

# Questions?

---

class: center, middle

# Thanks!