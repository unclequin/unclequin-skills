# Java and Kotlin: Functional First

Records give immutable values, enums and sealed interfaces give closed sets of states, and streams give the pipeline. A stream is lazy and makes one pass over the data however many `filter` and `map` stages it has, but each element pays some per-stage overhead. A plain loop is a derivation, done when a profile says so.

## Compose: a stream of named predicates

```java
public record Order(String id, long total, Optional<YearMonth> paidIn, boolean refunded) {}

static Predicate<Order> paidIn(YearMonth month) {
    return o -> o.paidIn().equals(Optional.of(month));
}

static boolean isRefunded(Order o) {
    return o.refunded();
}

/** Revenue for a month is the sum of the totals of orders paid in that month,
 *  except refunded ones. A refund at any time excludes the order. */
public static long monthlyRevenue(List<Order> orders, YearMonth month) {
    return orders.stream()
            .filter(paidIn(month))
            .filter(o -> !isRefunded(o))
            .mapToLong(Order::total)
            .sum();
}
```

`java.time.YearMonth` already exists, so use it. Money is `long` cents or `BigDecimal`, never `double`.

## Derive: group instead of rescanning

```java
/** Spec: twelve passes, one per month. */
public static long[] revenueByMonthSpec(List<Order> orders, int year) {
    return IntStream.rangeClosed(1, 12)
            .mapToLong(m -> monthlyRevenue(orders, YearMonth.of(year, m)))
            .toArray();
}

/** Derived from revenueByMonthSpec by grouping instead of rescanning. */
public static long[] revenueByMonth(List<Order> orders, int year) {
    long[] out = new long[12];
    for (Order o : orders) {
        if (o.paidIn().isPresent() && o.paidIn().get().getYear() == year && !isRefunded(o)) {
            out[o.paidIn().get().getMonthValue() - 1] += o.total();
        }
    }
    return out;
}
```

For grouping by an open set of keys, `Collectors.groupingBy(key, Collectors.summingLong(...))` is the composed form. Note that the result is a `HashMap`, so the order of its keys is unspecified. If output order matters, collect into a `TreeMap`, or sort explicitly. Don't reach for `parallelStream()` as an optimization without a benchmark: it changes the summation order for floating point and adds overhead for small inputs.

## State machine: a table as data

```java
public enum State { DRAFT, PAID, SHIPPED, CANCELLED }
public enum Event { PAY, SHIP, CANCEL }

/** The whole lifecycle. A pair that isn't here is illegal. */
public static final Map<State, Map<Event, State>> TRANSITIONS = new EnumMap<>(Map.of(
        State.DRAFT, Map.of(Event.PAY, State.PAID, Event.CANCEL, State.CANCELLED),
        State.PAID, Map.of(Event.SHIP, State.SHIPPED, Event.CANCEL, State.CANCELLED),
        State.SHIPPED, Map.of(),
        State.CANCELLED, Map.of()));

public static final class IllegalTransitionException extends RuntimeException {
    IllegalTransitionException(State state, Event event) {
        super("cannot " + event + " an order that is " + state);
    }
}

public static State step(State state, Event event) {
    State next = TRANSITIONS.get(state).get(event);
    if (next == null) {
        throw new IllegalTransitionException(state, event);
    }
    return next;
}

/** Folds step over events. Throws at the first illegal one. */
public static State replay(State start, List<Event> events) {
    State state = start;
    for (Event event : events) {
        state = step(state, event);
    }
    return state;
}
```

When states carry data, model them as a `sealed interface` with one `record` per state, and switch over them with pattern matching. The compiler then checks that every state is handled. Keep the table for which moves are legal.

## Kotlin

The same shapes, shorter:

```kotlin
data class Order(val id: String, val total: Long, val paidIn: YearMonth?, val refunded: Boolean)

fun paidIn(month: YearMonth): (Order) -> Boolean = { it.paidIn == month }
val isRefunded: (Order) -> Boolean = { it.refunded }

fun monthlyRevenue(orders: List<Order>, month: YearMonth): Long =
    orders.filter(paidIn(month)).filterNot(isRefunded).sumOf { it.total }

enum class State { DRAFT, PAID, SHIPPED, CANCELLED }
enum class Event { PAY, SHIP, CANCEL }

val transitions: Map<Pair<State, Event>, State> = mapOf(
    (State.DRAFT to Event.PAY) to State.PAID,
    (State.DRAFT to Event.CANCEL) to State.CANCELLED,
    (State.PAID to Event.SHIP) to State.SHIPPED,
    (State.PAID to Event.CANCEL) to State.CANCELLED,
)

fun step(state: State, event: Event): Result<State> =
    transitions[state to event]?.let { Result.success(it) }
        ?: Result.failure(IllegalStateException("cannot $event an order that is $state"))
```

Kotlin collection operations are eager and allocate a list per stage. Switch to `asSequence()` for long pipelines over large data, after measuring.

## Types: sets of values, sets of messages

```java
// Before: three flags and two optional fields allow 2³ combinations of flags,
// each with or without an amount and a tracking number. Four are legal.
public record OrderRecord(boolean paid, boolean shipped, boolean cancelled,
        Optional<Long> amount, Optional<String> tracking) {}
```

```java
/** An amount in integer cents, greater than zero. */
public record Amount(long cents) {
    public Amount {
        if (cents <= 0) {
            throw new IllegalArgumentException("amount must be positive: " + cents);
        }
    }

    /** Parses raw input at the boundary; the core takes only Amount. */
    public static Amount parse(String raw) {
        if (!raw.matches("[0-9]+")) {
            throw new IllegalArgumentException("invalid amount: \"" + raw + "\"");
        }
        // parseLong rejects values too large for a long; the constructor rejects zero.
        return new Amount(Long.parseLong(raw));
    }
}
```

