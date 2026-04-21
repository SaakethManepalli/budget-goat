# syntax = docker/dockerfile:1

ARG NODE_VERSION=22.11.0
FROM node:${NODE_VERSION}-slim AS base

LABEL fly_launch_runtime="Node.js"

WORKDIR /app
ENV NODE_ENV="production"

# Install production deps only. No native toolchain needed — all deps are pure JS.
COPY package.json package-lock.json* ./
RUN npm ci --omit=dev

# Copy source
COPY . .

EXPOSE 8787
CMD ["npm", "run", "start"]
