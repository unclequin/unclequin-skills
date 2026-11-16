package orders;

import static orders.Orders.TRANSITIONS;
import static orders.Orders.revenueByMonth;
import static orders.Orders.revenueByMonthSpec;
import static orders.Orders.step;
import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.YearMonth;
import java.util.List;
import java.util.Optional;
import net.jqwik.api.Arbitraries;
import net.jqwik.api.Arbitrary;
import net.jqwik.api.Combinators;
import net.jqwik.api.ForAll;
import net.jqwik.api.Property;
import net.jqwik.api.Provide;
import net.jqwik.api.constraints.Size;
import orders.Orders.Event;
import orders.Orders.IllegalTransitionException;
import orders.Orders.Order;
import orders.Orders.State;

class OrdersProperties {
    @Property
    void derivedEqualsSpec(@ForAll("orders") List<Order> orders) {
        assertArrayEquals(revenueByMonthSpec(orders, 2024), revenueByMonth(orders, 2024));
    }

    @Provide
    Arbitrary<List<Order>> orders() {
        Arbitrary<Optional<YearMonth>> paid = Combinators.combine(
                Arbitraries.integers().between(2024, 2025), Arbitraries.integers().between(1, 12))
            .as(YearMonth::of).optional();
        return Combinators.combine(Arbitraries.strings().ofMaxLength(3),
                Arbitraries.longs().between(0, 1000), paid, Arbitraries.of(true, false))
            .as(Order::new).list().ofMaxSize(20);
    }

    @Property
    void lifecycleInvariants(@ForAll @Size(max = 8) List<Event> events) {
        State state = State.DRAFT;
        for (Event event : events) {
            boolean allowed = TRANSITIONS.get(state).containsKey(event);
            try {
                State next = step(state, event);
                assertTrue(allowed);
                state = next;
            } catch (IllegalTransitionException e) {
                assertFalse(allowed);
            }
        }
    }
}
