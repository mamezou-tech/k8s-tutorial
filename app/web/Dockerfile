FROM node:16-alpine as builder
ARG stage=prod
WORKDIR /src
COPY src ./
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build:${stage}

FROM node:16-alpine
WORKDIR /web-resources
COPY --from=builder /src/dist ./dist
RUN npm install -g http-server
EXPOSE 8080
CMD ["http-server", "/web-resources/dist"]
