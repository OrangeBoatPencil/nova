import Stripe from 'stripe';
import { loadStripe } from '@stripe/stripe-js';

/**
 * Initialize Stripe client on the server side
 */
export const getStripeClient = (apiKey: string): Stripe => {
  return new Stripe(apiKey, {
    apiVersion: '2023-10-16',
  });
};

/**
 * Stripe frontend client
 */
let stripePromise: Promise<ReturnType<typeof loadStripe>> | null = null;

export const getStripeJs = (publishableKey: string) => {
  if (!stripePromise) {
    stripePromise = loadStripe(publishableKey);
  }
  return stripePromise;
};

/**
 * Create a Stripe Checkout session
 */
export const createCheckoutSession = async ({
  stripe,
  priceId,
  customerId,
  successUrl,
  cancelUrl,
}: {
  stripe: Stripe;
  priceId: string;
  customerId?: string;
  successUrl: string;
  cancelUrl: string;
}) => {
  const session = await stripe.checkout.sessions.create({
    customer: customerId,
    payment_method_types: ['card'],
    line_items: [
      {
        price: priceId,
        quantity: 1,
      },
    ],
    mode: 'subscription',
    success_url: successUrl,
    cancel_url: cancelUrl,
  });

  return session;
};

/**
 * Create a Stripe Portal session
 */
export const createPortalSession = async ({
  stripe,
  customerId,
  returnUrl,
}: {
  stripe: Stripe;
  customerId: string;
  returnUrl: string;
}) => {
  const session = await stripe.billingPortal.sessions.create({
    customer: customerId,
    return_url: returnUrl,
  });

  return session;
};

export * from './types'; 