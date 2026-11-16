from typing import Protocol
from dataclasses import dataclass


@dataclass(frozen=True)
class User:
    user_id: str
    name: str


@dataclass(frozen=True)
class Invoice:
    billed_to: str


class UserGetter(Protocol):
    def get(self, user_id: str) -> User: ...


def make_invoice(users: UserGetter, user_id: str) -> Invoice:
    return Invoice(billed_to=users.get(user_id).name)
