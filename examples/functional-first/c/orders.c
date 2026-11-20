/* The code shown in skills/functional-first/references/languages/c.md.
 * scripts/check-examples.py checks that the two stay the same. */
#include <errno.h>
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

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
