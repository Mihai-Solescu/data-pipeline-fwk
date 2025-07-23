# ADR-019: Orchestrator Responsibility for Conditional Storage Policy Evaluation

**Status:** Accepted
**Date:** 2025-07-23

## Context

The framework supports conditional storage policies via function handles (e.g., `@(p, all) p.rank == max([all.rank])`). This logic requires high-level context, specifically the parameters of the current run (`p`) and the entire parameter space of the experiment (`all`). A decision must be made about which component is responsible for evaluating this policy: the high-level `Orchestrator` or the low-level `StorageManager`.

## Decision

The responsibility for **evaluating** the conditional storage policy belongs exclusively to the **Orchestrator**.

When a job completes, the `Orchestrator` will first cache the result in memory. It will then evaluate the stage's `storage_policy` function handle, as it already possesses the necessary context (`current_params`, `all_params`). Based on the boolean result, it will then issue a simple, explicit command to the `StorageManager` (e.g., `storageManager.persist(hash, data)`).

## Alternatives Considered

### The `StorageManager` is Responsible

In this model, the `Orchestrator` would pass the policy and its required parameters down to the `StorageManager`'s `save` method.

* **Pros:** Appears to encapsulate all storage-related logic in one place.
* **Cons:** This is a flawed abstraction. It violates the **Separation of Concerns** principle by forcing a low-level utility (the `StorageManager`) to understand high-level experimental context (the parameter space). This would lead to a complex, "leaky" API for the `StorageManager` and create tangled dependencies.

## Rationale for Choosing the Orchestrator

The chosen approach is architecturally superior and more elegant for several reasons:

* **Maintains Separation of Concerns ✅:** The `Orchestrator` (the "brain") is responsible for high-level logic and decision-making. The `StorageManager` (the "hands") is a simple, "dumb" utility responsible only for the physical acts of reading and writing. This is a clean separation.
* **Creates a Clean, Focused API 🔗:** The `StorageManager`'s API remains simple and explicit (e.g., `cache()`, `persist()`). It does not need to be cluttered with arguments that are irrelevant to its core task. This makes it easier to implement, test, and maintain.
* **Improves Logical Cohesion:** The decision-making logic (the policy evaluation) resides in the component that already holds all the necessary data and context (the `Orchestrator`).

This design ensures that each component has a single, well-defined responsibility, which is a hallmark of a robust and maintainable architecture.
