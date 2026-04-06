# Zentry

This repository contains both the mobile client and the server for the **Zentry** application.

- **client/** – Expo based React Native app.
- **server/** – Node.js REST API built with Express and Sequelize.

## Docs

- REST API docs: run the server and open `/docs`
- Socket event reference: [docs/socket-events.md](docs/socket-events.md)
- AsyncAPI socket spec: [docs/socket-events.asyncapi.yaml](docs/socket-events.asyncapi.yaml)

## Running the server

From the `server` directory run:

```bash
pnpm install
pnpm dev
```

## Running the client

From the `client` directory run:

```bash
npm install
npm start
```

See each directory for more details.

## Pre-commit checks

This repo uses a committed Git hook at `.githooks/pre-commit` to run lint and test checks before each commit:

- `client/` changes run `flutter analyze` and `flutter test`
- `server/` changes run `pnpm lint` and `pnpm test`

Activate the hook in a clone with:

```bash
git config core.hooksPath .githooks
```
