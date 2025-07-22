# ADR-005: Granular Parameter Dependencies for Hashing

**Status:** Accepted
**Date:** 2025-07-20

## Context

The Provenance Hash (defined in ADR-004) relies on a hash of the stage's parameters. A naive implementation would hash the entire parameter struct for a given run. This is inefficient. For example, in a machine learning pipeline, a data preprocessing stage might not depend on the `learning_rate`. If the `learning_rate` changes, the preprocessing stage should not be re-executed, but a naive hash of all parameters would incorrectly trigger a re-run.

## Decision

The framework will support **granular parameter dependencies**. The Provenance Hash for a stage will **not** be based on the entire run's parameter struct. Instead:

1. The stage definition in the configuration will require an explicit declaration of which parameters it depends on (e.g., `.param_dependencies = {'embedding_dim', 'delay'}`).
2. Before hashing, the executor will create a temporary struct containing only the subset of parameters declared in `.param_dependencies`.
3. Only this subset struct will be hashed and included in the stage's final Provenance Hash.

If `.param_dependencies` is not specified, the framework will default to the safe but inefficient behavior of hashing all parameters for that run.

## Consequences

* **Pros:**
  * **Maximal Computational Reuse ✅:** This provides a significant efficiency gain by preventing unnecessary re-computation. It allows unrelated parts of a parameter sweep to evolve independently, saving considerable time and resources.
  * **Increased Clarity and Explicitness 🔗:** It forces the user to explicitly declare a stage's true dependencies, making the configuration more self-documenting and easier to reason about.

* **Cons:**
  * **Increased Configuration Verbosity:** This adds a new field that must be managed by the user for each stage to gain the optimization benefit.
  * **Risk of User Error ❗:** The most significant risk is that a user might forget to list a parameter that their component function actually uses. This would lead to incorrect cache reuse (a silent error), as the framework would not detect the parameter change. This risk must be mitigated through clear documentation and user diligence.
