# Java / Kotlin Idioms for the Unix Philosophy

The JVM ecosystem leans toward heavy abstraction, so Simplicity and Parsimony need the most attention here. Examples are in Java; Kotlin notes follow each section where the idiom differs.

## Modularity: small classes with one job

Split classes by responsibility, not by layer names alone. A `UserService` with 40 methods is several services.

```java
// After splitting
Signup signup = SignupParser.parse(request);   // throws ValidationException
User user = userRepository.create(signup);
mailer.sendWelcome(user);
```

## Composition: accept general types

```java
// Hard to compose
long countLines(Path path)

// Composable: works with files, network streams, test data
long countLines(Stream<String> lines) {
    return lines.count();
}
// caller: try (var lines = Files.lines(path)) { countLines(lines); }
```

Accept `InputStream`, `Reader`, `Iterable<T>`, `Stream<T>`, `Collection<T>`, and functional interfaces (`Function`, `Supplier`) rather than concrete classes. Kotlin: `Sequence<T>`, `Flow<T>`, and function types.

## Simplicity: avoid one-implementation interfaces

```java
// Over-engineered
interface UserService { ... }
class UserServiceImpl implements UserService { ... }
class UserServiceFactory { ... }

// Simple: a concrete class; extract an interface when a second implementation
// or a test seam is genuinely needed (most mocking libraries handle concrete classes)
class UserService { ... }
```

Prefer composition over inheritance. Use `record` for data (Kotlin: `data class`). Keep annotations and framework magic to what the project already uses.

## Separation: policy as parameters or config

```java
record RetryPolicy(int maxAttempts, Duration backoff) {}

<T> T withRetry(RetryPolicy policy, Supplier<T> action) { /* mechanism only */ }

withRetry(new RetryPolicy(3, Duration.ofMillis(200)), this::callPartner);
```

In Spring, bind policy with `@ConfigurationProperties` instead of hardcoding values in beans.

## Transparency and Repair: chain causes, fail fast

```java
// Opaque and silent
try { order = client.fetch(orderId); } catch (Exception e) { }

// Transparent: specific exception, context, original cause
try {
    order = client.fetch(orderId);
} catch (IOException e) {
    throw new OrderFetchException("fetch order " + orderId, e);
}
```

```java
// Fail fast in constructors and at startup
this.port = Integer.parseInt(Objects.requireNonNull(System.getenv("PORT"), "PORT is required"));
```

Red flags: empty `catch` blocks, `catch (Exception e) { e.printStackTrace(); }` and continuing, returning `null` on failure (use `Optional` for absence, exceptions for failure), wrapping checked exceptions in `RuntimeException` without a message. Kotlin: avoid `!!`; use `require()`/`check()` to fail fast.

## Representation: maps and enums with data

```java
enum Zone {
    BKK(40), CENTRAL(60), NORTH(80);
    final int fee;
    Zone(int fee) { this.fee = fee; }
}
```

Or `Map.of("BKK", 40, ...)`. Sealed interfaces with exhaustive `switch` (Java 21+; Kotlin `sealed` + `when`) replace instanceof chains. JUnit `@ParameterizedTest` applies the rule to tests.

## Least Surprise: JVM conventions

- Getters don't have side effects; `equals`/`hashCode` are consistent.
- Implement `AutoCloseable` for resources and use try-with-resources (Kotlin: `use {}`).
- Don't return `null` collections; return empty ones.
- Follow the Google Java Style Guide or the Kotlin coding conventions; format with `google-java-format`, Spotless, or `ktlint`.

## Silence

Log through SLF4J at the right level; no `System.out.println` in services. Don't log at INFO for every request step. CLIs write results to stdout, errors to stderr, and exit with a non-zero code on failure.

## Generation

OpenAPI Generator, `protoc` / gRPC plugins, jOOQ or QueryDSL from the database schema, MapStruct for mappers, Lombok only if the team already uses it (records often replace it).

## Optimization

Measure first with JMH for microbenchmarks and Java Flight Recorder / async-profiler for production profiles. Check GC and allocation before rewriting algorithms.

## Extensibility

Version API payloads and events; add optional fields; keep public APIs small, because every public method is a long-term commitment.
