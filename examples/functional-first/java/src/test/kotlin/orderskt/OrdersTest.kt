package orderskt

import java.time.YearMonth
import org.junit.jupiter.api.Assertions.assertEquals
import org.junit.jupiter.api.Assertions.assertTrue
import org.junit.jupiter.api.Test

class OrdersTest {
    private val march = YearMonth.of(2024, 3)

    @Test
    fun `revenue leaves out refunded and unpaid orders`() {
        val orders = listOf(
            Order("a", 100, march, false),
            Order("b", 50, march, true),
            Order("c", 20, null, false),
            Order("d", 5, YearMonth.of(2025, 3), false),
        )
        assertEquals(100, monthlyRevenue(orders, march))
    }

    @Test
    fun `step follows the table for every pair`() {
        for (state in State.entries) {
            for (event in Event.entries) {
                val result = step(state, event)
                assertEquals(transitions[state to event], result.getOrNull())
                assertEquals((state to event) in transitions, result.isSuccess)
            }
        }
        assertTrue(State.entries.none { (it to Event.PAY) in transitions && it != State.DRAFT })
    }
}
