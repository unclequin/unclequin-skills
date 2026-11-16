package unixphil;

enum Zone {
    BKK(40), CENTRAL(60), NORTH(80);
    final int fee;
    Zone(int fee) { this.fee = fee; }
}
