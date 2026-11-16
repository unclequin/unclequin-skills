package unixphil;

import java.util.ArrayList;
import java.util.List;

/**
 * The code shown in skills/unix-philosophy/references/languages/java.md.
 * scripts/check-examples.py checks that the files in this folder and that
 * file stay the same.
 */
final class SignupHandler {
    record Signup(String email) {}

    record User(String email) {}

    static final class ValidationException extends RuntimeException {
        private static final long serialVersionUID = 1L;

        ValidationException(String message) {
            super(message);
        }
    }

    static final class SignupParser {
        static Signup parse(String request) {
            if (!request.contains("@")) {
                throw new ValidationException("not an email address: " + request);
            }
            return new Signup(request);
        }
    }

    static final class UserRepository {
        User create(Signup signup) {
            return new User(signup.email());
        }
    }

    static final class Mailer {
        final List<String> welcomed = new ArrayList<>();

        void sendWelcome(User user) {
            welcomed.add(user.email());
        }
    }

    final UserRepository userRepository = new UserRepository();
    final Mailer mailer = new Mailer();

    void handle(String request) {
        // After splitting
        Signup signup = SignupParser.parse(request);   // throws ValidationException
        User user = userRepository.create(signup);
        mailer.sendWelcome(user);
    }
}
