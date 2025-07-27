all : settings.json

% : %.in
	envsubst <$^ >$@

test :
	FORCE_COLOR=2 node --test --test-reporter ./test-reporter.js $(TEST_FLAGS) transmission-tui.test.js

format-js :
	npx --yes prettier --use-tabs --write --print-width 100 transmission-tui.test.js test-reporter.js transmission-admin
