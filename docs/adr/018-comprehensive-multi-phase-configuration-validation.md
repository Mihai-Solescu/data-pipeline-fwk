# ADR-018: Comprehensive Multi-Phase Configuration Validation

**Status:** Accepted
**Date:** 2025-07-22

## Context

A malformed, logically inconsistent, or environmentally incompatible configuration can lead to cryptic runtime errors, wasting significant user time and computational resources. To provide a robust and user-friendly experience, the framework must detect the full spectrum of potential configuration errors as early as possible.

## Decision

We will implement a strict, comprehensive, and multi-phase **"Fail-Fast" validation routine** at the very beginning of the `pipeline.run()` execution. The Executor will validate the entire configuration against a formal contract before any computation begins. If any check fails, the pipeline will terminate immediately with a clear, specific error message.

The validation will be performed in three phases:

1. **Schema and Structural Validation:** Checks the basic "grammar" of the configuration (e.g., required fields, data types, unique names).
2. **Graph and Logical Validation:** Checks the "meaning" and integrity of the workflow, including:
    * Verifying the dependency graph is a valid DAG via topological sort.
    * Ensuring all dependency recipes and parameter links are valid.
    * Confirming the parameter sweep will result in at least one run.
3. **Environment Validation:** Checks for external prerequisites, such as:
    * The existence of required toolboxes (e.g., Parallel Computing Toolbox).
    * Write permissions for the specified storage path.

## Consequences

* **Pros:**
  * **Improved User Experience ✅:** Prevents user frustration by catching a wide range of errors early and providing actionable feedback.
  * **Prevents Wasted Computation 🚀:** Ensures that no time or resources are spent on a pipeline that is guaranteed to fail due to a configuration or environment issue.
  * **Enforces a Stable API:** Formalizing the contract makes the framework's public-facing API more robust and easier to maintain.

* **Cons:**
  * **Minor Startup Overhead:** Adds a small, one-time computational cost at the beginning of each run. This overhead is negligible.
  * **Requires Strictness:** The framework will be less permissive of minor configuration mistakes, a deliberate trade-off for correctness and reliability.
