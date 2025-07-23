# ADR-020: Enforcing Immutability of the Persistent Cache

**Status:** Accepted
**Date:** 2025-07-23

## Context

The framework's caching system must be completely trustworthy. A situation could arise where two different computations produce the same Provenance Hash but different data. We must define how the `StorageManager` behaves when it is asked to save data to a hash that already exists in the persistent (L2) cache.

## Decision

We will enforce the principle of **strict immutability** for the persistent cache. An attempt to save data to a Provenance Hash that already exists in the L2 cache is considered a **fatal architectural violation** and will be treated as an error.

The `StorageManager`'s `persist(hash, data)` method will first check if the hash exists in the HDF5 file. If it does, the `StorageManager` will **throw a specific, fatal error** (e.g., `StorageManager:OverwriteAttempt`) and terminate the save operation.

## Rationale: The Importance of Immutability

This decision is based on the premise that this scenario *should be architecturally impossible*. The Provenance Hash is designed to be a unique, deterministic fingerprint of a computational event. If the same hash is generated for two different results, it signals a critical bug.

### Why This Scenario Should Be Impossible

This error can only occur if one of two fundamental contracts is broken:

1. **A Framework Bug:** The `Hasher` utility is non-deterministic. This would be a critical bug in the framework itself.
2. **A User Violation:** A user's component function is not "pure." Its output depends on non-deterministic factors (e.g., `rand()`, `datetime('now')`) or external state, causing it to produce different results from the exact same inputs.

### Why Throwing an Error is the Most Elegant Solution

* **It Fails Loudly and Early ✅:** A silent overwrite would hide these critical bugs, leading to a race condition where the final cached result depends on which parallel worker finished first. This would create non-deterministic, untrustworthy results that are a nightmare to debug. A fatal error immediately surfaces the underlying bug and points the developer to the root cause.
* **It Guarantees Trustworthiness 🧬:** By enforcing a Write-Once-Read-Many (WORM) policy, the framework guarantees that once a result is persisted, its integrity is protected. This makes the cache a reliable source of truth.
* **It Simplifies the Mental Model:** The rule is simple and absolute: a Provenance Hash maps to one and only one result, forever.

This strict enforcement of immutability is a cornerstone of the framework's commitment to uncompromising reproducibility.
