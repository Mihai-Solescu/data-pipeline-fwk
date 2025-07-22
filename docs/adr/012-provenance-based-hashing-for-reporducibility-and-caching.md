# ADR-012: Provenance-Based Hashing for Reproducibility and Caching

**Status:** Accepted
**Date:** 2025-07-22

## Context

The framework's core promise is to provide both computational efficiency and uncompromising reproducibility. This requires a caching mechanism that can reliably determine if a result for a given computational stage already exists. A naive approach, such as checking file modification times or using simple content-based hashing (hashing the output data itself), is insufficient. A content-based hash cannot be calculated until after the computation is complete, creating a chicken-and-egg problem for cache lookups. Furthermore, the system must robustly handle complex data dependencies, including fan-in nodes, global barriers, and mixed-scope inputs, without ever using stale data.

## Decision

We will adopt a **Provenance-Based Hashing** system. This strategy creates a unique fingerprint for every computational event based on its complete origin, or "provenance," rather than its resulting data content. This allows the framework to calculate an expected hash *before* executing a stage, enabling efficient cache lookups.

The **Provenance Hash** for any data product is a single, deterministic hash derived from three and only three components:

1. **Code Hash:** An SHA-256 hash of the component `.m` file that performs the computation.
2. **Granular Parameter Hash:** An SHA-256 hash of a struct containing only the specific subset of parameters the stage depends on.
3. **Input Hashes:** An SHA-256 hash derived from a deterministically sorted list of the Provenance Hashes of all direct data inputs.

This single, consistent formula is the foundation for all caching and dependency tracking in the framework.

## Rationale and Implementation

This approach is the most elegant solution because its single, consistent hashing rule gracefully handles all required scenarios, from simple pipelines to complex computational graphs.

#### 1. Solves the Cache Lookup Problem

By hashing the *inputs* to a computation (its provenance), we can generate an expected hash and check for its existence in the cache **before** running the expensive computation itself. This is the fundamental mechanism that enables computational efficiency.

#### 2. Guarantees Reproducibility via Cascading Invalidation

Including the hashes of all inputs in a stage's own hash creates a chain of cryptographic dependency. A change to any upstream stage (its code or parameters) will change its hash, which in turn changes the hash of all its direct and indirect dependents. This automatic **cascading invalidation** guarantees that no stage ever runs with stale data.

#### 3. Handles Complex Graph Structures Deterministically

The hashing rule is applied consistently regardless of the graph's shape:

* **Fan-in and Global Stages:** For a stage with multiple inputs (e.g., a fan-in node or a global barrier that depends on 100 per-run results), the framework gathers the Provenance Hashes of all inputs into a list. This list is **alphabetically sorted** before being hashed. This ensures the final hash is deterministic and independent of the order in which the parallel jobs complete.
* **Multi-Output Stages:** A stage that produces multiple outputs (e.g., `U`, `S`, `V` from an SVD) is treated as a single computational event. The framework calculates **one** Provenance Hash for the event and stores the entire result set (e.g., a struct of outputs) under that single hash. Downstream stages use the Resolver to request specific fields from this result set.

#### 4. Manages Mixed-Scope and Transformed Inputs Elegantly

The system does not need a special mechanism for "global" or "transformed" inputs. These are simply data products with their own valid provenance.

* **Example (Mixed Scope):** A stage needing a `global_max` value depends on the result of a transformation (`.transform(@(all) max([all.data]))`). The framework computes a Provenance Hash for this transformation itself, based on the transform's code (the function handle) and all of its inputs (the hashes of all data points). This resulting `Hash_of_global_max` is then just another hash in the sorted input list for the consuming stage. The `Hasher` utility remains agnostic to the "scope"; it just sees a list of input hashes.

## Consequences

* **Pros:**
  * **Conceptual Simplicity ✅:** A single, consistent hashing rule governs the entire system, making the core logic robust and easy to reason about.
  * **Uncompromising Reproducibility 🧬:** The system provides a cryptographic guarantee that a result is the exact product of its stated origins.
  * **Maximum Efficiency 🚀:** The combination of provenance hashing and granular parameter dependencies ensures that the absolute minimum number of computations is performed.
  * **Decoupled Architecture 🔗:** The `Hasher` is a simple, stateless utility. All complex logic for gathering inputs and managing the graph resides in the Orchestrator and Resolver, adhering to the principle of separation of concerns.

* **Cons:**
  * **Requires Garbage Collection:** This non-destructive caching strategy means old results are never overwritten, only orphaned. A separate garbage collection utility is required to reclaim storage space.
  * **Non-Human-Readable Keys:** The cache is indexed by SHA-256 hashes, making direct browsing of the storage backend unintuitive.
