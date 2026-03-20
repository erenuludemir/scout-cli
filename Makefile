PYTHON ?= python
QAI_PYTHON ?= $(shell [ -x ./.venv_qai_ai/bin/python ] && echo ./.venv_qai_ai/bin/python || echo $(PYTHON))
POETRY ?= poetry
DEFAULT_ETHERSCAN_ADDRESS ?= 0x71c7656ec7ab88b098defb751b7401b5f6d8976f
DEFAULT_ETHERSCAN_CHAINID ?= 1
DEFAULT_ETHERSCAN_CONTRACT ?= 0xdAC17F958D2ee523a2206206994597C13D831ec7
DEFAULT_ETHERSCAN_CONTRACTS ?= 0xdac17f958d2ee523a2206206994597c13d831ec7,0xa0b86991c6218b36c1d19d4a2e9eb0ce3606eb48

.PHONY: audit doctor ci-local help hook-install hook-uninstall
.DEFAULT_GOAL := help

help:
	@printf "%s\n" ""
	@printf "%s\n" "Kullanılabilir hedefler:"
	@printf "%s\n" "  make                -> help"
	@printf "%s\n" "  make help           -> bu liste"
	@printf "%s\n" "  make audit          -> dependency audit"
	@printf "%s\n" "  make doctor         -> audit + DOCTOR_OK"
	@printf "%s\n" "  make ci-local       -> audit + CI_LOCAL_OK"
	@printf "%s\n" "  make hook-install   -> local pre-push hook kur"
	@printf "%s\n" "  make hook-uninstall -> local pre-push hook kaldır"

audit:
	"$(CURDIR)/ops/qai_dependency_audit.sh"

doctor: audit
	@echo "DOCTOR_OK"

ci-local: audit
	@echo "CI_LOCAL_OK"

hook-install:
	@git config core.hooksPath .githooks
	@chmod +x "$(CURDIR)/.githooks/pre-push"
	@printf "%s\n" "HOOK_INSTALL_OK"

hook-uninstall:
	@git config --unset core.hooksPath || true
	@printf "%s\n" "HOOK_UNINSTALL_OK"
