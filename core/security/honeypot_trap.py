import random

try:
    from termcolor import colored
except ImportError:  # pragma: no cover
    def colored(text, *_args, **_kwargs):
        return text


class BursaHoneypot:
    """Passive quarantine simulator. No external traffic shaping or retaliation is performed."""

    def __init__(self):
        self.trap_active = True

    def deploy_fake_data(self, attacker_ip):
        print(colored(f"[HONEYPOT] {attacker_ip} quarantine kanalina alindi.", "yellow"))
        fake_price = random.uniform(10000, 90000)
        payload = {
            "status": "quarantined",
            "symbol": "BTCUSDT",
            "price": round(fake_price, 2),
            "mode": "dry_run",
        }
        print(f"[TRAP] Izole canary payload hazirlandi: {payload}")
        return payload


if __name__ == "__main__":
    trap = BursaHoneypot()
    print(trap.deploy_fake_data("185.122.45.10"))
