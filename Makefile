.PHONY: bootstrap fetch build create-xcframework validate smoke-test package validate-versions validate-model all clean
bootstrap:; ./scripts/bootstrap.sh
fetch:; ./scripts/fetch.sh
build:; ./scripts/build.sh
create-xcframework:; ./scripts/create-xcframework.sh
validate:; ./scripts/validate.sh
smoke-test:; ./scripts/smoke-test.sh
package:; ./scripts/package.sh
validate-versions:; ./scripts/validate-versions.sh
validate-model:; ./scripts/validate-hand-landmarker-model.sh
all: bootstrap fetch build create-xcframework validate smoke-test package validate-model validate-versions
clean:; ./scripts/clean.sh
