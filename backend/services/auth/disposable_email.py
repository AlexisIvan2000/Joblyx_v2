from disposable_email_domains import blocklist

_DISPOSABLE_DOMAINS = frozenset(blocklist)


def is_disposable_email(email: str) -> bool:
    domain = email.rsplit("@", 1)[-1].strip().lower()
    return domain in _DISPOSABLE_DOMAINS
