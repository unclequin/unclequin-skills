// Package order holds the typed lifecycle shown in
// skills/functional-first/references/languages/go.md, beside package orders.
// scripts/check-examples.py checks that the two stay the same.
package order

import (
	"fmt"
	"maps"
	"slices"
	"strconv"
	"strings"

	"example.com/orders"
)

// Before: three flags and two optional fields allow 2³ combinations of flags,
// each with or without an amount and a tracking number. Four are legal.
type Record struct {
	Paid      bool
	Shipped   bool
	Cancelled bool
	Amount    *int64  // nil until paid
	Tracking  *string // nil until shipped
}

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
type Cancellable interface{ Cancel() Cancelled }
