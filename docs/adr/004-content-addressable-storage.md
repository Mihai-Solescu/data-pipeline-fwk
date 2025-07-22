# ADR-004: Content-Addressable Storage for Caching

**Status:** Accepted
**Date:** 2025-07-19

## Context

The framework requires a caching mechanism that is robust against changes to code, parameters, and dependencies. A simple location-based cache (e.g., saving results to `/results/<run_name>/<stage_name>`) is brittle. It fails to detect upstream changes and requires manual cache clearing when code is modified, making it unreliable and inefficient for iterative research.

## Decision

We will adopt a **content-addressable storage** strategy. This strategy decouples the data from any specific location and instead identifies it by a unique fingerprint of its computational provenance.

### The Provenance Hash 🔑

Each cached result will be identified by a **Provenance Hash**. This hash serves as the unique key for lookup and storage and is derived from all components that define the computation itself:

1. **Code Hash:** An SHA-256 hash of the stage's component M-file. This ensures any change to the algorithm's implementation invalidates the old result.
2. **Input Hashes:** The full Provenance Hashes of all direct data inputs from parent stages. This enforces cascading invalidation, guaranteeing that changes in upstream dependencies propagate downstream.
3. **Parameter Hash:** A hash of the specific subset of parameters that the stage depends on. This distinguishes between different runs in a parameter sweep.

### Components Excluded from the Hash

To ensure the hash accurately represents only the computation, several components are explicitly excluded:

* **Outputs:** The output data is the *result* of the computation, not a part of its definition. Including the output's hash in the key used to look it up would be a circular dependency—you can't know the hash of the result before you've computed it.
* **Stage Options (e.g., `storage_policy`):** Options like storage or execution policies are **post-computation directives**. They define what to do with a result *after* it's calculated or *how* inputs are selected, but they do not alter the numerical result of the computation itself. Including them would trigger unnecessary re-computation when only a non-computational setting is changed, violating the framework's efficiency goals.

## Consequences

* **Pros:**
  * **Guaranteed Correctness through Provenance Hashing:** The system ensures that a cached result is only ever used if its entire history—code, parameters, and all upstream dependencies—is identical. This completely eliminates the risk of using stale data.
  * **Conflict-Free, Version-Aware Storage 📦:** Because the hash is the key, results are never overwritten. A change to the code creates a new hash and a new result. This allows different versions of results to coexist, enabling a user to switch between git branches and have the framework automatically use the correct cached data for each branch without conflict.
  * **Automatic Data Deduplication:** If two different stages or runs happen to produce the exact same output from the exact same provenance, the data will only be stored once.

* **Cons:**
  * **Browser In-friendliness:** The storage file is not organized for human Browse. A dedicated utility or query mechanism is required to inspect results.
  * **Orphaned Data:** Old results are never deleted automatically. A separate **garbage collection** utility is required to scan for and remove data that is no longer reachable from the current pipeline configuration, thereby reclaiming storage space.
