---
"@spree/sdk": patch
---

Rename `multi_search` to `search` in `ProductListParams` and `OrderListParams`. The `multi_search` param still works via backward compatibility on the backend but `search` is now the recommended parameter name for full-text search.
