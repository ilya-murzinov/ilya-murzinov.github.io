class: middle, center

# Typelevel computations with Scala

### Ilya Murzinov

[https://twitter.com/ilyamurzinov](https://twitter.com/ilyamurzinov)

[https://github.com/ilya-murzinov](https://github.com/ilya-murzinov)

---

class: middle, center

# Revolut

---

class: middle, center

# Why?

---

# Because it's freaking cool

... and we can do this with Haskell

<img src="/images/scalaspb/typing-the-technical-interview.png" height="400px"/>

???
Staring with Haskell is never good

Kyle Kingsbury

Distributed system correctness

---

# N queens problem

<img src="/images/scalaspb/nqueens.jpg" height="450px"/>

???
Algorythm - recursively for every queen in row check if it's safe,
then add it and move to the next row

---

# What we need for solution

- Natural numbers
--

- Lists
--

- Booleans
--

- Functions
--

- **The way to operate with all above**
---

# Natural numbers

```scala
trait Nat
trait Z extends Nat
trait Succ[Z] extends Nat
```

???
Type bounds are left hereinafter

--

```scala
type _0 = Z
type _1 = Succ[Z]
type _2 = Succ[_1]
type _3 = Succ[_2]
type _4 = Succ[_3]
type _5 = Succ[_4]

// and so on
```
---

# Linked list

```scala
trait List

trait Nil extends List
trait Cons[H, T] extends List
```

---

# Infix types

```scala
type T1 = Cons[A, B]

type T2 = A Cons B
```
--

```scala
type ::[H, T] = Cons[H, T]
```
--

```scala
type T3 = A :: B
```
--

```scala
type L = _1 :: _2 :: _3 :: Nil
```

---

# Typelevel functions

```scala
trait Nat {
  type Add[A]
}
```
--

```scala
trait Z extends Nat {
  type Add[A] = A
}
trait Succ[Z] extends Nat {
  type Add[A] = Succ[Z#Add[A]]
}
```

---

class: middle, center

# Typeclasses!

---

# The Add typeclass

```scala
class Add[A, B] {type Out}
```
--

```scala
implicit def a0[A]: Add[`_0`, A] {type Out = A} = `???`
```
--

```scala
implicit def a1[A]: Add[A, `_0`] {type Out = A} = ???
```
--

```scala
implicit def a2[A, B, C](implicit
  a: `Add[A, B]{type Out = C}`
): `Add[Succ[A], B] {type Out = Succ[C]}` = ???
```

???
Type member is like type parameter

Think of it as a result and type parameters as arguments

---

# How to use it
--

```scala
def implicitly[A](implicit a: A) = ???
```
--

```scala
scala> implicitly[Add[_1, _2]]
scala.NotImplementedError: an implementation is missing
	at scala.Predef$.$qmark$qmark$qmark(Predef.scala:252)
```
--

```scala
scala> :t implicitly[Add[_1, _2]]
Add[_1,_2]
```

???
The purpose was to compile only if function can be performed

This is not useful - we already know that we can add 2 naturals

Result is invisible

Type member is erased

---

# The Aux pattern
--

```scala
class Add[A, B] {type Out}
object Add {
  type Aux[A, B, C] = Add[A, B] { type Out = C }
```
--

```scala
  def apply[A, B](implicit a: Add[A, B]): `Aux[A, B, a.Out]` = ???
}
```
--

```scala
scala> :t Add[_1, _2]
Add[Succ[Z],Succ[Succ[Z]]]{type Out = Succ[Succ[Succ[Z]]]}
```

???
apply instead of implicitly

---

# Implicit resolution is a search process

---

class: middle, center

# -Xlog-implicits


---

# Diverging implicit expansion

```
[error] somefile.scala:XX:YY: diverging implicit expansion
        for type T
[error] starting with method m0 in class C
[error]   implicitly[T]
[error]             ^
[error] one error found
[error] (compile:compileIncremental) Compilation failed
```

---

# Diverging implicit expansion

<img src="/images/scalaspb/spiewak.png" height="250px"/>
--

&nbsp;
&nbsp;

"A couple of years ago when I was working through some issues like this I found that the easiest way to figure out what the divergence checker was doing was just to **throw some printlns into the compiler and publish it locally.**"

(c) [Travis Brown on stackoverflow](https://stackoverflow.com/questions/42178372/why-does-scalac-rise-a-diverging-implicit-expansion-error-here)

---

# Diverging implicit expansion

Let's imagine...

--

```scala
T[C[S, V]]
T[S]
T[C[V, C[V, V]]]
```

--

```scalac
[error] divexp.scala:20:13: diverging implicit expansion
        for type d.this.T[d.this.C[d.this.S,d.this.V]]
[error] starting with method a0 in class d
[error]   implicitly[T[C[S, V]]]
[error]             ^
[error] one error found
[error] (compile:compileIncremental) Compilation failed
```

---
class: center, middle

# What other typeclasses are required?

---

```scala
trait First[L <: List] { type Out }
trait Concat[A <: List, B <: List] { type Out <: List }
trait ConcatAll[Ls <: List] { type Out <: List }
trait AnyTrue[L] { type Out <: Bool }
trait Not[A <: Bool] { type Out <: Bool }
trait Or[A <: Bool, B <: Bool] { type Out <: Bool }
trait Eq[A <: Nat, B <: Nat] { type Out <: Bool }
trait Lt[A <: Nat, B <: Nat] { type Out <: Bool }
trait AbsDiff[A <: Nat, B <: Nat] { type Out <: Nat }
trait Range[A <: Nat] { type Out <: List }
trait Apply[F <: Func, A] { type Out }
trait Map[F <: Func, L <: List] { type Out <: List }
trait MapCat[F <: Func, L <: List] { type Out <: List }
trait AppendIf[B <: Bool, A, L <: List] { type Out <: List }
trait Filter[F <: Func, L <: List] { type Out <: List }
trait QueensInRow[Y <: Nat, N <: Nat] { type Out <: List }
trait Threatens[Q1 <: Queen[_, _], Q2 <: Queen[_, _]]
  { type Out <: Bool }
trait Safe[Config <: List, Q <: Queen[_, _]] { type Out <: Bool }
trait AddQueen[N <: Nat, X <: Nat, Config <: List]
  { type Out <: List }
trait AddQueenToAll[N <: Nat, X <: Nat, Configs <: List]
  { type Out <: List }
trait AddQueensIf[P <: Bool, N <: Nat, X <: Nat, Configs <: List]
  { type Out <: List }
trait AddQueens[N <: Nat, X <: Nat, Configs <: List]
  { type Out <: List }
trait Solution[N <: Nat] { type Out <: List }
```

---

# What to do with all this

- programming with dependent types
- typeclass derivations

---

# References

- ["The Type Astronaut's Guide to Shapeless" by Dave Gurnell](https://github.com/underscoreio/shapeless-guide)
--

- ["Hacking on scalac — 0 to PR in an hour" by Miles Sabin](https://milessabin.com/blog/2016/05/13/scalac-hacking/)
--

- ["Typing the technical interview" by Kyle Kingsbury, a.k.a "Aphyr"](https://aphyr.com/posts/342-typing-the-technical-interview)
--


- [Slides](https://ilya-murzinov.github.io/slides/scalaspb/)
--

- [Solution of N queens problem on type level](https://scastie.scala-lang.org/ilya-murzinov/mNhJH6kdQFyfa59Vzs2OhA)

---

class: center, middle

# Questions?

---

class: center, middle

# Thanks!