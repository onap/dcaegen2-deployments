FROM node:8.11.1
RUN mkdir -p /opt/app
COPY *.js /opt/app/
COPY package.json /opt/app/
WORKDIR /opt/app
RUN npm install --only=production
EXPOSE 80
ENTRYPOINT ["/usr/local/bin/node", "healthcheck.js"]
