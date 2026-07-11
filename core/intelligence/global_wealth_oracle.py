import time

try:
    from termcolor import colored
except ImportError:  # pragma: no cover
    def colored(text, *_args, **_kwargs):
        return text


class BursaWealthOracle:
    """Aggregates digital and physical holdings into a single estimate."""

    def __init__(self):
        self.crypto_balance = 0.0
        self.property_value = 45_000_000.0
        self.last_update = time.time()

    def calculate_total_hq_value(self, live_market_data):
        btc_price = float(live_market_data.get("btc_price", 0))
        current_hq_value = self.property_value + (btc_price * 12.5)
        self.last_update = time.time()
        print(colored(f"[WEALTH-ORACLE] HQ total value: ${current_hq_value:,.2f}", "green"))
        return current_hq_value


if __name__ == "__main__":
    BursaWealthOracle().calculate_total_hq_value({"btc_price": 64_500.0})
