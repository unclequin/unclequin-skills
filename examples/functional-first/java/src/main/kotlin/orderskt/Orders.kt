// The Kotlin code shown in skills/functional-first/references/languages/java.md.
// scripts/check-examples.py checks that the two stay the same.
package orderskt

import java.time.YearMonth

data class Order(val id: String, val total: Long, val paidIn: YearMonth?, val refunded: Boolean)

fun paidIn(month: YearMonth): (Order) -> Boolean = { it.paidIn == month }
val isRefunded: (Order) -> Boolean = { it.refunded }

fun monthlyRevenue(orders: List<Order>, month: YearMonth): Long =
    orders.filter(paidIn(month)).filterNot(isRefunded).sumOf { it.total }

enum class State { DRAFT, PAID, SHIPPED, CANCELLED }
enum class Event { PAY, SHIP, CANCEL }

val transitions: Map<Pair<State, Event>, State> = mapOf(
    (State.DRAFT to Event.PAY) to State.PAID,
    (State.DRAFT to Event.CANCEL) to State.CANCELLED,
    (State.PAID to Event.SHIP) to State.SHIPPED,
    (State.PAID to Event.CANCEL) to State.CANCELLED,
)

fun step(state: State, event: Event): Result<State> =
    transitions[state to event]?.let { Result.success(it) }
        ?: Result.failure(IllegalStateException("cannot $event an order that is $state"))
