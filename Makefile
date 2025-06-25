set-up-dry-run:
	@CHAIN=${chain}; \
	if [ -z "$$CHAIN" ]; then CHAIN=fuji; fi; \
	echo "Current chain: $$CHAIN"; \
	forge script script/SetUpAll.s.sol:SetUpAll --fork-url $$CHAIN -vv

set-up-run:
	@CHAIN=${chain}; \
	if [ -z "$$CHAIN" ]; then CHAIN=fuji; fi; \
	echo "Current chain: $$CHAIN"; \
	forge script script/SetUpAll.s.sol:SetUpAll --fork-url $$CHAIN -vv --broadcast --verify --slow 


test-all:; forge test

test-match:; forge test --match-test ${match} -vvv