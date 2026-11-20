# Go Idioms for the Unix Philosophy

Go was co-created by Rob Pike and Ken Thompson, so it embodies many of these rules directly. Follow Effective Go and the Go Code Review Comments guide.

## Composition: accept small standard interfaces

```go
// Hard to compose: only works with files on disk
func CountLines(path string) (int, error)

// Composable: works with files, HTTP bodies, strings, gzip streams, tests
func CountLines(r io.Reader) (int, error) {
	sc := bufio.NewScanner(r)
	n := 0
	for sc.Scan() {
		n++
	}
	return n, sc.Err()
}
```

Standard interfaces to reach for: `io.Reader`, `io.Writer`, `io.Closer`, `fmt.Stringer`, `http.Handler`, `sort.Interface`, `iter.Seq`.

## Simplicity: small interfaces, defined by the consumer

"Accept interfaces, return structs." Define an interface in the package that *uses* it, with only the methods that package needs.

```go
// Over-engineered: producer-side interface mirroring every method
type UserService interface { Create(...); Get(...); Update(...); Delete(...); List(...) }

// Simple: concrete type in the producer; narrow interface at the consumer
type UserStore struct{ db *sql.DB }

// in package billing
type userGetter interface {
	Get(ctx context.Context, id string) (User, error)
}
```

## Separation: policy as parameters

```go
type RetryPolicy struct {
	MaxAttempts int
	Backoff     time.Duration
}

func Do(ctx context.Context, p RetryPolicy, fn func() error) error { /* mechanism only */ }

err := Do(ctx, RetryPolicy{MaxAttempts: 3, Backoff: 200 * time.Millisecond}, callPartner)
```

## Transparency and Repair: wrap errors, fail fast

```go
// Opaque
if err != nil {
	return err
}

// Transparent: says where and on what, keeps the cause for errors.Is/As
if err != nil {
	return fmt.Errorf("fetch order %s: %w", orderID, err)
}
```

```go
// Silent failure: port becomes 0
port, _ := strconv.Atoi(os.Getenv("PORT"))

// Fail fast at startup
port, err := strconv.Atoi(os.Getenv("PORT"))
if err != nil {
	log.Fatalf("invalid PORT %q: %v", os.Getenv("PORT"), err)
}
```

Red flags: `_ = err`, `panic` for expected errors, `recover()` that hides bugs. Use `log/slog` for structured logs.

## Representation: maps and tables

```go
var shippingFees = map[string]int{"BKK": 40, "CENTRAL": 60, "NORTH": 80}

func shippingFee(zone string) int {
	if fee, ok := shippingFees[zone]; ok {
		return fee
	}
	return 100
}
```

Table-driven tests are the same rule applied to testing.

## Least Surprise: Go conventions

- Return `(value, error)`; error last.
- `context.Context` is the first parameter.
- Make the zero value useful.
- `gofmt` everything; no stutter in names (`user.User` is fine, `user.UserService` stutters).
- `Close()` should be safe to call more than once where practical.

## Silence

CLIs write results to `os.Stdout`, diagnostics to `os.Stderr`, and exit with `os.Exit(1)` on failure. No log lines on the success path.

## Generation

`go generate` with `stringer`, `mockgen` or `moq`, `sqlc`, `oapi-codegen`, `protoc-gen-go`. Generated files start with `// Code generated ... DO NOT EDIT.`

## Optimization

Write `BenchmarkXxx` tests, run `go test -bench . -benchmem`, compare with `benchstat`, profile with `pprof`.

## Extensibility

```go
type Event struct {
	Version int             `json:"version"`
	Type    string          `json:"type"`
	Data    json.RawMessage `json:"data"`
}
```

Use functional options or a config struct only when there are genuinely many optional settings.

A version may add to the set of messages it accepts, never take from it:

```go
// QuoteV1 is version 1 of the quote request.
type QuoteV1 struct {
	SKU      string `json:"sku"`
	Quantity int    `json:"quantity"`
}

// QuoteV2 embeds QuoteV1 and adds an optional coupon; "" means none.
type QuoteV2 struct {
	QuoteV1
	Coupon string `json:"coupon,omitempty"`
}
```

```go
func quoteV1(q QuoteV1) (int, error) {
	price, err := lookup(prices, q.SKU, "sku")
	if err != nil {
		return 0, err
	}
	return price * q.Quantity, nil
}

func quoteV2(q QuoteV2) (int, error) {
	price, err := lookup(prices, q.SKU, "sku")
	if err != nil {
		return 0, err
	}
	total := price * q.Quantity
	if q.Coupon == "" {
		return total, nil
	}
	off, err := lookup(percentOff, q.Coupon, "coupon")
	if err != nil {
		return 0, err
	}
	return total - total*off/100, nil
}
```

Because `QuoteV2` embeds `QuoteV1`, the compiler checks half the rule: `QuoteV2{QuoteV1: q}` turns every version 1 request into a version 2 one, and the embedded fields decode from the same JSON. A test checks the other half, that each gets the same answer, with the old handler kept as the spec:

```go
func TestVersion2AnswersEveryVersion1RequestTheSame(t *testing.T) {
	for sku := range prices {
		for quantity := 1; quantity <= 100; quantity++ {
			q := QuoteV1{SKU: sku, Quantity: quantity}
			got, gotErr := quoteV2(QuoteV2{QuoteV1: q})
			want, wantErr := quoteV1(q)
			if got != want || (gotErr == nil) != (wantErr == nil) {
				t.Fatalf("%+v: got %d, %v; want %d, %v", q, got, gotErr, want, wantErr)
			}
		}
	}
}
```

Renaming `Quantity` would stop the test compiling. Making the coupon required has no type to break in Go, so it shows up as a failing test once `quoteV2` rejects `""`. Either is the signal for a new major version, served beside the old one.
