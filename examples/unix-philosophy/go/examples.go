// Package unixphil holds the code shown in
// skills/unix-philosophy/references/languages/go.md.
// scripts/check-examples.py checks that the two stay the same.
package unixphil

import (
	"bufio"
	"context"
	"database/sql"
	"encoding/json"
	"fmt"
	"io"
	"log"
	"os"
	"strconv"
	"time"
)

// Composable: works with files, HTTP bodies, strings, gzip streams, tests
func CountLines(r io.Reader) (int, error) {
	sc := bufio.NewScanner(r)
	n := 0
	for sc.Scan() {
		n++
	}
	return n, sc.Err()
}

type User struct{ ID string }

// Simple: concrete type in the producer; narrow interface at the consumer
type UserStore struct{ db *sql.DB }

// in package billing
type userGetter interface {
	Get(ctx context.Context, id string) (User, error)
}

type RetryPolicy struct {
	MaxAttempts int
	Backoff     time.Duration
}

// Do is the mechanism the reference file leaves as a comment.
func Do(ctx context.Context, p RetryPolicy, fn func() error) error {
	var err error
	for attempt := 1; attempt <= p.MaxAttempts; attempt++ {
		if err = fn(); err == nil {
			return nil
		}
		select {
		case <-ctx.Done():
			return ctx.Err()
		case <-time.After(p.Backoff):
		}
	}
	return err
}

var callPartner = func() error { return nil }

func retryPartner(ctx context.Context) error {
	err := Do(ctx, RetryPolicy{MaxAttempts: 3, Backoff: 200 * time.Millisecond}, callPartner)
	return err
}

func fetchOpaque(orderID string, fetch func(string) error) error {
	err := fetch(orderID)
	// Opaque
	if err != nil {
		return err
	}
	return nil
}

func fetchTransparent(orderID string, fetch func(string) error) error {
	err := fetch(orderID)
	// Transparent: says where and on what, keeps the cause for errors.Is/As
	if err != nil {
		return fmt.Errorf("fetch order %s: %w", orderID, err)
	}
	return nil
}

func portSilent() int {
	// Silent failure: port becomes 0
	port, _ := strconv.Atoi(os.Getenv("PORT"))
	return port
}

func portOrExit() int {
	// Fail fast at startup
	port, err := strconv.Atoi(os.Getenv("PORT"))
	if err != nil {
		log.Fatalf("invalid PORT %q: %v", os.Getenv("PORT"), err)
	}
	return port
}

var shippingFees = map[string]int{"BKK": 40, "CENTRAL": 60, "NORTH": 80}

func shippingFee(zone string) int {
	if fee, ok := shippingFees[zone]; ok {
		return fee
	}
	return 100
}

type Event struct {
	Version int             `json:"version"`
	Type    string          `json:"type"`
	Data    json.RawMessage `json:"data"`
}
