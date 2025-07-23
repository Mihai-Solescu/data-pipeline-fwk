# ADR-021: Explicit `cache` and `persist` Methods for the StorageManager

**Status:** Accepted
**Date:** 2025-07-23

## Context

The `StorageManager` is responsible for saving new data products. A decision is required on the design of its API for this task. We considered a single, policy-aware `save(hash, data, policy)` method versus separate, explicit methods for handling the L1 (in-memory) and L2 (persistent) caches. The chosen design must align with our core principle of Separation of Concerns.

## Decision

We will implement two distinct, single-responsibility methods on the `StorageManager` for saving data:

1. **`cache(hash, data)`:** This method's only responsibility is to write the provided data object to the L1 in-memory cache. It is called by the `Orchestrator` for every newly computed result to make it immediately available to downstream stages.

2. **`persist(hash)`:** This method's only responsibility is to promote data from the L1 cache to the L2 persistent store. It takes only a hash, retrieves the corresponding data from the L1 cache, and writes it to the HDF5 file. It does not accept the data object as an argument.

The `Orchestrator` is responsible for the workflow: it always calls `cache()` first, then evaluates the storage policy, and only then conditionally calls `persist()`.

## Alternatives Considered

### Single `save(..., policy)` Method

A single method that accepts a policy (`'memory_only'` or `'persistent'`) and handles the logic internally. This was rejected because it violates the Separation of Concerns principle. It would force the low-level `StorageManager` to interpret high-level policy, bloating its API and tangling responsibilities between it and the `Orchestrator`.

## Rationale for the Chosen Design

This design is architecturally superior because it creates a perfectly clean separation of responsibilities.

* **Elegance and Simplicity:** Each component does one thing well. The `Orchestrator` orchestrates (makes decisions). The `StorageManager` stores (performs physical I/O). The `StorageManager`'s API is minimal and focused, making it easier to implement, test, and maintain.
* **Clarity of Workflow:** The two separate calls made by the `Orchestrator` make the data flow explicit and unambiguous: a result is always cached in memory first, and then conditionally persisted.
* **Efficiency:** This design avoids redundant data passing. The `persist` command is a lightweight signal, not a heavy data transfer, as the `StorageManager` already has the data in its L1 cache.

This explicit, two-method approach creates a more robust, maintainable, and conceptually clean architecture.
