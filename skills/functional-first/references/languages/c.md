# C: Functional First

C is where *Functional C* starts: the language has no closures, no garbage-collected lists, and no pipelines, so the clear version and the fast version are both written by hand. The composed form is plain functions that call small `static` predicates, over arrays passed with their length. The transition table is a 2-D array indexed by enums. Every derivation step is manual, and the spec-equals-derived test runs under the sanitizers, because a wrong index is memory corruption, not just a wrong answer.

## Compose: small static predicates

```c
typedef struct {
    int year;
    int month; /* 1-12 */
} YearMonth;

typedef struct {
    int64_t total;     /* cents */
    bool paid;         /* paid_in is valid only when paid */
    YearMonth paid_in;
    bool refunded;
} Order;

static bool paid_in(const Order *o, YearMonth m) {
    return o->paid && o->paid_in.year == m.year && o->paid_in.month == m.month;
}

static bool is_refunded(const Order *o) {
    return o->refunded;
}

/* Revenue for a month is the sum of the totals of orders paid in that month,
 * except refunded ones. A refund at any time excludes the order. */
int64_t monthly_revenue(const Order *orders, size_t n, YearMonth m) {
    int64_t sum = 0;
    for (size_t i = 0; i < n; i++) {
        if (paid_in(&orders[i], m) && !is_refunded(&orders[i])) {
            sum += orders[i].total;
        }
    }
    return sum;
}
```

The loop condition reads like the sentence. Inputs are `const` pointers plus a length: pure in, value out, nothing modified. `static` predicates are inlined by any optimizing compiler, so naming them costs nothing at run time.

## Derive: group instead of rescanning

```c
/* Spec: twelve passes, one per month. */
void revenue_by_month_spec(const Order *orders, size_t n, int year, int64_t out[12]) {
    for (int month = 1; month <= 12; month++) {
        out[month - 1] = monthly_revenue(orders, n, (YearMonth){year, month});
    }
}

/* Derived from revenue_by_month_spec by grouping instead of rescanning.
 * The month range check keeps out-of-range months ignored, as in the spec. */
void revenue_by_month(const Order *orders, size_t n, int year, int64_t out[12]) {
    for (int i = 0; i < 12; i++) {
        out[i] = 0;
    }
    for (size_t i = 0; i < n; i++) {
        const Order *o = &orders[i];
        if (o->paid && o->paid_in.year == year && !is_refunded(o) &&
            o->paid_in.month >= 1 && o->paid_in.month <= 12) {
            out[o->paid_in.month - 1] += o->total;
        }
    }
}
```

The range check is the derivation's real work. The spec only ever asks about months 1 to 12, so a month of 0 or 13 is silently ignored. The derived code uses the month as an array index, so without the check that input becomes an out-of-bounds write. Derivation in C means finding every place where the spec's safety came for free and making it explicit.

Other C derivations follow the catalog in `derivation.md`: turn recursion into a loop, reuse a caller-provided output buffer instead of allocating, and update in place only when no one else holds a pointer to the old value. State who owns each buffer in a comment.

## State machine: a 2-D table

```c
typedef enum { DRAFT, PAID, SHIPPED, CANCELLED, STATE_COUNT } State;
typedef enum { PAY, SHIP, CANCEL, EVENT_COUNT } Event;

#define ILLEGAL STATE_COUNT

/* The whole lifecycle. ILLEGAL marks every pair that isn't allowed. */
const State TRANSITIONS[STATE_COUNT][EVENT_COUNT] = {
    [DRAFT]     = {[PAY] = PAID,    [SHIP] = ILLEGAL, [CANCEL] = CANCELLED},
    [PAID]      = {[PAY] = ILLEGAL, [SHIP] = SHIPPED, [CANCEL] = CANCELLED},
    [SHIPPED]   = {[PAY] = ILLEGAL, [SHIP] = ILLEGAL, [CANCEL] = ILLEGAL},
    [CANCELLED] = {[PAY] = ILLEGAL, [SHIP] = ILLEGAL, [CANCEL] = ILLEGAL},
};

/* Returns false and leaves *next untouched for an illegal pair. */
bool step(State s, Event e, State *next) {
    State t = TRANSITIONS[s][e];
    if (t == ILLEGAL) {
        return false;
    }
    *next = t;
    return true;
}

/* Folds step over events and stops at the first illegal one,
 * reporting its index in *failed_at. */
bool replay(State start, const Event *events, size_t n, State *end, size_t *failed_at) {
    State s = start;
    for (size_t i = 0; i < n; i++) {
        if (!step(s, events[i], &s)) {
            *end = s;
            *failed_at = i;
            return false;
        }
    }
    *end = s;
    return true;
}
```