A record's constructor is as public as the record, so the check goes in the compact constructor: every `Amount` that exists is positive, however it was made, deserialization included. `parse` is the boundary that turns a `String` into one. The regex matters: `parseLong` alone also accepts `"+5"`, `"-5"`, and other scripts' digits.

```java
// After: one type per state, each holding only its own data.
// A state's methods are the messages it accepts.
public sealed interface Order permits Draft, Paid, Shipped, Cancelled {}

public record Draft(String id) implements Order, Cancellable {
    public Paid pay(Amount amount) {
        return new Paid(id, amount);
    }
}

public record Paid(String id, Amount amount) implements Order, Cancellable {
    public Shipped ship(String tracking) {
        return new Shipped(id, amount, tracking);
    }
}

public record Shipped(String id, Amount amount, String tracking) implements Order {}

public record Cancelled(String id) implements Order {}

/** The amount to refund on cancellation: only money that was taken. */
public static long refundDue(Order order) {
    return switch (order) {
        case Draft d -> 0;
        case Cancelled c -> 0;
        case Paid p -> p.amount().cents();
        case Shipped s -> s.amount().cents();
    };
}
```

`Order` is sealed, so the compiler knows its four cases and the `switch` needs no `default`. Add a fifth record to `permits` and every `switch` over `Order` that doesn't handle it stops compiling.

```java
/** The states that accept cancel. */
public sealed interface Cancellable permits Draft, Paid {
    String id();

    default Cancelled cancel() {
        return new Cancelled(id());
    }
}

/** The messages a state accepts, read from the transition table. */
public static List<Event> accepts(State state) {
    return Stream.of(Event.values()).filter(TRANSITIONS.get(state)::containsKey).toList();
}
```

The methods are the typestate: only `Paid` has `ship`, so `draft.ship("T1")` doesn't compile, and only the two `Cancellable` states have `cancel`. `Event` is the set of messages the lifecycle understands, and `accepts` reads one state's subset from `TRANSITIONS` instead of keeping a second list. Events that arrive as data, from a queue or a database, still go through `step`. When messages carry data of their own, make them a sealed interface of records instead of an enum, and the same exhaustive `switch` handles them.

In Kotlin, a `sealed interface` of `data class` states with a `when` expression gives the same exhaustiveness check, and a `value class` with a private constructor and a parsing factory gives the narrow type.

## Check: properties

With jqwik, a JUnit 5 engine:

```java
@Property
void derivedEqualsSpec(@ForAll("orders") List<Order> orders) {
    assertArrayEquals(revenueByMonthSpec(orders, 2024), revenueByMonth(orders, 2024));
}

@Provide
Arbitrary<List<Order>> orders() {
    Arbitrary<Optional<YearMonth>> paid = Combinators.combine(
            Arbitraries.integers().between(2024, 2025), Arbitraries.integers().between(1, 12))
        .as(YearMonth::of).optional();
    return Combinators.combine(Arbitraries.strings().ofMaxLength(3),
            Arbitraries.longs().between(0, 1000), paid, Arbitraries.of(true, false))
        .as(Order::new).list().ofMaxSize(20);
}

@Property
void lifecycleInvariants(@ForAll @Size(max = 8) List<Event> events) {
    State state = State.DRAFT;
    for (Event event : events) {
        boolean allowed = TRANSITIONS.get(state).containsKey(event);
        try {
            State next = step(state, event);
            assertTrue(allowed);
            state = next;
        } catch (IllegalTransitionException e) {
            assertFalse(allowed);
        }
    }
}
```

```java
@Example
void aStateAcceptsExactlyTheEventsStepAllows() {
    for (State state : State.values()) {
        assertEquals(Stream.of(Event.values()).filter(e -> allows(state, e)).toList(), accepts(state));
    }
}

@Property
void parseAcceptsExactlyThePositiveWholeNumbersOfCents(@ForAll("raw") String raw) {
    boolean digits = !raw.isEmpty() && raw.chars().allMatch(c -> c >= '0' && c <= '9');
    boolean valid = digits && new BigInteger(raw).signum() > 0 && new BigInteger(raw).bitLength() < 64;
    try {
        Amount amount = Amount.parse(raw);
        assertTrue(valid);
        assertEquals(new BigInteger(raw).longValueExact(), amount.cents());
    } catch (IllegalArgumentException e) {
        assertFalse(valid);
    }
}

@Provide
Arbitrary<String> raw() {
    return Arbitraries.oneOf(Arbitraries.strings(), Arbitraries.longs().map(String::valueOf),
            Arbitraries.strings().numeric().ofMaxLength(25));
}
```

`allows(state, event)` calls `step` and reports whether it threw. Java has no standard way to assert that `draft.ship(...)` fails to compile short of running the compiler inside a test, so that check is left to the build.

For Kotlin, Kotest's `checkAll` covers the same ground. Without a library, a seeded `java.util.Random` loop inside a normal JUnit test works too, without shrinking.

## Tooling

- Measure before deriving with JMH for microbenchmarks, and async-profiler or JDK Flight Recorder for real workloads. A loop timed with `System.nanoTime()` without warm-up measures the JIT, not your code.
- Use the formatter the project already has (google-java-format, Spotless, or ktlint for Kotlin).
