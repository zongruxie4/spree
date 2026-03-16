## 2026-03-16: PaymentMethod and DeliveryMethod become SingleStoreResource
Both PaymentMethod and DeliveryMethod (renamed from ShippingMethod) switch from
multi-store join tables (`StorePaymentMethod`, `StoreShippingMethod`) to
`SingleStoreResource` with direct `belongs_to :store`.

In practice, different stores have different currencies, zones, and provider
accounts — sharing the same payment/delivery config across stores is rare.
If a merchant wants the same config on two stores, they create two records.

Changes:
- Add `store_id` column to `spree_payment_methods` and `spree_delivery_methods`
- Data migration: for each join record, set `store_id`; duplicate methods linked
  to multiple stores
- Drop `spree_store_payment_methods` and `spree_store_shipping_methods` join tables
- Both models include `Spree::SingleStoreResource` concern

## 2026-03-16: Fix promotion rule/action STI namespacing
Rename `Spree::Promotion::Rules::*` → `Spree::PromotionRules::*` and
`Spree::Promotion::Actions::*` → `Spree::PromotionActions::*`.

The convention for STI subtypes is `Spree::{BaseClass}s::{Subtype}` — pluralized
base class as the namespace. Every other hierarchy follows this already:

- `Spree::PriceRules::VolumeRule`
- `Spree::Metafields::ShortText`
- `Spree::CollectionRules::Tag` (from categories plan)
- `Spree::ReimbursementType::Credit`

Promotion was the only one nesting under the parent model (`Spree::Promotion::Rules`)
instead of the base class (`Spree::PromotionRules`).

Changes:
- Move files from `app/models/spree/promotion/rules/` → `app/models/spree/promotion_rules/`
- Move files from `app/models/spree/promotion/actions/` → `app/models/spree/promotion_actions/`
- Data migration: update `type` column in `spree_promotion_rules` and `spree_promotion_actions`
  (e.g., `Spree::Promotion::Rules::Product` → `Spree::PromotionRules::Product`)
- Deprecation aliases for one release

## 2026-03-16: Normalize state → status across all models
Settle on `status` as the standard column name for state machines. Newer models
(Product, PriceList, PaymentSession, Import, Invitation) already use `status`.

Order.state and Adjustment.state are removed entirely by other 6.0 plans
(cart-order-split, split-adjustments). Five remaining models need a column
rename from `state` → `status` in 6.0:

- **Payment** — `state` → `status`
- **Shipment** — `state` → `status`
- **InventoryUnit** — `state` → `status`
- **ReturnAuthorization** — `state` → `status`
- **GiftCard** — `state` → `status`

Single migration renaming all five columns. State machine declarations updated
to `state_machine :status, initial: ...`. Deprecation aliases
(`alias_attribute :state, :status`) for one release.

Models already correct (no change): Product, PriceList, PaymentSession,
PaymentSetupSession, Import, ImportRow, Invitation, ReturnItem
(`reception_status`/`acceptance_status`), Reimbursement (`reimbursement_status`).

## 2026-03-16: Consolidate metadata — drop public_metadata, keep metadata JSON column
Drop `public_metadata` column (never exposed in Store API, unused). Rename
`private_metadata` → `metadata` in the database. Simplify the `Spree::Metadata`
concern to a single `metadata` JSON column with no alias indirection.

**Metadata** (JSON column) stays as a schemaless developer escape hatch —
integration IDs, sync state, ad-hoc flags. No definition required, one-step API:
`PATCH /product { metadata: { erp_id: "123" } }`. Never exposed in Store API
(Stripe convention: write-only).

**Metafields** stay as merchant-defined structured data — typed values
(short_text, number, boolean, json, rich_text, long_text), require a
`MetafieldDefinition`, have visibility control (front_end/back_end),
searchable, CSV importable. With the ProductType plan (6.0-product-types.md),
metafields become schema-enforced custom attributes driven by ProductType.

Two systems, two purposes, no overlap. No consolidation into one.

## 2026-03-10: Product descriptions stay as plain column
Considered Action Text. Rejected for API-first performance —
serializing rich text adds overhead for every product response.
Also in the new Admin UI we will use TipTap for rich text editing.
