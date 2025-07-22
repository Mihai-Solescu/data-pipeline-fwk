# ADR-011: Support for Mixed-Scope Dependencies

**Status:** Accepted
**Date:** 2025-07-22

## Context

A simple dependency model might restrict a per-run stage to only depend on data from the same run. This is insufficient for common scientific analyses where a per-run calculation needs to be contextualized by a global property. For example, normalizing a run's error score requires knowing both the run's local error and the global maximum error from all runs. The framework must provide an elegant way to supply a single stage with inputs from different scopes.

## Decision

We will explicitly support **mixed-scope dependencies**. A stage's `.dependencies` struct can contain multiple dependency recipes, where each recipe can resolve to a different scope. The framework will allow a single stage to depend on both per-run data and globally aggregated data simultaneously.

The **Resolver** will process each dependency recipe independently. The **Orchestrator** will ensure that all dependencies for a stage—both local and global—are fully resolved before that stage's job is scheduled for execution.

**Example Implementation:**
A `normalize_error` stage would define two dependencies:

1. A per-run recipe to get its local error: `resolver.get('compute_error', {'model_error'}).where(...)`
2. A global recipe to get the aggregate maximum: `resolver.get('compute_error', {'model_error'}).all().transform(...)`

## Consequences

* **Pros:**
  * **Enables Critical Scientific Patterns ✅:** This feature is essential for common tasks like normalization, ranking, or calculating relative performance, which are fundamental to many scientific workflows.
  * **High Expressiveness and Flexibility 🚀:** It allows users to construct highly sophisticated data flows declaratively in the configuration, without complicating the scientific component code.
  * **Leverages Existing Architecture 🔗:** This functionality is a natural extension of the existing Resolver and Orchestrator components. It does not require a new system, but rather relies on the power of the dependency recipe and the stateful scheduler.

* **Cons:**
  * **Creates Complex Scheduling Constraints ❗:** A per-run stage with a global dependency creates an implicit synchronization barrier. The Orchestrator's scheduling logic must be robust enough to understand that it cannot schedule *any* of these per-run jobs until the global dependency they all share has been fully computed and aggregated.
  * **Potential for Reduced Parallelism:** If many per-run stages depend on a global aggregate, they will all be blocked until the end of the preceding stage, potentially leaving parallel workers idle. This is an inherent trade-off for this type of analysis.
