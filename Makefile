deploy-dry-run:
	@CHAIN=${chain}; \
	if [ -z "$$CHAIN" ]; then CHAIN=fuji; fi; \
	echo "Current chain: $$CHAIN"; \
	forge script script/Deploy.s.sol:Deploy --fork-url $$CHAIN -vv

deploy-run:
	@CHAIN=${chain}; \
	if [ -z "$$CHAIN" ]; then CHAIN=fuji; fi; \
	echo "Current chain: $$CHAIN"; \
	forge script script/Deploy.s.sol:Deploy --fork-url $$CHAIN -vv --broadcast