package unixphil;

import java.util.Objects;

final class Config {
    final int port;

    Config() {
        // Fail fast in constructors and at startup
        this.port = Integer.parseInt(Objects.requireNonNull(System.getenv("PORT"), "PORT is required"));
    }
}
