// This file is auto-generated. Do not edit directly.
import { z } from 'zod';

export const PaymentSourceSchema = z.object({
  id: z.string(),
});

export type PaymentSource = z.infer<typeof PaymentSourceSchema>;
