FROM node:16-alpine as builder
ARG stage=prod
WORKDIR /src
COPY src ./
COPY package*.json ./
RUN npm ci
COPY . .
RUN npm run build:${stage}

FROM node:16-alpine
WORKDIR /task-app
COPY --from=builder /src/dist ./dist
COPY --from=builder /src/node_modules ./node_modules
EXPOSE 3000
CMD ["node", "/task-app/dist/bundle.js"]
