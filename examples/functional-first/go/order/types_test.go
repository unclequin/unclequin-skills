package order

import (
	"math"
	"math/big"
	"reflect"
	"regexp"
	"slices"
	"strconv"
	"strings"
	"testing"

	"example.com/orders"
	"pgregory.net/rapid"
)

var (
	states = []orders.State{orders.Draft, orders.Paid, orders.Shipped, orders.Cancelled}
	events = []orders.Event{orders.Pay, orders.Ship, orders.Cancel}
)

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

// Go can't test that draft.Ship doesn't compile, so check instead that each
// state type has a method for exactly the messages the table accepts.
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

func TestRefundDue(t *testing.T) {
	amount, err := ParseAmount("500")
	if err != nil {
		t.Fatal(err)
	}
	paid := Draft{"o1"}.Pay(amount)
	for _, c := range []struct {
		order Order
		want  int64
	}{{Draft{"o1"}, 0}, {paid, 500}, {paid.Ship("T1"), 500}, {paid.Cancel(), 0}} {
		if got := RefundDue(c.order); got != c.want {
			t.Errorf("RefundDue(%+v) = %d, want %d", c.order, got, c.want)
		}
	}
}
