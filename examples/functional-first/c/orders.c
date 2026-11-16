/* The code shown in skills/functional-first/references/languages/c.md.
 * scripts/check-examples.py checks that the two stay the same. */
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <stdio.h>
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
    puts("ok");
    return 0;
}
