.PHONY: deps lint run-mainnet-online run-mainnet-offline run-testnet-online \
	run-testnet-offline check-comments add-license check-license shorten-lines \
	spellcheck salus format check-format update-tracer test coverage coverage-local \
	update-bootstrap-balances mocks build-testnet build-mainnet build-testnet-local \
	build-mainnet-local build-testnet-release build-mainnet-release run-mainnet-remote run-testnet-remote

ADDLICENSE_IGNORE=-ignore ".github/**/*" -ignore ".idea/**/*"
ADDLICENSE_INSTALL=go install github.com/google/addlicense@latest
ADDLICENSE_CMD=addlicense
ADDLICENCE_SCRIPT=${ADDLICENSE_CMD} -c "Coinbase, Inc." -l "apache" -v ${ADDLICENSE_IGNORE}
SPELLCHECK_CMD=go run github.com/client9/misspell/cmd/misspell
GOLINES_INSTALL=go install github.com/segmentio/golines@latest
GOLINES_CMD=golines
GOLINT_INSTALL=go install golang.org/x/lint/golint
GOLINT_CMD=golint
GOVERALLS_INSTALL=go install github.com/mattn/goveralls@latest
GOVERALLS_CMD=goveralls
GOIMPORTS_CMD=go run golang.org/x/tools/cmd/goimports
GO_PACKAGES=./services/... ./cmd/... ./configuration/... ./ethereum/...
GO_FOLDERS=$(shell echo ${GO_PACKAGES} | sed -e "s/\.\///g" | sed -e "s/\/\.\.\.//g")
TEST_SCRIPT=go test ${GO_PACKAGES}
LINT_SETTINGS=golint,misspell,gocyclo,gocritic,whitespace,goconst,gocognit,bodyclose,unconvert,lll,unparam
PWD=$(shell pwd)
NOFILE=100000

PLATFORM_FLAG :=
DOCKER_API_VERSION := $(shell docker version --format '{{.Server.APIVersion}}')
ifeq ($(shell expr $(DOCKER_API_VERSION) \>= 1.41), 1)
	PLATFORM_FLAG := --platform linux/amd64
endif

GITHUB_ACCESS_TOKEN_FLAG :=
trimmed_github_token := $(strip ${github_token})
ifneq (${trimmed_github_token},)
	GITHUB_ACCESS_TOKEN_FLAG := ${trimmed_github_token}@
endif

deps:
	go get ./...

test:
	${TEST_SCRIPT}

build-testnet:
	docker build ${PLATFORM_FLAG} -t rosetta-core:testnet-latest -f Dockerfile.testnet https://github.com/easonchan17/rosetta-core-for-docker.git

build-mainnet:
	docker build ${PLATFORM_FLAG} -t rosetta-core:mainnet-latest -f Dockerfile.mainnet https://${GITHUB_ACCESS_TOKEN_FLAG}github.com/coredao-org/rosetta-core.git

build-testnet-local:
	docker build ${PLATFORM_FLAG} -t rosetta-core:testnet-latest -f Dockerfile.testnet .

build-mainnet-local:
	docker build ${PLATFORM_FLAG} -t rosetta-core:mainnet-latest -f Dockerfile.mainnet .

build-testnet-release:
	# make sure to always set version with vX.X.X
	docker build ${PLATFORM_FLAG} -t rosetta-core:testnet-$(version) -f Dockerfile.testnet .;
	docker save rosetta-core:testnet-$(version) | gzip > rosetta-core-testnet-$(version).tar.gz;

build-mainnet-release:
	# make sure to always set version with vX.X.X
	docker build ${PLATFORM_FLAG} -t rosetta-core:mainnet-$(version) -f Dockerfile.mainnet .;
	docker save rosetta-core:mainnet-$(version) | gzip > rosetta-core-mainnet-$(version).tar.gz;

update-tracer:
	curl https://raw.githubusercontent.com/ethereum/go-ethereum/master/eth/tracers/js/internal/tracers/call_tracer_js.js -o ethereum/call_tracer.js

