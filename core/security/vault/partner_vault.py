import base64
import hashlib

try:
    from Crypto.Cipher import AES
except ImportError:  # pragma: no cover
    AES = None


class PartnerVault:
    """Partner-scoped sealing helper with graceful fallback when AES is unavailable."""

    def __init__(self, partner_id):
        self.partner_id = partner_id
        self.vault_key = hashlib.sha256(f"BURSA_HQ_{partner_id}".encode()).digest()

    def seal_strategy(self, strategy_data):
        payload = strategy_data.encode()
        if AES is None:
            token = hashlib.sha256(self.vault_key + payload).hexdigest().encode()
            print(f"[VAULT] Partner {self.partner_id} verisi muhurlendi (hash fallback).")
            return base64.b64encode(token)

        cipher = AES.new(self.vault_key, AES.MODE_GCM)
        ciphertext, tag = cipher.encrypt_and_digest(payload)
        print(f"[VAULT] Partner {self.partner_id} verisi muhurlendi.")
        return base64.b64encode(cipher.nonce + tag + ciphertext)


if __name__ == "__main__":
    vault = PartnerVault("Partner_X")
    print(vault.seal_strategy("BTC_LONG_STRATEGY_v3"))
