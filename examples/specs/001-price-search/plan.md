# Implementation Plan: Price search

**Spec**: [spec.md](spec.md)

## Technical Context

- **Stack**: TypeScript, Node 26, Fastify, PostgreSQL, React
- **Testing**: `pnpm test` (node:test), with an integration test against a test database
- **Performance**: an index on `products(price)` keeps SC-001 under 200 ms

## Design

- `GET /products?maxPrice=15` → `200 [{ id, name, price }]` sorted by price; `400` on bad input.
- The query lives in `src/products/search.ts`; the route only validates and calls it.
- The UI adds a number input to `src/web/ProductList.tsx` that calls the endpoint.

## Constitution Check

Simple (one query, one route, one field) · input validated at the API boundary (FR-002) ·
every task has a test that proves its *Completed when*.
