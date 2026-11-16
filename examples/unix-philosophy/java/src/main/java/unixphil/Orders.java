package unixphil;

import java.io.IOException;

final class Orders {
    record Order(String id) {}

    static final class OrderFetchException extends RuntimeException {
        private static final long serialVersionUID = 1L;

        OrderFetchException(String message, Throwable cause) {
            super(message, cause);
        }
    }

    static final class Client {
        Order fetch(String orderId) throws IOException {
            if (orderId.equals("missing")) {
                throw new IOException("connection refused");
            }
            return new Order(orderId);
        }
    }

    final Client client = new Client();

    Order fetchOpaque(String orderId) {
        Order order = null;
        // Opaque and silent
        try { order = client.fetch(orderId); } catch (Exception e) { }
        return order;
    }

    Order fetchTransparent(String orderId) {
        Order order;
        // Transparent: specific exception, context, original cause
        try {
            order = client.fetch(orderId);
        } catch (IOException e) {
            throw new OrderFetchException("fetch order " + orderId, e);
        }
        return order;
    }
}
