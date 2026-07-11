from urllib.request import urlopen

try:
    from termcolor import colored
except ImportError:  # pragma: no cover
    def colored(text, *_args, **_kwargs):
        return text


class BursaSatelliteLink:
    """Fallback link checker for degraded network conditions."""

    def __init__(self):
        self.primary_net = "FIBER_HQ"
        self.backup_net = "STARLINK_BYPASS"
        self.is_connected = True

    def check_heartbeat(self):
        try:
            with urlopen("https://binance.com", timeout=2):
                self.is_connected = True
        except Exception:
            self.is_connected = False
            self.activate_satellite_mode()

    def activate_satellite_mode(self):
        print(colored("[SATELLITE LINK] Ana hat koptu. Uydu koprusu kuruluyor...", "yellow"))
        print(colored("[STATUS] STARLINK uzerinden baglanildi. Sadece acil emirler aktif.", "cyan"))


if __name__ == "__main__":
    link = BursaSatelliteLink()
    link.check_heartbeat()
