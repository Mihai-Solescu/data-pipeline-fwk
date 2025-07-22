# ADR-015: Dual-Layer Caching for Performance and Parallel Safety

**Status:** Accepted
**Date:** 2025-07-22

## Context

The framework's performance and reliability depend on its caching system. A simple, single-layer cache that only interacts with the disk would create a significant I/O bottleneck. Furthermore, in a parallel execution environment, allowing multiple workers to directly access a single cache could lead to race conditions, file corruption, and non-deterministic behavior. The system requires a caching architecture that is fast, handles both temporary (in-memory) and persistent data, and is safe for concurrent operations.

## Decision

We will implement a **dual-layer caching system**, managed exclusively by the `StorageManager` component. This system separates the fast, run-local cache from the long-term persistent store.

1. **In-Memory Cache (L1):** A fast, temporary cache that exists only for the duration of a single `pipeline.run()` execution. It will be implemented using a `containers.Map`, where the key is the string-based Provenance Hash and the value is the complete MATLAB data object. This cache will hold all results computed or loaded during the current run.

2. **Persistent Cache (L2):** The long-term, on-disk HDF5 file. This serves as the permanent store for results whose `storage_policy` dictates persistence.

The `StorageManager` will orchestrate all interactions with these two layers according to a strict set of rules to ensure both performance and safety.

## Consequences

* **Pros:**
  * **High Performance ✅:** The L1 in-memory cache minimizes slow disk I/O. Any data product, once computed or loaded from disk, is served instantly from memory for all subsequent requests within the same pipeline run.
  * **Guaranteed Parallel Safety ⛓️:** This design completely prevents race conditions. Parallel workers are isolated and never interact with the cache directly. They return their results to the main, single-threaded Executor, which is the only process that communicates with the `StorageManager`. All cache updates and disk writes are therefore serialized and safe.
  * **Elegant Handling of Storage Policies:** The dual-layer system naturally handles both `'memory_only'` and `'persistent'` data. Memory-only data simply lives in the L1 cache for the run, while persistent data is promoted to the L2 cache.

* **Cons:**
  * **Higher Memory Footprint ❗:** This architecture makes a deliberate trade-off for performance. All data required for a given pipeline run (including data loaded from disk) is held in system memory. For workflows involving extremely large datasets that exceed available RAM, this could become a limitation.
