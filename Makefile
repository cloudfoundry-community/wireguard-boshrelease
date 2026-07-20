# wireguard-boshrelease — development targets.
#
# Usage:
#   make                              # show this target list
#   make download-blobs               # fetch wireguard-tools tarball, add to blobs/
#   make download-blobs WG_TOOLS_VERSION=1.0.20260223
#   make upload-blobs                 # push blobs to the release blobstore
#   make dev-release                  # bosh create-release --force
#   make final-release VERSION=0.1.0  # bosh create-release --final --version=...
#   make clean                        # remove dev build artifacts

WG_TOOLS_VERSION ?= 1.0.20260223

CYAN  := \033[36m
BOLD  := \033[1m
RESET := \033[0m

.DEFAULT_GOAL := help

.PHONY: help
help:
	@printf "$(BOLD)wireguard-boshrelease$(RESET)\n\n"
	@printf "$(BOLD)Targets:$(RESET)\n"
	@grep -E '^[a-zA-Z_-]+:.*?##' $(MAKEFILE_LIST) \
	 | awk 'BEGIN {FS = ":.*?## "} {printf "  $(CYAN)%-18s$(RESET) %s\n", $$1, $$2}'
	@printf "\n$(BOLD)Variables:$(RESET)\n"
	@printf "  $(CYAN)%-18s$(RESET) %s\n" "WG_TOOLS_VERSION" "wireguard-tools tarball version (default: $(WG_TOOLS_VERSION))"
	@printf "  $(CYAN)%-18s$(RESET) %s\n" "VERSION" "release version for final-release, e.g. 0.1.0"

.PHONY: download-blobs
download-blobs: ## Fetch wireguard-tools tarball, verify sha256, bosh add-blob
	./scripts/add-blob.sh $(WG_TOOLS_VERSION)

.PHONY: upload-blobs
upload-blobs: ## Upload blobs to the release blobstore (needs config/private.yml)
	bosh upload-blobs

.PHONY: dev-release
dev-release: ## Build a development release (bosh create-release --force)
	bosh create-release --force

.PHONY: final-release
final-release: ## Build a final release (requires VERSION=x.y.z)
	@if [ -z "$(VERSION)" ]; then \
	  printf "Set VERSION, e.g. make final-release VERSION=0.1.0\n" >&2; \
	  exit 1; \
	fi
	bosh create-release --final --version=$(VERSION)

.PHONY: clean
clean: ## Remove dev build artifacts (keeps blobs/)
	rm -rf .dev_builds dev_releases

.PHONY: clean-blobs
clean-blobs: ## Remove the local blob cache (forces re-download on next build)
	rm -rf blobs/
