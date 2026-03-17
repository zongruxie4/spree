---
"@spree/sdk": minor
---

### Breaking: Shipping → Delivery/Fulfillment naming

Renamed all shipping/shipment API surface to use delivery/fulfillment vocabulary:

- `client.carts.shipments` → `client.carts.fulfillments`
- `selected_shipping_rate_id` param → `selected_delivery_rate_id`
- `/carts/:id/shipments` endpoint → `/carts/:id/fulfillments`

### Breaking: Renamed response fields

- `shipment_state` → `fulfillment_status` (on Order)
- `payment_state` → `payment_status` (on Order)
- `ship_total` / `display_ship_total` → `delivery_total` / `display_delivery_total` (on Cart/Order)
- `state` → `status` (on Payment, GiftCard)
- `shipped_at` → `fulfilled_at` (on Fulfillment)
- `shipping_method` → `delivery_method` (on Fulfillment, DeliveryRate)
- `shipping_rates` → `delivery_rates` (on Fulfillment)

### Breaking: Removed fields

- Removed `is_master` from Variant
- Removed `expand=master_variant` from Product (use `expand=default_variant`)

### Type renames

- `Shipment` → `Fulfillment` / `StoreFulfillment`
- `ShippingMethod` → `DeliveryMethod` / `StoreDeliveryMethod`
- `ShippingRate` → `DeliveryRate` / `StoreDeliveryRate`