update-bootstrap-balances:
	go run main.go utils:generate-bootstrap ethereum/genesis_files/mainnet.json rosetta-cli-conf/mainnet/bootstrap_balances.json;
	go run main.go utils:generate-bootstrap ethereum/genesis_files/testnet.json rosetta-cli-conf/testnet/bootstrap_balances.json;
	go run main.go utils:generate-bootstrap ethereum/genesis_files/devnet.json rosetta-cli-conf/devnet/bootstrap_balances.json;

run-mainnet-online:
	docker run -d --rm ${PLATFORM_FLAG} --ulimit "nofile=${NOFILE}:${NOFILE}" -v "${PWD}/core-mainnet-data:/data" -e "MODE=ONLINE" -e "NETWORK=CORE" -e "PORT=8080" -p 8080:8080 -p 35021:35021 -p 8579:8579 rosetta-core:mainnet-latest

run-mainnet-offline:
	docker run -d --rm ${PLATFORM_FLAG} -e "MODE=OFFLINE" -e "NETWORK=CORE" -e "PORT=8081" -p 8081:8081 rosetta-core:mainnet-latest

run-testnet-online:
	docker run -d --rm ${PLATFORM_FLAG} --ulimit "nofile=${NOFILE}:${NOFILE}" -v "${PWD}/core-testnet-data:/data" -e "MODE=ONLINE" -e "NETWORK=BUFFALO" -e "PORT=8080" -p 8080:8080 -p 35012:35012 -p 8575:8575 rosetta-core:testnet-latest

run-testnet-offline:
	docker run -d --rm ${PLATFORM_FLAG} -e "MODE=OFFLINE" -e "NETWORK=BUFFALO" -e "PORT=8081" -p 8081:8081 rosetta-core:testnet-latest

run-mainnet-remote:
	docker run -d --rm ${PLATFORM_FLAG} --ulimit "nofile=${NOFILE}:${NOFILE}" -e "MODE=ONLINE" -e "NETWORK=CORE" -e "PORT=8080" -e "GETH=$(geth)" -p 8080:8080  rosetta-core:mainnet-latest

run-testnet-remote:
	docker run -d --rm ${PLATFORM_FLAG} --ulimit "nofile=${NOFILE}:${NOFILE}" -e "MODE=ONLINE" -e "NETWORK=BUFFALO" -e "PORT=8080" -e "GETH=$(geth)" -p 8080:8080  rosetta-core:testnet-latest

check-comments:
	${GOLINT_INSTALL}
	${GOLINT_CMD} -set_exit_status ${GO_FOLDERS} .
	go mod tidy

lint: | check-comments
	golangci-lint run --timeout 2m0s -v -E ${LINT_SETTINGS},gomnd

add-license:
	${ADDLICENSE_INSTALL}
	${ADDLICENCE_SCRIPT} .

check-license:
	${ADDLICENSE_INSTALL}
	${ADDLICENCE_SCRIPT} -check .

shorten-lines:
	${GOLINES_INSTALL}
	${GOLINES_CMD} -w --shorten-comments ${GO_FOLDERS} .

format:
	gofmt -s -w -l .
	${GOIMPORTS_CMD} -w .

check-format:
	! gofmt -s -l . | read
	! ${GOIMPORTS_CMD} -l . | read

salus:
	docker run --rm -t -v ${PWD}:/home/repo coinbase/salus

spellcheck:
	${SPELLCHECK_CMD} -error .

coverage:
	${GOVERALLS_INSTALL}
	if [ "$(COVERALLS_TOKEN)" ]; then ${TEST_SCRIPT} -coverprofile=c.out -covermode=count; ${GOVERALLS_CMD} -coverprofile=c.out -repotoken $(COVERALLS_TOKEN); fi

coverage-local:
	${TEST_SCRIPT} -cover

mocks:
	rm -rf mocks;
	mockery --dir services --all --case underscore --outpkg services --output mocks/services;
	mockery --dir ethereum --all --case underscore --outpkg ethereum --output mocks/ethereum;
	${ADDLICENSE_INSTALL}
	${ADDLICENCE_SCRIPT} .;
