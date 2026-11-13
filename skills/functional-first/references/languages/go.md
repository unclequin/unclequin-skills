# Go: Functional First

Go has no `filter` or `map` in the standard library, and a hand-written generic pipeline isn't idiomatic. The composed form in Go is a plain loop that calls named predicates, so the condition reads like the sentence. State machines fit naturally as a map of maps. Go doesn't fuse anything for you, so every pass is a real pass.

## Compose: named predicates in a plain loop

```go
type YearMonth struct {
	Year  int
	Month time.Month
}

type Order struct {
	ID       string
	Total    int64      // cents
	PaidIn   *YearMonth // nil if unpaid
	Refunded bool
}

func paidIn(m YearMonth) func(Order) bool {
	return func(o Order) bool { return o.PaidIn != nil && *o.PaidIn == m }
}

func isRefunded(o Order) bool { return o.Refunded }

// MonthlyRevenue is the sum of the totals of orders paid in month m,
// except refunded ones. A refund at any time excludes the order.
func MonthlyRevenue(orders []Order, m YearMonth) int64 {
	isPaid := paidIn(m)
	var sum int64
	for _, o := range orders {
		if isPaid(o) && !isRefunded(o) {
			sum += o.Total
		}
	}
	return sum
}
```

"Also exclude test accounts" becomes one predicate, `isTestAccount`, and one more `&& !isTestAccount(o)`. Take the month as a parameter, never `time.Now()` inside, so the function stays pure.

This example stores the paid month directly to keep it short. With a real `PaidAt time.Time`, which month an instant falls in depends on the time zone, so put the zone in the month value (`Month{Year, Month, Loc}`) and convert with `t.In(m.Loc)` before comparing. In tests, use `time.FixedZone` rather than `time.LoadLocation`, so they don't depend on the machine's time zone database.

For longer pipelines over large or streaming data, `iter.Seq[T]` (Go 1.23+) lets each stage be a small named function. Use it when stages are reused. A plain loop is clearer when they aren't.

## Derive: group instead of rescanning

The spec for a yearly report calls `MonthlyRevenue` twelve times. Keep it, and derive a one-pass version:

```go
// RevenueByMonthSpec is the spec: twelve passes, one per month.
func RevenueByMonthSpec(orders []Order, year int) [12]int64 {
	var out [12]int64
	for i := range out {
		out[i] = MonthlyRevenue(orders, YearMonth{year, time.Month(i + 1)})
	}
	return out
}

// RevenueByMonth is derived from RevenueByMonthSpec by grouping instead of
// rescanning: one pass, adding each order to its month's slot.
func RevenueByMonth(orders []Order, year int) [12]int64 {
	var out [12]int64
	for _, o := range orders {
		if o.PaidIn != nil && o.PaidIn.Year == year && !isRefunded(o) {
			out[o.PaidIn.Month-1] += o.Total
		}
	}
	return out
}
```

The spec can stay in the package, or move to a `_test.go` file if nothing else calls it. Arrays compare with `==`, which makes the spec-equals-derived check one line.

## State machine: a table as data

```go
type State string
type Event string

const (
	Draft     State = "draft"
	Paid      State = "paid"
	Shipped   State = "shipped"
	Cancelled State = "cancelled"
)

const (
	Pay    Event = "pay"
	Ship   Event = "ship"
	Cancel Event = "cancel"
)

// Transitions is the whole lifecycle. A pair that isn't here is illegal.
var Transitions = map[State]map[Event]State{
	Draft: {Pay: Paid, Cancel: Cancelled},
	Paid:  {Ship: Shipped, Cancel: Cancelled},
}

func Step(s State, e Event) (State, error) {
	next, ok := Transitions[s][e]
	if !ok {
		return s, fmt.Errorf("cannot %s an order that is %s", e, s)
	}
	return next, nil
}

// Replay folds Step over events and stops at the first illegal one.
func Replay(start State, events []Event) (State, error) {
	s := start
	for i, e := range events {
		next, err := Step(s, e)
		if err != nil {
			return s, fmt.Errorf("event %d: %w", i, err)
		}
		s = next
	}
	return s, nil
}
```

Indexing a missing outer key of a nil map is safe in Go, so terminal states need no entry. When states carry data (a paid amount), keep the table for the shape and let a `switch` on the event compute the new data after the table says the move is legal.

## Check: properties with a seeded loop

The standard library is enough for property tests. Keep the domain small so collisions happen:

```go
func randomOrders(r *rand.Rand) []Order {
	orders := make([]Order, r.IntN(20))
	for i := range orders {
		orders[i] = Order{Total: r.Int64N(1000), Refunded: r.IntN(4) == 0}
		if r.IntN(3) > 0 {
			orders[i].PaidIn = &YearMonth{2024 + r.IntN(2), time.Month(1 + r.IntN(12))}
		}
	}
	return orders
}

func TestRevenueByMonthMatchesSpec(t *testing.T) {
	r := rand.New(rand.NewPCG(42, 0))
	for i := range 1000 {
		orders := randomOrders(r)
		if got, want := RevenueByMonth(orders, 2024), RevenueByMonthSpec(orders, 2024); got != want {
			t.Fatalf("case %d: got %v, want %v for %+v", i, got, want, orders)
		}
	}
}

var allEvents = []Event{Pay, Ship, Cancel}

func TestLifecycleInvariants(t *testing.T) {
	r := rand.New(rand.NewPCG(1, 0))
	for range 1000 {
		s := Draft
		for range r.IntN(8) {
			e := allEvents[r.IntN(len(allEvents))]
			_, allowed := Transitions[s][e]
			next, err := Step(s, e)
			if allowed != (err == nil) {
				t.Fatalf("%s + %s: allowed=%v, err=%v", s, e, allowed, err)
			}
			if err != nil && next != s {
				t.Fatalf("rejected %s changed state %s to %s", e, s, next)
			}
			if (s == Shipped || s == Cancelled) && err == nil {
				t.Fatalf("terminal state %s accepted %s", s, e)
			}
			s = next
		}
	}
}
```

The lifecycle test reaches every state by replaying random events from `Draft`, never by constructing a state by hand.

With `pgregory.net/rapid`, the same spec-equals-derived check gets shrinking. When it fails, rapid reports the smallest failing order list:

```go
func TestRevenueByMonthMatchesSpecRapid(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		orders := rapid.SliceOfN(rapid.Custom(genOrder), 0, 20).Draw(t, "orders")
		if got, want := RevenueByMonth(orders, 2024), RevenueByMonthSpec(orders, 2024); got != want {
			t.Fatalf("got %v, want %v", got, want)
		}
	})
}
```

`genOrder` is a `func(*rapid.T) Order` built from `rapid.Int64Range`, `rapid.IntRange`, and `rapid.Bool`.

## Tooling

- Benchmark before deriving: `go test -bench . -benchmem`, then `go test -cpuprofile cpu.out` and `go tool pprof cpu.out`.
- `gofmt` and `go vet` on every change. `golangci-lint` if the project uses it.
