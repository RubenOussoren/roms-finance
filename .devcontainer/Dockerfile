ARG RUBY_VERSION=3.4.4
FROM ruby:${RUBY_VERSION}-slim-bookworm

RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
  && apt-get -y install --no-install-recommends \
  apt-utils \
  build-essential \
  curl \
  git \
  imagemagick \
  iproute2 \
  libpq-dev \
  libvips42 \
  libyaml-dev \
  libyaml-0-2 \
  openssh-client \
  postgresql-client \
  vim

RUN gem install bundler
RUN gem install foreman

# Node.js 22 LTS (Node 20 is end-of-life).
RUN curl -fsSL https://deb.nodesource.com/setup_22.x | bash - \
&& apt-get install -y --no-install-recommends nodejs \
&& rm -rf /var/lib/apt/lists/*

WORKDIR /workspace
