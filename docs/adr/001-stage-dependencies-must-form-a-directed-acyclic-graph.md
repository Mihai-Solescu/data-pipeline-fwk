# ADR-001: Stage Dependencies Must Form a Directed Acyclic Graph (DAG)

**Status:** Accepted
**Date:** 2025-07-19

## Context

The framework allows users to define dependencies between computational stages, creating a workflow graph. If a user accidentally defines a circular dependency (e.g., stage A depends on B, which in turn depends on A), the pipeline executor could enter an infinite loop while trying to resolve the execution order. The system must be robust against such invalid configurations.

## Decision

We will enforce the rule that the stage dependency graph **must be a Directed Acyclic Graph (DAG)**. Before any computation begins, the Pipeline Executor will validate the entire graph to ensure it contains no cycles. The primary mechanism for this validation will be attempting to perform a **topological sort** on the graph of stages. If the sort is successful, the graph is a valid DAG; if it fails, it contains a cycle, and the pipeline will terminate with an informative error.

## Consequences

* **Pros:**
  * **Guaranteed Termination ✅:** This approach makes the framework fundamentally robust by preventing infinite dependency loops, ensuring that every valid pipeline will eventually complete or fail gracefully.
  * **Provides a Linear Execution Plan 🔗:** A successful topological sort produces a linear ordering of the stages. This provides the executor with a clear, pre-calculated plan for execution, which is essential for managing the workflow.
  * **Enables Complex Scheduling:** The linear plan allows the orchestrator to easily identify and schedule different types of stages correctly. It can execute setup stages first, then all per-run stages (potentially in parallel), and finally any global barrier stages, all while respecting the complex, cross-run dependencies.

* **Cons:**
  * **Minor Startup Overhead:** The framework incurs a small computational cost at startup to build the graph representation and perform the topological sort. This overhead is negligible compared to the runtime of the scientific computations themselves.
  * **Restricts User Configurations:** Users are explicitly prevented from creating cyclical workflows. This is a necessary design constraint that aligns with the logical flow of a reproducible data pipeline.
