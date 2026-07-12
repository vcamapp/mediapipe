.PHONY: bootstrap fetch build create-xcframework validate smoke-test package all clean
bootstrap:; ./scripts/bootstrap.sh
fetch:; ./scripts/fetch.sh
build:; ./scripts/build.sh
create-xcframework:; ./scripts/create-xcframework.sh
validate:; ./scripts/validate.sh
smoke-test:; ./scripts/smoke-test.sh
package:; ./scripts/package.sh
all: bootstrap fetch build create-xcframework validate smoke-test package
clean:; ./scripts/clean.sh
