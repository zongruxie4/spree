---
"@spree/next": minor
---

### Breaking: Shipping → Delivery/Fulfillment naming

Renamed server actions to match SDK 0.12.0 naming:

- `getShipments()` → `getFulfillments()`
- `selectShippingRate(shipmentId, rateId)` → `selectDeliveryRate(fulfillmentId, rateId)`

### Updated type re-exports

- `Shipment` → `Fulfillment`
- `ShippingRate` → `DeliveryRate`
