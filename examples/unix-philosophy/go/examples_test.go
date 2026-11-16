package unixphil

import (
	"context"
	"encoding/json"
	"errors"
	"strings"
	"testing"
)

func TestCountLines(t *testing.T) {
	n, err := CountLines(strings.NewReader("a\nb\nc\n"))
	if err != nil || n != 3 {
		t.Fatalf("got %d, %v; want 3, nil", n, err)
	}
}

func TestRetryStopsAtMaxAttempts(t *testing.T) {
	calls := 0
	failing := errors.New("down")
	callPartner = func() error { calls++; return failing }
	defer func() { callPartner = func() error { return nil } }()
	if err := retryPartner(context.Background()); !errors.Is(err, failing) || calls != 3 {
		t.Fatalf("got %v after %d calls; want the failure after 3", err, calls)
	}
}

func TestWrappedErrorKeepsCauseAndContext(t *testing.T) {
	cause := errors.New("timeout")
	fetch := func(string) error { return cause }
	if err := fetchOpaque("o1", fetch); err != cause {
		t.Fatalf("opaque: got %v", err)
	}
	err := fetchTransparent("o1", fetch)
	if !errors.Is(err, cause) || err.Error() != "fetch order o1: timeout" {
		t.Fatalf("transparent: got %v", err)
	}
}

func TestPort(t *testing.T) {
	t.Setenv("PORT", "eighty")
	if got := portSilent(); got != 0 {
		t.Fatalf("silent: got %d, want the silent 0", got)
	}
	t.Setenv("PORT", "8080")
	if got := portOrExit(); got != 8080 {
		t.Fatalf("got %d, want 8080", got)
	}
}

func TestShippingFee(t *testing.T) {
	for zone, want := range map[string]int{"BKK": 40, "NORTH": 80, "MARS": 100} {
		if got := shippingFee(zone); got != want {
			t.Errorf("%s: got %d, want %d", zone, got, want)
		}
	}
}

func TestEventKeepsUnknownData(t *testing.T) {
	var e Event
	in := `{"version":2,"type":"paid","data":{"new_field":1}}`
	if err := json.Unmarshal([]byte(in), &e); err != nil {
		t.Fatal(err)
	}
	out, err := json.Marshal(e)
	if err != nil || string(out) != in {
		t.Fatalf("got %s, %v", out, err)
	}
}
