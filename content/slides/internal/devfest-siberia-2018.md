---
title: Monix in practice
layout: true
---

class: center, middle

<img src="https://monix.io/public/images/monix-logo.png" width="100"/>

# Monix in practice

### Ilya Murzinov

<i class="fab fa-twitter" style="color: #00aced"></i> [ilyamurzinov](https://twitter.com/ilyamurzinov)

<i class="fab fa-github"></i> [ilya-murzinov](https://github.com/ilya-murzinov)

<i class="fab fa-telegram" style="color: #0088cc"></i> [ilyamurzinov](https://t.me/ilyamurzinov)

---

layout: true
<div class="my-footer"><span>Monix in practice - Ilya Murzinov, slides: <a href="slides/devfest-siberia-2018.pdf">https://ilya-murzinov.github.io/slides/devfest-siberia-2018.pdf</a></span></div>

---

class: middle, center

<img src="/images/Revolut.png" style="max-width:100%;"/>

---

# Referential transparency

```scala
def goodFunction() = 2 + 2
```

--

```scala
def badFunction() = {
  sendMessage()
  2 + 2
}
```

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

???
Ключевой абстракцией является Task - структура данных, которая позволяет описывать вычисления,
возможно, асинхронные. Для начала хочу пояснить, зачем вообще нужен Task, когда у нас вроде бы уже
есть Future, которая позволяет описывать асинхронные вычисления.

Дело в том, что между Task и Future есть значительные принципиальне различия, давайте на них посмотрим.

---

# Task vs Future
--

`scala.concurrect.Future`:

- Eager (thus not ref. transparent)

???
Главная проблема Future в том, что она жадная, это значит, что когда вы в своём коде получили ссылку
на какую-то Future, то скорее всего она уже начала выполняться, а может быть даже завершила выполнение.
Это нарушает ссылочную прозрачность Future, то есть банальный рефакторинг ТАКОГО ВИДА полностью меняет
семантику программы.
--

- Not cancellable

???
Кроме того, запущенное внутри Future вычисление невозможно отменить, даже если результат нам уже не
нужен. То есть отменить-то его можно, но для этого придётся делать кастомную логику в самом вычислении.
--

- Always asyncronous

???
С точки зрения выполнения, Future всегда запускается на другом логическом потоке, что может привести к
оверхеду из-за переключения контекста, хотя в некоторых случаях этого можно было бы избежать.
--

- Not stack-safe

--

`monix.Task`:

- Lazy (ref. transparent)

???
С другой стороны Task является ленивым, то есть пока на нём не вызван runAsync, ничего не будет
выполнено. На таск можно смотреть как на чистую функцию, которая возвращает Future. Это делает его
ссылочно прозрачным, а значит программу, составленную из тасков, гораздо проще поддерживать.
--

- Cancellable

???
Таск можно сделать отменяемым, причём почти автоматически, просто вызвав cancelable. Чуть позже я
поясню, как это работает.
--

- Not always asyncronous

???
Таск не всегда запускается на другом логическом потоке и позволяет очень точно контролировать своё
выполнение, например, выполнять часть задач на отдельном тред-пуле, либо форсировать переключение на
другой логический поток.
--

- Stack (and heap) safe

---

# Scheduler

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

???
computation под капотом имеет ForkJoinPool и предназначен в основном для CPU-bound вычислений.

у io под капотом unbounded CachedThreadPool.

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
  s"Running on thread: ${Thread.currentThread.getName}"))

val async = source.`executeAsync`
val forked = source.`executeOn(io)`

val onFinish = Task.eval(println(
  s"Ends on thread: ${Thread.currentThread.getName}"))

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
val extract: Task[Seq[String]] = ???
val transform: Seq[String] => Task[Seq[WTF]] = ???
val load: Seq[WTF] => Task[Unit] = ???

for {
  strings <- extract
  transformed <- transform(strings)
  _ <- load(transformed)
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

class: middle, center

# Observable[A]

???
Observable - это структура данных для описания асинхронной обработки потока данных.

Observable можно представлять как Iterable, который может обрабатывать элементы асинхронно.

Давайте посмотрим, какими свойствами обладает Observable

---

# Observable[A]

- Lazy (ref. transparent)

--

- Cancellable

--

- Safe (doesn't expose unsafe or blocking operations)

--

- Allows fine-grained control over execution

--

- Models single producer - multiple consumers communication

--

- Non-blocking back-pressure


???
У Obserable отличная интеграция с Task, то есть таски можно использовать для описания
обработки элементов.

Observable - это высокоуровневая абстракция, это значит, что для работы с ним почти
никогда не нужно задумываться про примитивы типа Observer, обычно Observable можно
легко превратить в таск и уже таск запустить.

В Мониксе есть холодные и горячие Observable, первые могу иметь только 1 подписчика,
вторые - несколько. Это позволяет строить сложные флоу по типу Akka Graph DSL.

Раз уж заговорили про акка стримы, давайте я расскажу, почему Моникс лучше.

Разумеется, с моей точки зрения.

---

# Monix vs Akka streams

`Monix` has

- Simpler API

- Lighter (no dependency on actor framework)

- Better execution control

- Easier to understand internals

- Faster

???
Моникс очень хорошо справляется с задачами, где нужно мёржить много стримов и запускать много
разных асинхронных задач

По поводу перформанса у меня есть небольшой бенчмарк.

---

# Performance

```scala
private[this] val list = 1 to 100

@Benchmark
def monixMerge: Int = {
  val observables = list
    .map(_ => Observable.fromIterable(list).executeAsync)

  Observable
    .merge(observables: _*)(OverflowStrategy.BackPressure(10))
    .foldL
    .runSyncUnsafe(1.seconds)
}

@Benchmark
def akkaMerge: Int = {
  val source: Source[Int, NotUsed] = Source(list)
  val f = list
    .map(_ => source)
    .fold(Source.empty)(_.merge(_))
    .runWith(Sink.fold(0)(_ + _))

  Await.result(f, 1.second)
}
```

---

# Performance

```
# Run complete. Total time: 00:06:45
Do not assume the numbers tell you what you want them to tell.
Benchmark                   Mode  Cnt    Score    Error  Units
MonixBenchmark.akkaMerge   thrpt   10   `46.207 ±  0.849`  ops/s
MonixBenchmark.monixMerge  thrpt   10  `531.182 ± 37.332`  ops/s
```

---

# Example

<img src="/images/devfest-siberia-2018/diagram.svg"/>

---

# Example

```scala
val acceptClient: Task[(Long, Data)] = ???

def handleClientJoin(id: Long, data: Data,
                     state: State): Task[State] = ???

def clientSubscriber(`mState: MVar[State]`) =
  Observable.repeat(())
    .doOnSubscribe(() => println(s"Client subscriber started"))
    .mapTask(_ => `acceptClient`)
    .mapTask { case (id, s) =>
      for {
        state <- `mState.take`
        newState <- `handleClientJoin(id, s, state)`
        _ <- `mState.put(newState)`
      } yield ()
    }
    `.completedL`
```

---

# Example

```scala
val acceptEventSource: Task[Iterator[Event]] = ???

def handleEvent(event: Event, state: State): Task[State]

def eventSourceProcessor(mState: MVar[State]) =
  Observable.repeat(())
    .doOnSubscribe(() => println(s"Event processor started"))
    .mapTask(_ => `acceptEventSource`)
    .flatMap(it => Observable.fromIterator(it)
      .mapTask(e => for {
        state <- mState.take
        newState <- `handleEvent(e, state)`
        _ <- mState.put(newState)
      } yield ()))
    `.headL`
```

---

# Example

```scala
val io = Scheduler.io()
val computation = Scheduler.computation()

for {
  initialState <- MVar(State())
  c = clientSubscriber(initialState).`executeOn(io)`
  e = eventSourceProcessor(initialState).`executeOn(computation)`
  _ <- Task.gatherUnordered(Seq(c, e))
} yield ()
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