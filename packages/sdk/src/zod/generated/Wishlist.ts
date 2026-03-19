// This file is auto-generated. Do not edit directly.
import { z } from 'zod';
import { WishlistItemSchema } from './WishlistItem';

export const WishlistSchema = z.object({
  id: z.string(),
  name: z.string(),
  token: z.string(),
  created_at: z.string(),
  updated_at: z.string(),
  is_default: z.boolean(),
  is_private: z.boolean(),
  items: z.array(WishlistItemSchema).optional(),
});

export type Wishlist = z.infer<typeof WishlistSchema>;
