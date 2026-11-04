<!-- PR #24 "feat(products): add price search query", feat/001-t001-add-the-price-query → develop. Opened by /speckit-implement (pr.sh task). -->
Adds `searchByMaxPrice()`, which returns products at or below a price, cheapest first, plus an
index on `products(price)`.

## Evidence

tests 18/18 · lint clean · scanners: no findings · 10,000 rows answered in 41 ms (SC-001)

<details>
<summary>Test output</summary>

```
✓ search > returns products at or below the max, cheapest first
✓ search > returns nothing on an empty catalog
✓ search > keeps a stable order for equal prices
✓ search > 10,000 products under 200 ms (41 ms)
Test Files  3 passed (3) · Tests  18 passed (18)
```

</details>

<details>
<summary>Security scan</summary>

Ran gitleaks, osv-scanner and semgrep on the changed files: 0 findings.
`/security-review`: the query is parameterized, so there is no injection path.

</details>

Closes #21
