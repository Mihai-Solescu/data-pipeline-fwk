# ADR-002: Explicit Declaration of Global Stages and Automatic Setup Stage Optimization

**Status:** Accepted
**Date:** 2025-07-19

## Context

The framework's execution flow must accommodate different types of stages. Some stages are specific to a single parameter combination (**per-run**), while others operate on a broader scope (**global**). A clear mechanism is needed to define this behavior, ensuring that global stages act as execution barriers and that common optimization cases are handled efficiently.

## Decision

We will introduce an optional field, `.execution_mode`, to the stage definition in the configuration.

1. **Explicit Declaration:** Users can set `.execution_mode = 'global'` to explicitly designate a stage as a **global barrier**. The executor will ensure that all prerequisite stages for all parameter runs are completed before executing this stage. If the field is not present, it will default to `'per_run'`.

2. **Automatic Setup Stage Optimization:** As a critical optimization, the executor will automatically identify any stage that has **no dependencies on run-specific parameters**. Such a stage will be treated as a global **setup stage**, running only once at the beginning of the entire pipeline execution, regardless of its `.execution_mode` setting.

## Consequences

* **Pros:**
  * **Clear and Unambiguous Control ✅:** The `.execution_mode` flag makes the user's intent explicit, improving the readability and maintainability of the pipeline configuration. It provides direct control over which stages act as execution barriers.
  * **Automatic Efficiency 🚀:** The automatic detection and promotion of setup stages is a powerful, "zero-effort" optimization. It handles the most common global use case (e.g., initial data generation) without requiring any specific user action, simplifying the configuration for common patterns.
  * **Robust Scheduling:** This dual approach allows the scheduler to build a highly reliable execution plan. It can run all automatically detected setup stages first, then all per-run stages, and finally the explicitly declared global barrier stages.

* **Cons:**
  * **Slightly More Verbose Configuration:** For global stages that are not setup stages (e.g., a final analysis stage), the user is required to add the `.execution_mode` field. This is a minor trade-off for the clarity it provides.
  * **Potential for Logical Errors:** A user could misconfigure a stage that logically depends on an aggregate of all runs as `'per_run'`. While this is a logical error in the configuration, the framework's dependency resolver should be designed to detect such impossible dependencies and fail with a clear error message.
