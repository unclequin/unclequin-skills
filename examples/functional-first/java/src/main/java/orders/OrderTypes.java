package orders;

import java.util.List;
import java.util.Optional;
import java.util.stream.Stream;
import orders.Orders.Event;
import orders.Orders.State;

import static orders.Orders.TRANSITIONS;

/** The types section of skills/functional-first/references/languages/java.md. */
public final class OrderTypes {
    private OrderTypes() {}

    // Before: three flags and two optional fields allow 2³ combinations of flags,
    // each with or without an amount and a tracking number. Four are legal.
    public record OrderRecord(boolean paid, boolean shipped, boolean cancelled,
            Optional<Long> amount, Optional<String> tracking) {}

    /** An amount in integer cents, greater than zero. */
    public record Amount(long cents) {
        public Amount {
            if (cents <= 0) {
                throw new IllegalArgumentException("amount must be positive: " + cents);
            }
        }

        /** Parses raw input at the boundary; the core takes only Amount. */
        public static Amount parse(String raw) {
            if (!raw.matches("[0-9]+")) {
                throw new IllegalArgumentException("invalid amount: \"" + raw + "\"");
            }
            // parseLong rejects values too large for a long; the constructor rejects zero.
            return new Amount(Long.parseLong(raw));
        }
    }

    // After: one type per state, each holding only its own data.
    // A state's methods are the messages it accepts.
    public sealed interface Order permits Draft, Paid, Shipped, Cancelled {}

    public record Draft(String id) implements Order, Cancellable {
        public Paid pay(Amount amount) {
            return new Paid(id, amount);
        }
    }

    public record Paid(String id, Amount amount) implements Order, Cancellable {
        public Shipped ship(String tracking) {
            return new Shipped(id, amount, tracking);
        }
    }

    public record Shipped(String id, Amount amount, String tracking) implements Order {}

    public record Cancelled(String id) implements Order {}

    /** The amount to refund on cancellation: only money that was taken. */
    public static long refundDue(Order order) {
        return switch (order) {
            case Draft d -> 0;
            case Cancelled c -> 0;
            case Paid p -> p.amount().cents();
            case Shipped s -> s.amount().cents();
        };
    }

    /** The states that accept cancel. Law: cancelling keeps the order's id. */
    public sealed interface Cancellable permits Draft, Paid {
        String id();

        default Cancelled cancel() {
            return new Cancelled(id());
        }
    }

    /** The messages a state accepts, read from the transition table. */
    public static List<Event> accepts(State state) {
        return Stream.of(Event.values()).filter(TRANSITIONS.get(state)::containsKey).toList();
    }
}
