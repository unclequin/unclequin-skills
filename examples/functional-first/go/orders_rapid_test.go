package orders

import (
	"testing"
	"time"

	"pgregory.net/rapid"
)

func genOrder(t *rapid.T) Order {
	o := Order{
		Total:    rapid.Int64Range(0, 1000).Draw(t, "total"),
		Refunded: rapid.Bool().Draw(t, "refunded"),
	}
	if rapid.Bool().Draw(t, "paid") {
		o.PaidIn = &YearMonth{
			Year:  rapid.IntRange(2024, 2025).Draw(t, "year"),
			Month: time.Month(rapid.IntRange(1, 12).Draw(t, "month")),
		}
	}
	return o
}

func TestRevenueByMonthMatchesSpecRapid(t *testing.T) {
	rapid.Check(t, func(t *rapid.T) {
		orders := rapid.SliceOfN(rapid.Custom(genOrder), 0, 20).Draw(t, "orders")
		if got, want := RevenueByMonth(orders, 2024), RevenueByMonthSpec(orders, 2024); got != want {
			t.Fatalf("got %v, want %v", got, want)
		}
	})
}
