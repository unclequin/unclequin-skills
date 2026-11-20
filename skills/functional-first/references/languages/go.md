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

## Types: sets of values, sets of messages

These live in their own package, `order`, beside `orders`, so the package boundary can guard them.

```go
// Before: three flags and two optional fields allow 2³ combinations of flags,
// each with or without an amount and a tracking number. Four are legal.
type Record struct {
	Paid      bool
	Shipped   bool
	Cancelled bool
	Amount    *int64  // nil until paid
	Tracking  *string // nil until shipped
}
```

```go
// Amount is an amount in integer cents, greater than zero.
// Only ParseAmount makes one.
type Amount struct{ cents int64 }

func (a Amount) Cents() int64 { return a.cents }

// ParseAmount parses raw input at the boundary; the core takes only Amount.
func ParseAmount(raw string) (Amount, error) {
	if raw == "" || strings.Trim(raw, "0123456789") != "" {
		return Amount{}, fmt.Errorf("invalid amount %q: want digits only", raw)
	}
	n, err := strconv.ParseInt(raw, 10, 64)
	if err != nil {
		return Amount{}, fmt.Errorf("invalid amount %q: %w", raw, err)
	}
	if n == 0 {
		return Amount{}, fmt.Errorf("invalid amount %q: want more than zero", raw)
	}
	return Amount{n}, nil
}
```

The field is unexported, so code outside the package can't set it, and `ParseAmount` is the only way to get a nonzero `Amount`. Go can't forbid the zero value `Amount{}`, and code inside the package can still write `Amount{-5}`, so keep the package small.

```go
// Order is a Draft, Paid, Shipped or Cancelled order, each holding only its
// own data. The unexported method closes the set: no other package can add a case.
//
//sumtype:decl Order
type Order interface{ isOrder() }

type Draft struct{ ID string }

type Paid struct {
	ID     string
	Amount Amount
}

type Shipped struct {
	ID       string
	Amount   Amount
	Tracking string
}

type Cancelled struct{ ID string }

func (Draft) isOrder()     {}
func (Paid) isOrder()      {}
func (Shipped) isOrder()   {}
func (Cancelled) isOrder() {}

// RefundDue is the amount to refund on cancellation: only money that was taken.
func RefundDue(o Order) int64 {
	switch o := o.(type) {
	case Draft, Cancelled:
		return 0
	case Paid:
		return o.Amount.Cents()
	case Shipped:
		return o.Amount.Cents()
	}
	panic(fmt.Sprintf("RefundDue: unhandled order %T", o))
}
```

The Go compiler doesn't check a type switch for missing cases. The `gochecksumtype` linter (in `golangci-lint`) does: it reads the `//sumtype:decl` comment and reports any switch on `Order` that misses a case. Leave out `default`, since the linter counts a `default` as handling every case; the `panic` after the switch catches a nil `Order` at run time.

```go
// Accepts is the set of messages a state accepts, read from the transition table.
func Accepts(s orders.State) []orders.Event {
	return slices.Sorted(maps.Keys(orders.Transitions[s]))
}

// Typestate: each state type has a method for each message it accepts, and no other.
func (d Draft) Pay(a Amount) Paid           { return Paid{d.ID, a} }
func (d Draft) Cancel() Cancelled           { return Cancelled{d.ID} }
func (p Paid) Ship(tracking string) Shipped { return Shipped{p.ID, p.Amount, tracking} }
func (p Paid) Cancel() Cancelled            { return Cancelled{p.ID} }

// Cancellable is the set of states that accept cancel.
// Law: cancelling keeps the order's id.
type Cancellable interface{ Cancel() Cancelled }
```

A Go interface is a set of messages, and a type belongs to it by having the methods. So the method set of each state type is that state's messages: `draft.Ship(...)` doesn't compile, and `Cancellable` holds exactly `Draft` and `Paid`. Its law, not its signature, defines the set, and one property test runs the law against every member (below). The set is open: any type in any package with a `Cancel() Cancelled` method joins it; add an unexported method to the interface to close it. `Accepts` reads the same sets from the table instead of keeping a second list. Events that arrive as data, from a queue or a database, still go through `Step`.

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

The typed package gets the same kind of checks. Go has no standard way to test that a line doesn't compile, so the third test checks instead that each state type's methods are exactly the events the table accepts:

```go
func TestAcceptsMatchesStep(t *testing.T) {
	for _, s := range states {
		var allowed []orders.Event
		for _, e := range events {
			if _, err := orders.Step(s, e); err == nil {
				allowed = append(allowed, e)
			}
		}
		slices.Sort(allowed)
		if got := Accepts(s); !slices.Equal(got, allowed) {
			t.Errorf("%s: Accepts = %v, Step allows %v", s, got, allowed)
		}
	}
}

func TestParseAmountAcceptsPositiveWholeCents(t *testing.T) {
	digits := regexp.MustCompile(`^[0-9]+$`)
	rapid.Check(t, func(t *rapid.T) {
		raw := rapid.OneOf(rapid.String(), rapid.StringMatching(`[+-]?[0-9]{0,20}`)).Draw(t, "raw")
		n, isInt := new(big.Int).SetString(raw, 10)
		want := digits.MatchString(raw) && isInt && n.Sign() > 0 && n.IsInt64()
		if _, err := ParseAmount(raw); (err == nil) != want {
			t.Fatalf("ParseAmount(%q): err = %v, want ok = %v", raw, err, want)
		}
	})
	rapid.Check(t, func(t *rapid.T) {
		n := rapid.Int64Range(1, math.MaxInt64).Draw(t, "n")
		if a, err := ParseAmount(strconv.FormatInt(n, 10)); err != nil || a.Cents() != n {
			t.Fatalf("ParseAmount(%d) = %v, %v", n, a.Cents(), err)
		}
	})
}

func TestMethodsMatchTable(t *testing.T) {
	types := map[orders.State]Order{
		orders.Draft: Draft{}, orders.Paid: Paid{}, orders.Shipped: Shipped{}, orders.Cancelled: Cancelled{},
	}
	for s, o := range types {
		typ := reflect.TypeOf(o)
		var methods []orders.Event
		for i := range typ.NumMethod() {
			methods = append(methods, orders.Event(strings.ToLower(typ.Method(i).Name)))
		}
		slices.Sort(methods)
		if got := Accepts(s); !slices.Equal(methods, got) {
			t.Errorf("%T has methods %v, but the table accepts %v", o, methods, got)
		}
	}
}

// The law of Cancellable, run against every type in the set.
func TestCancelKeepsTheID(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		id := rapid.String().Draw(t, "id")
		amount, err := ParseAmount(strconv.FormatInt(rapid.Int64Range(1, math.MaxInt64).Draw(t, "cents"), 10))
		if err != nil {
			t.Fatal(err)
		}
		if !keepsID(Draft{id}, id) || !keepsID(Paid{id, amount}, id) {
			t.Fatalf("cancelling an order with id %q changed its id", id)
		}
	})
}

func keepsID[T Cancellable](o T, id string) bool { return o.Cancel().ID == id }
```

The parse property checks `ParseAmount` against an independent spec, `math/big` plus a regexp, over both arbitrary strings and strings that look like numbers, so signs, leading zeros and overflow all come up. `reflect` lists only exported methods, so the unexported `isOrder` doesn't count.

## Tooling

- Benchmark before deriving: `go test -bench . -benchmem`, then `go test -cpuprofile cpu.out` and `go tool pprof cpu.out`.
- `gofmt` and `go vet` on every change. `golangci-lint` if the project uses it.
