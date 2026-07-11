try:
    from termcolor import colored
except ImportError:  # pragma: no cover
    def colored(text, *_args, **_kwargs):
        return text


class BursaSentinel:
    """Traffic scoring and emergency IP lockdown simulation."""

    def __init__(self):
        self.blacklisted_ips = set()
        self.threat_db = self.blacklisted_ips
        self.max_latency_threshold = 200
        self.threat_threshold = 0.95

    def scan_request(self, ip, latency, payload_size):
        if latency > self.max_latency_threshold:
            self.lockdown_ip(ip, "Latency_Anomaly")
            return False
        if payload_size > 1024 * 50:
            self.lockdown_ip(ip, "Large_Payload_Attack")
            return False
        return True

    def evaluate_traffic(self, ip_address, packet_pattern):
        threat_score = self.calculate_threat(packet_pattern)
        if threat_score > self.threat_threshold:
            self.lockdown_ip(ip_address, f"ThreatScore={threat_score:.2f}")
            return False
        return True

    def lockdown_ip(self, ip, reason):
        self.blacklisted_ips.add(ip)
        print(colored(f"[SENTINEL] {ip} muhurlendi. Gerekce: {reason}", "red"))

    def calculate_threat(self, pattern):
        if "brute_force" in pattern:
            return 0.98
        if "timing" in pattern:
            return 0.96
        return 0.10


if __name__ == "__main__":
    sentinel = BursaSentinel()
    sentinel.scan_request("192.168.1.45", 250, 100)
    sentinel.evaluate_traffic("185.122.45.10", "pattern:brute_force_attack_detected")
