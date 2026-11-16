"""The code shown in skills/unix-philosophy/references/languages/python.md.
scripts/check-examples.py checks that the files in this folder and that
file stay the same."""


class ValidationError(ValueError):
    pass


def parse_signup(data):
    if not isinstance(data, dict) or "email" not in data:
        raise ValidationError("email is required")
    return {"email": data["email"]}


# Before: one view, four jobs
def signup_view(request): ...  # parse + validate + insert + email


def signup_after(request, user_repo, mailer):
    # After
    signup = parse_signup(request.json)   # raises ValidationError
    user = user_repo.create(signup)
    mailer.send_welcome(user)
    return user
