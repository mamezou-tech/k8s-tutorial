FROM node:16-alpine as builder
WORKDIR /src
COPY src ./
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build:local

FROM node:16-alpine
WORKDIR /task-reporter
COPY --from=builder /src/dist ./dist
COPY --from=builder /src/node_modules ./node_modules
CMD ["node", "/task-reporter/dist/bundle.js"]
