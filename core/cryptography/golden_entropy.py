import decimal

try:
    from termcolor import colored
except ImportError:  # pragma: no cover
    def colored(text, *_args, **_kwargs):
        return text


class GoldenEntropyEngine:
    """Golden ratio driven irrational digit generator."""

    def __init__(self):
        decimal.getcontext().prec = 1000
        self.phi = (1 + decimal.Decimal(5).sqrt()) / 2

    def generate_phi_sequence(self, start_digit, length=64):
        phi_str = str(self.phi).replace(".", "")
        sequence = phi_str[start_digit:start_digit + length]
        print(colored(f"[GOLDEN-PHI] Irrasyonel dizi uretildi (digit: {start_digit})", "yellow"))
        return sequence


if __name__ == "__main__":
    engine = GoldenEntropyEngine()
    print(engine.generate_phi_sequence(100))