Write every cell, including the `ILLEGAL` ones. Designated initializers would quietly fill a missing cell with `0`, which is `DRAFT`, a legal-looking state. The `STATE_COUNT` and `EVENT_COUNT` sentinels size the table, so adding a state without a row is a visible gap. The error is a `bool` return plus out-parameters, with the failing index, so the caller can say which event was illegal.

## Types: sets of values, sets of messages

```c
/* Before: three flags and two maybe-set fields allow 2³ combinations of flags,
 * each with or without an amount and a tracking number. Four are legal. */
typedef struct {
    bool paid;
    bool shipped;
    bool cancelled;
    bool has_amount;   /* amount is valid only when has_amount */
    int64_t amount;
    char tracking[32]; /* empty until shipped */
} OrderRecord;
```

```c
/* An amount in integer cents, greater than zero. Only parse_amount makes one. */
typedef struct {
    int64_t cents;
} Amount;

/* Parses raw input at the boundary; the core takes only Amount.
 * Returns false and leaves *out untouched unless raw is digits only,
 * fits in int64_t, and is greater than zero. */
bool parse_amount(const char *raw, Amount *out) {
    if (*raw == '\0') {
        return false;
    }
    int64_t n = 0;
    for (const char *p = raw; *p != '\0'; p++) {
        if (*p < '0' || *p > '9') {
            return false;
        }
        int digit = *p - '0';
        if (n > (INT64_MAX - digit) / 10) {
            return false;
        }
        n = n * 10 + digit;
    }
    if (n == 0) {
        return false;
    }
    *out = (Amount){n};
    return true;
}
```

Wrapping the number in a struct makes `Amount` a distinct type: passing a bare `int64_t` where an `Amount` is expected is a compile error. It doesn't stop anyone writing `(Amount){-5}`. For real enforcement, declare `typedef struct Amount Amount;` in the header, define the struct only in `amount.c`, and hand out pointers; callers then can't see the field at all, at the cost of allocation and an accessor.

```c
/* After: the tag says which state, and the union holds only that state's data. */
typedef enum { ORDER_DRAFT, ORDER_PAID, ORDER_SHIPPED, ORDER_CANCELLED } OrderTag;

typedef struct {
    OrderTag tag;
    union {
        struct {
            Amount amount;
        } paid; /* valid only when tag is ORDER_PAID */
        struct {
            Amount amount;
            char tracking[32];
        } shipped; /* valid only when tag is ORDER_SHIPPED */
    } as;
} TaggedOrder;

/* The amount to refund on cancellation: only money that was taken. */
int64_t refund_due(const TaggedOrder *o) {
    switch (o->tag) {
    case ORDER_DRAFT:
    case ORDER_CANCELLED:
        return 0;
    case ORDER_PAID:
        return o->as.paid.amount.cents;
    case ORDER_SHIPPED:
        return o->as.shipped.amount.cents;
    }
    fprintf(stderr, "refund_due: tag %d is not an OrderTag\n", (int)o->tag);
    abort();
}
```

The switch has no `default`, so `-Wswitch` (part of `-Wall`) reports any `OrderTag` it doesn't handle, and `-Werror` makes that a build failure. Add `-Wswitch-enum` to get the same report from switches that do have a `default`. Keep sentinels like `STATE_COUNT` out of a tag enum, or every switch must handle them too. C's guarantee is weaker than a real sum type: nothing stops code from reading `as.shipped` when the tag says `ORDER_PAID`, so read the union only inside a switch on the tag.

```c
/* The messages a state accepts, read from the transition table:
 * bit e is set when event e is legal. */
unsigned accepts(State s) {
    unsigned set = 0;
    for (int e = 0; e < EVENT_COUNT; e++) {
        if (TRANSITIONS[s][e] != ILLEGAL) {
            set |= 1u << e;
        }
    }
    return set;
}
```

`Event` is the set of messages the lifecycle understands, and `accepts` reads one state's subset from the table as a bitmask, instead of keeping a second list. C has no plain typestate. A struct per state with `ship` taking only the paid one gets part of the way, but `cancel` then needs one function per source state, and every order read back from a `TaggedOrder` must be checked by hand before it can be passed. So C relies on `step` at run time.

