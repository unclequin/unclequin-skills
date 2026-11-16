package unixphil;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import java.io.IOException;
import java.util.List;
import java.util.stream.Stream;
import org.junit.jupiter.api.Test;

class ExamplesTest {
    @Test
    void signupParsesCreatesThenMails() {
        SignupHandler handler = new SignupHandler();
        handler.handle("a@b.c");
        assertThrows(SignupHandler.ValidationException.class, () -> handler.handle("nobody"));
        assertEquals(List.of("a@b.c"), handler.mailer.welcomed);
    }

    @Test
    void countLinesTakesAnyStream() {
        assertEquals(3, new LineCounter().countLines(Stream.of("a", "b", "c")));
    }

    @Test
    void withRetryGivesUpAfterMaxAttempts() {
        Partner recovering = new Partner();
        recovering.failures = 2;
        recovering.run();
        assertEquals(3, recovering.calls);

        Partner down = new Partner();
        down.failures = 3;
        assertThrows(IllegalStateException.class, down::run);
        assertEquals(3, down.calls);
    }

    @Test
    void transparentErrorKeepsContextAndCause() {
        Orders orders = new Orders();
        assertNull(orders.fetchOpaque("missing"));
        var thrown = assertThrows(Orders.OrderFetchException.class, () -> orders.fetchTransparent("missing"));
        assertEquals("fetch order missing", thrown.getMessage());
        assertInstanceOf(IOException.class, thrown.getCause());
        assertEquals("o1", orders.fetchTransparent("o1").id());
    }

    @Test
    void missingPortFailsInTheConstructor() {
        var thrown = assertThrows(NullPointerException.class, Config::new);
        assertEquals("PORT is required", thrown.getMessage());
    }

    @Test
    void zonesCarryTheirFee() {
        assertEquals(List.of(40, 60, 80), Stream.of(Zone.values()).map(zone -> zone.fee).toList());
    }
}
