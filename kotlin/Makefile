default: build

build:
	mvn clean install -e -DskipTests -Dcargo-build.profile=release

pkg:
	mvn clean package -Dcargo-build.profile=release

deploy:
	mvn clean deploy -Dcargo-build.profile=release

test:
	mvn clean test -Dcargo-build.profile=release
