// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { DeliveryMethodSchema } from './DeliveryMethod';

export const DeliveryRateSchema = z.object({
  id: z.string(),
  delivery_method_id: z.string(),
  name: z.string(),
  selected: z.boolean(),
  cost: z.string(),
  display_cost: z.string(),
  delivery_method: DeliveryMethodSchema,
});

export type DeliveryRate = z.infer<typeof DeliveryRateSchema>;
