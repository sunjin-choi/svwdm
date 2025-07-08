#!/usr/bin/env bash
# This scripts should be run at the project root

# define test suites
TEST_SUITES=(
	"tuner_search"
	"tuner_search_row"
	#"tuner_search_lock"
)

# build
cmake -B ./build . && cd ./build

# run tests
for test in "${TEST_SUITES[@]}"; do
	echo "Running test: $test"
	make run-"$test"/fast
	if [ $? -ne 0 ]; then
		echo "Test $test failed."
		exit 1
	fi
done
