ARG PHPVERSION

# Use an official Drupal PHP runtime image as a parent image
FROM php:${PHPVERSION}-cli

COPY --from=composer:latest /usr/bin/composer /usr/local/bin/composer

# Set the working directory
WORKDIR /terminus-plugin-test

# Copy the current directory contents into the container at our working directory
ADD . /terminus-plugin-test

# Collect the components we need for this image
RUN apt-get update
RUN apt-get install -y ruby jq git
RUN gem install circle-cli

# Pcov extension
RUN pecl install pcov && docker-php-ext-enable pcov

# Create an unpriviliged testuser
RUN groupadd -g 999 tester && \
    useradd -r -m -u 999 -g tester tester && \
    chown -R tester /usr/local && \
    chown -R tester /terminus-plugin-test
USER tester

# Install terminus
RUN curl -L https://github.com/pantheon-systems/terminus/releases/download/3.0.3/terminus.phar -o /usr/local/bin/terminus && \
    chmod +x /usr/local/bin/terminus
RUN terminus self:update

# Add phpcs for use in checking code style
RUN mkdir ~/phpcs && cd ~/phpcs && COMPOSER_BIN_DIR=/usr/local/bin composer require squizlabs/php_codesniffer:^2.7

# Add phpunit for unit testing
RUN mkdir ~/phpunit && cd ~/phpunit && COMPOSER_BIN_DIR=/usr/local/bin composer require phpunit/phpunit:^9

# Add bats for functional testing
RUN git clone https://github.com/sstephenson/bats.git; bats/install.sh /usr/local

# Add behat for more functional testing
RUN mkdir ~/behat && \
    cd ~/behat && \
    COMPOSER_BIN_DIR=/usr/local/bin \
    composer require \
        "behat/behat:^3.1" \
        "behat/mink:*" \
        "behat/mink-extension:^2.2" \
        "behat/mink-goutte-driver:^1.2" \
        "drupal/drupal-extension:*"
