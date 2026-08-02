# Mode 3 — Experimental, Out of Scope for v2

This mode is **not** part of the hardened 2-mode (A/B) engine and is kept
here for reference only. It predates the Mode A/B design and has a known
issue: `09_mode_3_engine.sql` hardcodes column names (`broker_code`,
`description`, `units`) specific to the demo `public.transactions` table,
contradicting the "no hardcoding / metadata-driven" claim that applies to
the rest of the framework.

If Mode 3 (synthetic expansion beyond historical/candidate limits) is
picked back up in a future version, it should be redesigned to be
registry-driven the same way Mode B is, rather than resumed as-is.
