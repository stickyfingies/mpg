# syntax=docker/dockerfile:1

# Build stage for common package
FROM node:23 AS common-builder
WORKDIR /app/common
COPY common/package*.json ./
RUN npm install
RUN npm install --only=dev
COPY common/ ./
RUN npm run build || echo "No build script in common package"

# Build stage for client
FROM node:23 AS client-builder
WORKDIR /app/client
COPY client/package*.json ./
RUN npm install
RUN npm install --only=dev
COPY client/ ./
COPY --from=common-builder /app/common /app/common
RUN npm run build

# Build stage for server
FROM node:23 AS server-builder
WORKDIR /app/server
COPY server/package*.json ./
RUN npm install
RUN npm install --only=dev
COPY server/ ./
COPY --from=common-builder /app/common /app/common
RUN npm run build

# Production stage
FROM node:23-slim
WORKDIR /app

# Copy only what's needed for production
COPY --from=common-builder /app/common ./common
COPY --from=server-builder /app/server/package*.json ./server/
COPY --from=server-builder /app/server/dist ./server/dist
COPY --from=client-builder /app/client/dist ./client/dist

WORKDIR /app/server
RUN npm install --omit=dev

ENV NODE_ENV production
EXPOSE 8080

CMD ["npm", "start"]