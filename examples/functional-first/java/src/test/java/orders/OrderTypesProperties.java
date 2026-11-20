package orders;

import static orders.OrderTypes.accepts;
import static orders.Orders.step;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.math.BigInteger;
import java.util.List;
import java.util.stream.Stream;
import net.jqwik.api.Arbitraries;
import net.jqwik.api.Arbitrary;
import net.jqwik.api.Example;
import net.jqwik.api.ForAll;
import net.jqwik.api.Property;
import net.jqwik.api.Provide;
import orders.OrderTypes.Amount;
import orders.OrderTypes.Draft;
import orders.OrderTypes.Paid;
import orders.Orders.Event;
import orders.Orders.IllegalTransitionException;
import orders.Orders.State;

class OrderTypesProperties {
    static boolean allows(State state, Event event) {
        try {
            step(state, event);
            return true;
        } catch (IllegalTransitionException e) {
            return false;
        }
    }

    @Example
    void aStateAcceptsExactlyTheEventsStepAllows() {
        for (State state : State.values()) {
            assertEquals(Stream.of(Event.values()).filter(e -> allows(state, e)).toList(), accepts(state));
        }
    }

    @Property
    void parseAcceptsExactlyThePositiveWholeNumbersOfCents(@ForAll("raw") String raw) {
        boolean digits = !raw.isEmpty() && raw.chars().allMatch(c -> c >= '0' && c <= '9');
        boolean valid = digits && new BigInteger(raw).signum() > 0 && new BigInteger(raw).bitLength() < 64;
        try {
            Amount amount = Amount.parse(raw);
            assertTrue(valid);
            assertEquals(new BigInteger(raw).longValueExact(), amount.cents());
        } catch (IllegalArgumentException e) {
            assertFalse(valid);
        }
    }

    @Provide
    Arbitrary<String> raw() {
        return Arbitraries.oneOf(Arbitraries.strings(), Arbitraries.longs().map(String::valueOf),
                Arbitraries.strings().numeric().ofMaxLength(25));
    }

    @Example
    void refundDueIsTheMoneyTaken() {
        Draft draft = new Draft("o1");
        Paid paid = draft.pay(Amount.parse("500"));
        assertEquals(List.of(0L, 500L, 500L, 0L),
                Stream.of(draft, paid, paid.ship("T1"), paid.cancel()).map(OrderTypes::refundDue).toList());
    }
}
