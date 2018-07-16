# Use an official Drupal PHP runtime image as a parent image
FROM drupaldocker/php:7.1-cli

# Set the working directory
WORKDIR /terminus-plugin-test

# Copy the current directory contents into the container at our working directory
ADD . /terminus-plugin-test

# Collect the components we need for this image
RUN apt-get update
RUN apt-get install -y ruby
RUN gem install circle-cli
RUN composer global require -n "hirak/prestissimo:^0.3"

# Create an unpriviliged testuser
RUN groupadd -g 999 tester && \
    useradd -r -m -u 999 -g tester tester && \
    chown -R tester /usr/local && \
    chown -R tester /terminus-plugin-test
USER tester

# Install terminus
RUN git clone https://github.com/pantheon-systems/terminus.git ~/terminus
RUN cd ~/terminus && git checkout 1.8.0 && composer install
RUN ln -s ~/terminus/bin/terminus /usr/local/bin/terminus

# Add phpcs for use in checking code style
RUN mkdir ~/phpcs && cd ~/phpcs && COMPOSER_BIN_DIR=/usr/local/bin composer require squizlabs/php_codesniffer:^2.7

# Add phpunit for unit testing
RUN mkdir ~/phpunit && cd ~/phpunit && COMPOSER_BIN_DIR=/usr/local/bin composer require phpunit/phpunit:^6

# Add bats for functional testing
RUN git clone https://github.com/sstephenson/bats.git; bats/install.sh /usr/local

# Add behat for more functional testing
RUN mkdir ~/behat && cd ~/behat && COMPOSER_BIN_DIR=/usr/local/bin composer require "behat/behat:^3.1" "behat/mink-extension:^2.2" "behat/mink-goutte-driver:^1.2"
