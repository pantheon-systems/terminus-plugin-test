# Terminus Plugin Test Docker Image

[![Actively Maintained](https://img.shields.io/badge/Pantheon-Actively_Maintained-yellow?logo=pantheon&color=FFDC28)](https://pantheon.io/docs/oss-support-levels#actively-maintained)

[![docker pull quay.io/pantheon-public/terminus-plugin-test](https://img.shields.io/badge/image-quay-blue.svg)](https://quay.io/repository/pantheon-public/terminus-plugin-test)

This is the source Dockerfile for the [pantheon-public/terminus-plugin-test](https://quay.io/repository/pantheon-public/terminus-plugin-test) docker image.

For an example of how to use this image to test Terminus plugins, see the [Terminus Plugin Example](https://github.com/pantheon-systems/terminus-plugin-example).

## Usage
In CircleCI 2.0:
```
  docker:
    - image: quay.io/pantheon-public/terminus-plugin-test:1.x
```
## Image Contents

This docker image contains the contents of [pantheon-public/php-ci](https://quay.io/repository/pantheon-public/php-ci), which includes PHP and Terminus. It adds testing tools useful for testing Terminus Plugins.

- [bats](https://github.com/sstephenson/bats) shell script testing tool
- [phpcs](https://github.com/squizlabs/php_codesniffer) php code style tool
- [phpunit](https://github.com/phpunit/phpunit) php unit test tool

If you are looking for a container prepopulated with Terminus plugins to use in functional testing, see the [build-tools-ci image](https://github.com/pantheon-systems/docker-build-tools-ci).
