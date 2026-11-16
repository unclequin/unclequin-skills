package unixphil;

import java.util.stream.Stream;

final class LineCounter {
    // Composable: works with files, network streams, test data
    long countLines(Stream<String> lines) {
        return lines.count();
    }
    // caller: try (var lines = Files.lines(path)) { countLines(lines); }
}
