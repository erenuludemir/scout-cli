import base64
import hashlib
import os

try:
    from Crypto.Cipher import AES
except ImportError:  # pragma: no cover
    AES = None

try:
    from termcolor import colored
except ImportError:  # pragma: no cover
    def colored(text, *_args, **_kwargs):
        return text


class BursaPCIVault:
    """Tokenization helper with optional AES-GCM support."""

    def __init__(self):
        self.master_key = os.urandom(32)

    def tokenize_payment_data(self, partner_id, card_data):
        print(colored(f"[PCI-VAULT] Partner {partner_id} icin veri muhurleniyor...", "cyan"))
        if AES is None:
            digest = hashlib.sha256(self.master_key + card_data.encode()).digest()
            return base64.b64encode(digest[:24]).decode("utf-8")

        cipher = AES.new(self.master_key, AES.MODE_GCM)
        nonce = cipher.nonce
        _ciphertext, tag = cipher.encrypt_and_digest(card_data.encode())
        token = base64.b64encode(nonce + tag).decode("utf-8")
        return token


if __name__ == "__main__":
    vault = BursaPCIVault()
    print(vault.tokenize_payment_data("Bursa_Invest_01", "VISA_4111_..."))
