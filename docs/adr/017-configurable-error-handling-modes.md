# ADR-017: Configurable Error Handling Modes

**Status:** Accepted
**Date:** 2025-07-22

## Context

A failure in one part of a large, parallel pipeline (e.g., in one run of a 1000-run parameter sweep) should not necessarily halt all other independent work. However, during initial development and debugging, a user might prefer the pipeline to terminate immediately upon the first error. The framework must support both of these use cases.

## Decision

We will support two distinct, user-configurable error handling modes, controlled by the `config.error_mode` field.

1. **`'resilient'` (Default):** This mode is designed for production runs and large sweeps. When a job fails, the Executor will:
    * Mark the job as `FAILED` and log the error.
    * Traverse the dependency graph downstream and mark all dependent jobs as `CANCELLED`.
    * Continue to execute any other independent branches of the graph.
    * Provide a final summary report of all job statuses.

2. **`'fail_fast'`:** This mode is designed for debugging. The first time any job fails, the Executor will immediately terminate the entire pipeline run and report the critical error.

## Consequences

* **Pros:**
  * **Empowers the User ✅:** Gives the user explicit control over the framework's behavior, allowing them to choose the best strategy for their current task (production vs. debugging).
  * **Maximizes Throughput 🚀:** The default `'resilient'` mode ensures that a single faulty run does not waste computational resources by preventing other valid, independent runs from completing.
  * **Improves Debugging Workflow:** The `'fail_fast'` mode allows for rapid iteration during development without waiting for the entire pipeline to run.

* **Cons:**
  * **High Implementation Complexity ❗:** The `'resilient'` mode significantly increases the state management complexity of the Orchestrator, which must be able to correctly track `FAILED` and `CANCELLED` states and navigate the dependency graph to prune failed branches.
