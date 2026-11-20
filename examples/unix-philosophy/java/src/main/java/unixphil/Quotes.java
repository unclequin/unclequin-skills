package unixphil;

import java.util.Map;
import java.util.Optional;

final class Quotes {
    private Quotes() {}

    /** Version 1 of the quote request. */
    record QuoteV1(String sku, int quantity) {}

    /** Version 2 adds an optional coupon; every QuoteV1 converts to a QuoteV2 with none. */
    record QuoteV2(String sku, int quantity, Optional<String> coupon) {
        static QuoteV2 from(QuoteV1 q) {
            return new QuoteV2(q.sku(), q.quantity(), Optional.empty());
        }
    }

    static final Map<String, Integer> PRICES = Map.of("apple", 100, "pear", 150);
    private static final Map<String, Integer> PERCENT_OFF = Map.of("TENOFF", 10);

    private static int lookup(Map<String, Integer> table, String key, String what) {
        Integer value = table.get(key);
        if (value == null) {
            throw new IllegalArgumentException("unknown " + what + ": " + key);
        }
        return value;
    }

    static int quoteV1(QuoteV1 q) {
        return lookup(PRICES, q.sku(), "sku") * q.quantity();
    }

    static int quoteV2(QuoteV2 q) {
        int total = lookup(PRICES, q.sku(), "sku") * q.quantity();
        return q.coupon()
            .map(coupon -> total - total * lookup(PERCENT_OFF, coupon, "coupon") / 100)
            .orElse(total);
    }
}
