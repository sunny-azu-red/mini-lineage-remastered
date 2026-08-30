# --- STAGE 1: The Kitchen (Builder) ---
FROM node:22-alpine AS builder
RUN apk add --no-cache git curl
WORKDIR /app

COPY package*.json ./
RUN npm ci

COPY . .
RUN export APP_VERSION=$(curl -s https://api.github.com/repos/sunny-azu-red/mini-lineage-remastered/commits/main | grep -m 1 '"sha":' | cut -d '"' -f 4 | cut -c1-7) && \
    npm run build

# --- STAGE 2: The App (Production) ---
FROM node:22-alpine AS runner
WORKDIR /app
ENV NODE_ENV=production
ENV IN_DOCKER=true

COPY --from=builder /app/dist ./dist
COPY --from=builder /app/package*.json ./

RUN npm ci --omit=dev

CMD ["sh", "-c", "node dist/scripts/db/migrate.js && npm run start"]
