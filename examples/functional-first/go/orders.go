// Package orders holds the code shown in
// skills/functional-first/references/languages/go.md.
// scripts/check-examples.py checks that the two stay the same.
package orders

import (
	"fmt"
	"time"
)

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
