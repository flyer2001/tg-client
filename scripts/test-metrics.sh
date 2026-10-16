#!/usr/bin/env bash
# Метрики тестов из .claude/testing-v1-plan.md — одной командой, key=value.
#   scripts/test-metrics.sh              статика по Tests/ (работает где угодно)
#   scripts/test-metrics.sh /tmp/t.log   + время наборов из лога `swift test`
set -euo pipefail
cd "$(dirname "$0")/.."

count() { grep -rE "$1" "${2:-Tests}" --include=*.swift | wc -l | tr -d ' '; }
lines() { find "$1" -name '*.swift' -print0 | xargs -0 cat | wc -l | tr -d ' '; }

unit=$(count '@Test' Tests/TgClientUnitTests)
comp=$(count '@Test' Tests/TgClientComponentTests)
e2e=$(count '@Test' Tests/TgClientE2ETests)
echo "tests_unit=$unit"
echo "tests_component=$comp"
echo "tests_e2e=$e2e"
echo "e2e_disabled=$(count '\.disabled' Tests/TgClientE2ETests)"
echo "sleep_in_tests=$(count 'Task\.sleep|Thread\.sleep|usleep')"
echo "raw_json_casts=$(count 'as! \[|as\? \[String: Any\]')"
echo "fatalError_in_helpers=$(count 'fatalError' Tests/TestHelpers)"
echo "component_lines_per_test=$(( $(lines Tests/TgClientComponentTests) / comp ))"
echo "test_loc=$(lines Tests)"

if [ $# -ge 1 ]; then
  grep -h 'Test run with' "$1" | sed -E 's/.*with ([0-9]+) tests.* after ([0-9.]+) seconds.*/suite_\1_tests_s=\2/'
fi
