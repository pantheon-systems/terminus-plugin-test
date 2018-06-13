# Use an official Drupal PHP runtime image as a parent image
FROM quay.io/pantheon-public/php-ci:1.x

# Set the working directory to /php-ci
WORKDIR /terminus-plugin-test

# Copy the current directory contents into the container at /php-ci
ADD . /terminus-plugin-test

# Add phpcs for use in checking code style
RUN mkdir ~/phpcs && cd ~/phpcs && COMPOSER_BIN_DIR=/usr/local/bin composer require squizlabs/php_codesniffer:^2.7

# Add in a global phpunit for unit testing
RUN mkdir ~/phpunit && cd ~/phpunit && COMPOSER_BIN_DIR=/usr/local/bin composer require phpunit/phpunit:^6

# Add bats for use in testing
RUN git clone https://github.com/sstephenson/bats.git; bats/install.sh /usr/local

USER nobody
