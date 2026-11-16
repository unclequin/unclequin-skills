# Fragments: java

Code that `skills/unix-philosophy/references/languages/java.md` shows on purpose
in a form that can't be compiled, with the reason. `scripts/check-examples.py`
skips exactly these paragraphs; everything else the file shows is in the
tested sources in this folder.

The "before" signature has no body; the next paragraph redeclares `countLines`.

```java
// Hard to compose
long countLines(Path path)
```

The "before" classes use `...` for their bodies.

```java
// Over-engineered
interface UserService { ... }
class UserServiceImpl implements UserService { ... }
class UserServiceFactory { ... }
```

The "after" class uses `...` for its body.

```java
// Simple: a concrete class; extract an interface when a second implementation
// or a test seam is genuinely needed (most mocking libraries handle concrete classes)
class UserService { ... }
```

`withRetry` is shown with a comment for a body, which does not return. `Partner.java` has it with a real body.

```java
<T> T withRetry(RetryPolicy policy, Supplier<T> action) { /* mechanism only */ }
```
