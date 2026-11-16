package unixphil;

import java.time.Duration;
import java.util.function.Supplier;

final class Partner {
    record RetryPolicy(int maxAttempts, Duration backoff) {}

    int calls = 0;
    int failures = 0;

    /** The mechanism the reference file leaves as a comment. */
    <T> T withRetry(RetryPolicy policy, Supplier<T> action) {
        for (int attempt = 1; ; attempt++) {
            try {
                return action.get();
            } catch (RuntimeException e) {
                if (attempt >= policy.maxAttempts()) {
                    throw e;
                }
                try {
                    Thread.sleep(policy.backoff());
                } catch (InterruptedException interrupted) {
                    Thread.currentThread().interrupt();
                    throw e;
                }
            }
        }
    }

    String callPartner() {
        calls++;
        if (calls <= failures) {
            throw new IllegalStateException("partner is down");
        }
        return "ok";
    }

    void run() {
        withRetry(new RetryPolicy(3, Duration.ofMillis(200)), this::callPartner);
    }
}
