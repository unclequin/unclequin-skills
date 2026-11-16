package orders;

import java.time.YearMonth;
import java.util.EnumMap;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import java.util.function.Predicate;
import java.util.stream.IntStream;

/**
 * The code shown in skills/functional-first/references/languages/java.md.
 * scripts/check-examples.py checks that the two stay the same.
 */
public final class Orders {
    private Orders() {}

    public record Order(String id, long total, Optional<YearMonth> paidIn, boolean refunded) {}

    static Predicate<Order> paidIn(YearMonth month) {
        return o -> o.paidIn().equals(Optional.of(month));
    }

    static boolean isRefunded(Order o) {
        return o.refunded();
    }

    /** Revenue for a month is the sum of the totals of orders paid in that month,
     *  except refunded ones. A refund at any time excludes the order. */
    public static long monthlyRevenue(List<Order> orders, YearMonth month) {
        return orders.stream()
                .filter(paidIn(month))
                .filter(o -> !isRefunded(o))
                .mapToLong(Order::total)
                .sum();
    }

    /** Spec: twelve passes, one per month. */
    public static long[] revenueByMonthSpec(List<Order> orders, int year) {
        return IntStream.rangeClosed(1, 12)
                .mapToLong(m -> monthlyRevenue(orders, YearMonth.of(year, m)))
                .toArray();
    }

    /** Derived from revenueByMonthSpec by grouping instead of rescanning. */
    public static long[] revenueByMonth(List<Order> orders, int year) {
        long[] out = new long[12];
        for (Order o : orders) {
            if (o.paidIn().isPresent() && o.paidIn().get().getYear() == year && !isRefunded(o)) {
                out[o.paidIn().get().getMonthValue() - 1] += o.total();
            }
        }
        return out;
    }

    public enum State { DRAFT, PAID, SHIPPED, CANCELLED }
    public enum Event { PAY, SHIP, CANCEL }

    /** The whole lifecycle. A pair that isn't here is illegal. */
    public static final Map<State, Map<Event, State>> TRANSITIONS = new EnumMap<>(Map.of(
            State.DRAFT, Map.of(Event.PAY, State.PAID, Event.CANCEL, State.CANCELLED),
            State.PAID, Map.of(Event.SHIP, State.SHIPPED, Event.CANCEL, State.CANCELLED),
            State.SHIPPED, Map.of(),
            State.CANCELLED, Map.of()));

    public static final class IllegalTransitionException extends RuntimeException {
        IllegalTransitionException(State state, Event event) {
            super("cannot " + event + " an order that is " + state);
        }
    }

    public static State step(State state, Event event) {
        State next = TRANSITIONS.get(state).get(event);
        if (next == null) {
            throw new IllegalTransitionException(state, event);
        }
        return next;
    }

    /** Folds step over events. Throws at the first illegal one. */
    public static State replay(State start, List<Event> events) {
        State state = start;
        for (Event event : events) {
            state = step(state, event);
        }
        return state;
    }
}
