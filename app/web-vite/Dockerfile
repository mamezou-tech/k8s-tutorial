FROM node:16-alpine as builder
WORKDIR /src
COPY src ./
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build

FROM node:16-alpine
WORKDIR /web-resources
COPY --from=builder /src/dist ./dist
RUN npm install -g http-server
EXPOSE 8080
CMD ["http-server", "/web-resources/dist"]
