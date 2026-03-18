#!/bin/bash
set -e

echo "[i] .env gncelleniyor"

# ETHERSCAN
grep -q '^ETHERSCAN_API_KEY=' .env \
  && sed -i '' -E 's/^ETHERSCAN_API_KEY=.*/ETHERSCAN_API_KEY=REPLACE_WITH_YOUR_KEY/' .env \
  || echo 'ETHERSCAN_API_KEY=REPLACE_WITH_YOUR_KEY' >> .env

# INFURA + ETH Bilgileri
grep -q '^INFURA_PROJECT_ID=' .env     || echo 'INFURA_PROJECT_ID=a1308e9977764245b8d7b532a59ac7ee' >> .env
grep -q '^ETH_SENDER_ADDRESS=' .env    || echo 'ETH_SENDER_ADDRESS=0xda93812D7D1F3D326ef8156D94175238948Da04f' >> .env
grep -q '^ETH_PRIVATE_KEY=' .env       || echo 'ETH_PRIVATE_KEY=0xd1b9128cb5e34115f061a37348607e877d457cc53cde1825dac65e60427f9' >> .env
grep -q '^ETH_RECIPIENT_ADDRESS=' .env || echo 'ETH_RECIPIENT_ADDRESS=0xc5C600c86E13e8c475BCEbC981966d47E171A18c' >> .env

echo "[] .env baaryla gncellendi."