## Check: properties in a plain test

```c
/* Small seeded generator (xorshift), so failures can be reproduced. */
static uint64_t rng_state = 42;
static int below(int n) {
    rng_state ^= rng_state << 13;
    rng_state ^= rng_state >> 7;
    rng_state ^= rng_state << 17;
    return (int)(rng_state % (uint64_t)n);
}

static size_t random_orders(Order *orders) {
    size_t n = (size_t)below(20);
    for (size_t i = 0; i < n; i++) {
        orders[i] = (Order){
            .total = below(1000),
            .paid = below(3) > 0,
            .paid_in = {2024 + below(2), below(14)}, /* includes invalid months 0 and 13 */
            .refunded = below(4) == 0,
        };
    }
    return n;
}

int main(void) {
    Order orders[20];
    for (int c = 0; c < 1000; c++) {
        size_t n = random_orders(orders);
        int64_t got[12], want[12];
        revenue_by_month(orders, n, 2024, got);
        revenue_by_month_spec(orders, n, 2024, want);
        if (memcmp(got, want, sizeof got) != 0) {
            fprintf(stderr, "case %d: derived differs from spec\n", c);
            return 1;
        }
    }

    for (int c = 0; c < 1000; c++) {
        State s = DRAFT;
        for (int k = below(8); k > 0; k--) {
            Event e = (Event)below(EVENT_COUNT);
            State before = s;
            bool allowed = TRANSITIONS[s][e] != ILLEGAL;
            if (step(s, e, &s) != allowed || (!allowed && s != before)) {
                fprintf(stderr, "state %d, event %d: table and step disagree\n", before, e);
                return 1;
            }
        }
    }

    if (check_types() != 0) {
        return 1;
    }
    puts("ok");
    return 0;
}
```

The generator deliberately produces invalid months (0 and 13). With the range check removed from `revenue_by_month`, this test crashes under AddressSanitizer with a stack-buffer-overflow on the first such case. That's why property tests in C must generate inputs outside the valid range, and why they run under the sanitizers.

The checks for the types run from `main` too. The parse property generates strings over a small alphabet heavy in digits and zeros, up to 21 characters, so signs, spaces, leading zeros and overflow past `INT64_MAX` all come up, and compares `parse_amount` with a spec built on `strtoll`:

```c
/* parse_amount's spec, from the standard library: strtoll on a string of
 * digits only, in range, above zero. */
static bool is_amount_spec(const char *raw, int64_t *n) {
    if (*raw == '\0' || strspn(raw, "0123456789") != strlen(raw)) {
        return false;
    }
    errno = 0;
    long long v = strtoll(raw, NULL, 10);
    *n = v;
    return errno == 0 && v > 0;
}

static int check_types(void) {
    for (int s = 0; s < STATE_COUNT; s++) {
        unsigned allowed = 0;
        for (int e = 0; e < EVENT_COUNT; e++) {
            State next;
            if (step((State)s, (Event)e, &next)) {
                allowed |= 1u << e;
            }
        }
        if (accepts((State)s) != allowed) {
            fprintf(stderr, "state %d: accepts and step disagree\n", s);
            return 1;
        }
    }

    const char alphabet[] = "0123456789000+- a";
    for (int c = 0; c < 10000; c++) {
        char raw[24] = {0};
        for (int i = below(22); i > 0; i--) {
            raw[strlen(raw)] = alphabet[below((int)sizeof alphabet - 1)];
        }
        int64_t want = 0;
        Amount got = {0};
        bool ok = parse_amount(raw, &got);
        if (ok != is_amount_spec(raw, &want) || (ok && got.cents != want)) {
            fprintf(stderr, "parse_amount(\"%s\") disagrees with its spec\n", raw);
            return 1;
        }
    }
    return 0;
}
```

The first loop is the law that a state accepts exactly the events `step` allows, checked for every state. With no typestate, there is no "doesn't compile" test to write.

`theft` is a property-testing library for C with shrinking, if adding a dependency is fine. The seeded loop above needs nothing.

## Tooling

- Build and test with `-std=c17 -Wall -Wextra -Wpedantic -Werror -fsanitize=address,undefined -g`.
- Measure before deriving: `perf` on Linux, Instruments on macOS, and `valgrind --tool=callgrind` for instruction counts.
- `clang-format` for formatting, and `clang-tidy` or `cppcheck` for static analysis.
