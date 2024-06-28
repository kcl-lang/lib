default: build

build:
	mvn clean install -DskipTests -Dcargo-build.profile=release

fmt:
	mvn formatter:format

pkg:
	mvn clean package -Dcargo-build.profile=release

deploy:
	mvn clean deploy -Dcargo-build.profile=release

test:
	mvn clean test -Dcargo-build.profile=release
