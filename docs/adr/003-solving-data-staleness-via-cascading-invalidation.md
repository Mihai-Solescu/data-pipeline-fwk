# ADR-003: Solving Data Staleness via Cascading Invalidation

**Status:** Accepted
**Date:** 2025-07-19

## Context

A critical challenge in any pipeline with cached results is **data staleness**. If a pipeline is structured as `A -> B`, a cached result for stage `B` can become invalid if the code or data from the upstream stage `A` changes, even if `B`'s own code remains untouched. A simple caching mechanism that only checks for changes in stage `B` would fail to detect this, leading to incorrect results based on outdated inputs. The framework must guarantee that all computations are performed on up-to-date inputs.

## Decision

The framework will solve data staleness by implementing the principle of **Cascading Invalidation**. The validity of any cached result will be determined by a unique **identity hash** that acts as a fingerprint for its entire computational provenance.

This identity hash will be a composite derived from three sources:

1. A hash of the stage's own **code**.
2. A hash of the stage's specific **parameters**.
3. The identity hashes of all its **inputs** from prerequisite stages.

Before executing a stage, the executor will calculate this expected identity hash. It will only reuse a cached result if it finds one associated with that exact, complete hash. A change anywhere in the upstream dependency chain will alter the input hashes, which in turn alters the downstream stage's identity hash, forcing re-computation.

## Consequences

* **Pros:**
  * **Guaranteed Correctness ✅:** This system ensures that a stage's results are always based on the correct version of its code, parameters, and all upstream dependencies. It completely eliminates the risk of using stale data.
  * **Automatic and Transparent Invalidation ⛓️:** The process is entirely automatic. Users do not need to manually clear caches or track dependencies; a change anywhere correctly invalidates everything downstream.

* **Cons and Future Considerations:**
  * **Inefficient Storage (by itself):** This decision, on its own, only solves the correctness problem. A naive implementation that stores the cache for a stage by name (e.g., `cache/stage_B`) would still overwrite previous results. This offers no storage optimization when, for example, switching between different versions of the code.
  * **Prerequisite for Better Storage:** The concept of a unique identity hash is the necessary foundation for a more optimal **content-addressable storage** system. In such a system, the hash itself would become the storage key, allowing multiple versions of a result to coexist without conflict. This more advanced storage architecture will be considered separately.
