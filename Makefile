FLUTTER ?= flutter
DART ?= dart

.PHONY: flutter-format flutter-analyze flutter-test flutter-check

flutter-format:
	cd apps/client_flutter && $(DART) format --set-exit-if-changed .

flutter-analyze:
	cd apps/client_flutter && $(FLUTTER) analyze

flutter-test:
	cd apps/client_flutter && $(FLUTTER) test

flutter-check: flutter-format flutter-analyze flutter-test
