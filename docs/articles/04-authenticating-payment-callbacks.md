# Never trust a webhook: authenticating payment callbacks

When a member pays into a project over M-Pesa, Safaricom's systems eventually call back to Changa's server with the result: success or failure, and (sometimes) an amount and a receipt number. Changa's original callback endpoint, `/payments/mpesa/callback`, looked at that request body, and if it said the payment succeeded, marked the contribution as paid.

Here's the uncomfortable question that finding asks: **what actually proves that request came from Safaricom?** The endpoint was a public URL. Nothing checked a signature, a shared secret, or even the source IP. Anyone who found or guessed that URL could POST a body claiming any contribution had succeeded, and Changa would believe them — because "believing them" was the entire implementation.

There's a second, subtler problem once you start looking at how M-Pesa's Daraja API actually behaves in practice: even *legitimate* callbacks aren't something you should blindly trust for the exact amount. The `stkpushquery` status-check endpoint doesn't reliably return the amount or receipt in a form you can safely treat as authoritative for crediting money. Following the illustrative pattern of "verify the callback, then credit whatever it says" would still leave a gap.

## What we changed

Two separate fixes, addressing two separate risks:

**Nobody unauthenticated gets to talk to the callback route.** Callback URLs now carry a per-provider secret token (`/payments/{provider}/callback/{token}`), checked with `hmac.compare_digest` — a constant-time comparison, so an attacker can't use response-timing differences to guess the token one character at a time. A request with the wrong token is rejected before any business logic runs.

**The callback body is never the source of truth for how much money moved.** Every incoming callback — verified or not — gets its raw body persisted immediately, unconditionally, before any other logic touches it. That's the durable evidence trail. But when it comes to actually crediting a contribution, the amount used is never anything read out of the callback: it's `contribution.amount`, the amount Changa itself initiated the payment for in the first place, confirmed successful via an authenticated, server-to-server status query back to the provider — not trusted from an inbound POST that anyone with the right URL could have sent.

## How we knew it worked

We tested both properties directly against a running server: a callback with a missing or wrong token gets rejected outright, and its raw body still lands in the audit table regardless of whether it was accepted — because a rejected callback is exactly the kind of thing you want a durable record of, not something to silently drop. We also had to be honest about what this fix *doesn't* do: it doesn't implement full HMAC signature verification of Safaricom's own signing scheme (Daraja's public sandbox doesn't consistently support it end-to-end), so the shared-secret-token approach is a deliberate, documented middle ground — meaningfully better than "trust whatever hits this URL," but not a replacement for provider-native request signing if and when that becomes available.

**The lesson:** a webhook URL is not a credential. If a request can move real money, something about that request — a signature, a token, a callback to a source you initiated — needs to prove where it came from, and the payload itself should never be the sole authority for how much money changed hands.
