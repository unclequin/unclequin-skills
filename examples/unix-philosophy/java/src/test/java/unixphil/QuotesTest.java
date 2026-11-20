package unixphil;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static unixphil.Quotes.PRICES;
import static unixphil.Quotes.quoteV1;
import static unixphil.Quotes.quoteV2;

import java.util.Optional;
import org.junit.jupiter.api.Test;
import unixphil.Quotes.QuoteV1;
import unixphil.Quotes.QuoteV2;

class QuotesTest {
    @Test
    void version2AnswersEveryVersion1RequestTheSame() {
        for (String sku : PRICES.keySet()) {
            for (int quantity = 1; quantity <= 100; quantity++) {
                var q = new QuoteV1(sku, quantity);
                assertEquals(quoteV1(q), quoteV2(QuoteV2.from(q)));
            }
        }
    }

    @Test
    void version2sNewFieldChangesOnlyTheNewRequests() {
        assertEquals(405, quoteV2(new QuoteV2("pear", 3, Optional.of("TENOFF"))));
        var thrown = assertThrows(IllegalArgumentException.class,
            () -> quoteV2(new QuoteV2("pear", 3, Optional.of("BOGUS"))));
        assertEquals("unknown coupon: BOGUS", thrown.getMessage());
        assertThrows(IllegalArgumentException.class, () -> quoteV1(new QuoteV1("plum", 1)));
    }
}
