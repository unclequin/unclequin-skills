# Types: Sets of Values, Sets of Messages

Read this when the model from step 2 has to become types: when you design a domain type, replace flags or nullable fields, decide what a function accepts, or define what an object or process will answer. The sets and the transition table from `modeling.md` are the input; this file says how to make the compiler hold them.

## Contents

- A type names a set
- Narrow once, keep the narrowing
- "Or" is a sum, "and" is a product
- An interface is a set of messages
- When the state decides the messages
- Observe, don't inspect
- Where the set view stops
- Sources

---

## A type names a set

Read every type as the set of values it allows. `string` is every string; `"draft" | "paid"` is two of them. A design is right when the type's set and the domain's set are the same. Each value the type allows but the domain forbids is a case some function must check for, and some function will forget.

Pick the smallest set that is still honest: one that holds every legal value and nothing else. Count to check. Three booleans `paid`, `shipped`, `cancelled` allow 2³ = 8 combinations; the lifecycle has four states. Four of the eight are bugs waiting for an input.

When the name does not make the set obvious, say it in the type's doc comment: "an amount in cents, greater than zero".

## Narrow once, keep the narrowing

Every predicate from step 2 selects a subset. When later code depends on that subset, give it a type: a newtype or wrapper class whose only constructor runs the check, a branded type, or a narrowed union. The check then happens once, and the type carries the result to every function downstream, which can no longer be called with the unchecked value.

Do the narrowing at the boundary. The shell turns raw input (a string from a form, a JSON body, a database row) into the narrowest type the core needs, or into an error that says what was wrong. The core's functions take only narrow types, so they never re-check and never meet the case they forgot. A check that returns `true` or `false` throws away what it learned; a function that returns the narrow type or an error keeps it.

## "Or" is a sum, "and" is a product

The domain sentence from step 1 maps onto the shape of the data:

| Spoken | Set | Type |
|--------|-----|------|
| "an order is draft, paid, shipped, or cancelled" | disjoint union | a sum: tagged union, enum with data, sealed hierarchy |
| "a shipment has an address and a tracking number" | Cartesian product | a product: record, struct, tuple |
| "a paid order has an amount" | data that exists only in one case | the field lives inside that case, not beside the tag |
| "any status except cancelled" | difference | a narrower union, or a negation type where the language has one |

Sizes add for sums and multiply for products, so moving a field into the one case that has it shrinks the set to the legal values. Data that only some states carry is the most common illegal state: `trackingNumber: string | null` beside a status field allows a shipped order with no tracking number and a draft with one.

Make every case analysis over a sum exhaustive, with the language's check (a `never` default, match warnings as errors, a sealed type). Adding a case is then a compile error at every decision that must handle it, not a silent fall-through.

## An interface is a set of messages

An object, a process, or a module's public API is described from outside by the messages it accepts and what it answers to each. Its fields are not part of the description. Callers depend on that set alone, so the inside can change while the set stays the same.

Write the set down once:

- In OOP code, the message set is the interface's methods, or a sealed hierarchy of command types when commands are values.
- For a process or actor, it is one union type of every message it handles, beside its receive loop or its `handle_call` clauses.
- For a lifecycle, the events in the transition table are the messages, and the table says which are accepted in each state: `accepts(s) = { e | (s, e) ∈ table }`. Compute it from the table, never keep a second list.

A trait, interface, protocol, or type class turns this around: it names the set of types that answer its messages. `T: Cancel` reads "T is one of the types that accept `cancel`". The signatures alone don't define the set, because two types can share a signature and behave differently. The trait's laws do: `cancel` keeps the order's id, equality is reflexive and symmetric, an ordering is total. Write each law in the trait's doc comment, and check it with one property test run against every implementation, so a new implementation joins the set only by passing it.

A subtype must be safe wherever its parent is used: it accepts at least the messages the parent accepts, and its answers stay within what the parent promised. A subclass that throws on an inherited method, or narrows what it accepts, breaks every caller that relied on the parent.

Choose whether the set is open or closed. An open trait or interface lets any code add a member, which suits a plug-in point. A closed one (sealed, or not exported for others to implement) fixes the members, which suits states and other domain cases, where an outside member would be a state the table doesn't know.

## When the state decides the messages

In a lifecycle, the legal messages change with the state: a draft accepts `pay` and `cancel`, a shipped order accepts nothing. Two ways to enforce it:

1. **At run time, from the table.** `step(state, event)` rejects any pair the table lacks. This works in every language and is the default.
2. **At compile time, by typestate.** Give each state its own type, and give each type only the operations its state accepts: `ship` exists on a paid order and nowhere else. Calling an illegal message is then a type error. Use it where the language expresses it plainly: one type per state, phantom type parameters, or a type indexed by the state. Keep the transition table as the source of truth and the run-time `step` beside it, since histories replayed from storage arrive as data, not as typed calls.

Use typestate for a lifecycle that callers drive step by step in code. For one driven by events from outside (messages from a queue, rows from a database), the run-time table is enough.

## Observe, don't inspect

Two objects with the same answers to every message are the same, whatever their fields hold. So test an object or process by sending it messages and checking its answers, and test a lifecycle by replaying events through `step` and checking what it accepts and rejects. A test that reads private fields fails when the representation changes and the behavior did not.

The laws worth testing:

- `accepts(s)` is exactly the set of events `e` for which `step(s, e)` succeeds.
- A terminal state accepts the empty set.
- Every implementation of a trait or interface passes the trait's laws: one property, run against each member of the set.
- The narrow type's constructor accepts exactly the values the predicate allows: everything it accepts satisfies the predicate, and everything it rejects fails it.

## Where the set view stops

"A type is a set of values" is a sound guide for data: records, unions, literals, enums, refinements. It is not a sound model for functions that are generic over all types: a generic `map` is not "the set of all functions" of its type. For generics, reason from what the function cannot know (it can't inspect a value of an unknown type), not from sets.

## Sources

In our own words, from these works:

- Luca Cardelli and Peter Wegner, "On Understanding Types, Data Abstraction, and Polymorphism" (1985): types as sets of values, subtyping as inclusion.
- John Reynolds, "Polymorphism is not set-theoretic" (1984): where the set view stops.
- Alain Frisch, Giuseppe Castagna and Véronique Benzaken, "Semantic subtyping" (2008), and Giuseppe Castagna, Guillaume Duboc and José Valim, "The Design Principles of the Elixir Type System" (2024): types built from union, intersection and negation.
- Philip Wadler, "Propositions as Types" (2015): products as "and", sums as "or".
- Yaron Minsky, "Effective ML Revisited" (2011): make illegal states unrepresentable.
- Alexis King, "Parse, don't validate" (2019).
- Alan Kay, "The Early History of Smalltalk" (1993): objects communicate by messages.
- William Cook, "On Understanding Data Abstraction, Revisited" (2009): an object is known by the observations it supports.
- Barbara Liskov and Jeannette Wing, "A Behavioral Notion of Subtyping" (1994).
- Robert Strom and Shaula Yemini, "Typestate" (1986); Kohei Honda, session types (1993).

Details and verification notes: https://github.com/unclequin/unclequin-skills/blob/main/docs/research/types-sets-and-messages.md
