package orders

import (
	"math/rand/v2"
	"testing"
	"time"
)

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
