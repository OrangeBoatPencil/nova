export type SubscriptionStatus =
  | 'active'
  | 'canceled'
  | 'incomplete'
  | 'incomplete_expired'
  | 'past_due'
  | 'trialing'
  | 'unpaid';

export interface CustomerData {
  id: string;
  email: string;
  name?: string;
  subscriptionId?: string;
  subscriptionStatus?: SubscriptionStatus;
  priceId?: string;
}

export interface PriceData {
  id: string;
  name: string;
  description?: string;
  unitAmount: number;
  currency: string;
  type: 'one_time' | 'recurring';
  interval?: 'day' | 'week' | 'month' | 'year';
  intervalCount?: number;
}

export interface CreateCheckoutOptions {
  priceId: string;
  customerId?: string;
  successUrl: string;
  cancelUrl: string;
}

export interface CreatePortalOptions {
  customerId: string;
  returnUrl: string;
} 