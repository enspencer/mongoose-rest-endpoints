FROM node:6-alpine

MAINTAINER Krypton "krypton@maxwellhealth.com"

RUN apk add --no-cache \
    attr \
    bash \
    ca-certificates \
    make \
    unzip

RUN mkdir -p /var/www/edi/
WORKDIR /var/www/edi/
COPY . .

RUN npm install -g grunt-cli
RUN npm install -g mocha@^5.2.0
RUN npm install
RUN npm install body-parser
RUN npm install method-override

CMD ./wait-for-it.sh mongo:27017 -- npm run test
