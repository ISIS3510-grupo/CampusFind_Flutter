# Common commands for the Flutter app. Run `make` to list them.
# Secrets never go here: pass them as environment variables.

APK := build/app/outputs/flutter-apk/app-debug.apk
# Extra flags for flutter build, e.g. DART_DEFINES="--dart-define=GOOGLE_MAPS_API_KEY=..."
DART_DEFINES ?=
# Optional file with EMAIL and PASSWORD for the Maestro test student.
MAESTRO_ENV ?=
# Tailscale name of the phone that receives the APK.
DEVICE ?=

.DEFAULT_GOAL := help
.PHONY: help deps format analyze test coverage apk install run e2e send clean

help: ## List the commands
	@grep -E '^[a-z0-9-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'

deps: ## Install the packages
	flutter pub get

format: ## Format lib and test
	dart format lib test

analyze: ## Static analysis, same as CI
	flutter analyze --no-fatal-infos --no-fatal-warnings

test: ## Unit and widget tests
	flutter test

coverage: ## Tests with coverage in coverage/lcov.info
	flutter test --coverage

apk: ## Build the debug APK
	flutter build apk --debug $(DART_DEFINES)

install: apk ## Build and install the APK on the connected device
	adb install -r $(APK)

run: ## Run the app on the connected device
	flutter run $(DART_DEFINES)

e2e: install ## Maestro flows (needs EMAIL and PASSWORD, or MAESTRO_ENV)
	@set -a; if [ -n "$(MAESTRO_ENV)" ]; then . "$(MAESTRO_ENV)"; fi; set +a; \
	: "$${EMAIL:?Set EMAIL or MAESTRO_ENV}" "$${PASSWORD:?Set PASSWORD or MAESTRO_ENV}"; \
	maestro test -e EMAIL="$$EMAIL" -e PASSWORD="$$PASSWORD" -e TITLE="Maestro $$(date +%H%M%S)" .maestro

send: ## Send the APK over Taildrop (DEVICE=<tailscale name>)
	$(if $(DEVICE),,$(error Set DEVICE=<tailscale name>))
	tailscale file cp $(APK) $(DEVICE):

clean: ## Remove build outputs
	flutter clean
