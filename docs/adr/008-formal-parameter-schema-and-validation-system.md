# ADR-008: Formal Parameter Schema and Validation System

**Status:** Deferred
**Date:** 2025-07-20

## Context

The framework currently treats parameters as simple, untyped values defined directly within an experiment's configuration file. This approach lacks a formal system for validating parameter types, ranges, or inter-dependencies before a pipeline begins. Furthermore, it provides no mechanism for defining the properties of parameters, such as the inherent order of ordinal values (e.g., 'LOW' < 'MEDIUM' < 'HIGH'). This can lead to runtime errors that could have been caught earlier and limits the robustness of advanced filtering and data retrieval features.

## Decision

We will **defer** the implementation of a formal parameter schema system to a future version.

The proposed system would involve a centralized "data dictionary" file that defines the type, valid range, default value, and order for all potential parameters. The Pipeline Executor would use this schema to validate an experiment's configuration at startup. While this feature would significantly increase the framework's robustness and maintainability, its implementation adds considerable complexity to the initial development scope.

For the current version, the framework will continue to operate without a formal schema, relying on user diligence to ensure parameter correctness.

## Consequences

* **Pros of Deferring:**
  * **Reduced Initial Scope ✅:** Postponing this feature allows development to focus on the core, essential functionality first: the DAG executor, the hashing mechanism, and the content-addressable storage backend.
  * **Simpler User Experience (for now) 👍:** The current approach is simpler for new users and small projects. It avoids the overhead of creating and maintaining a separate schema definition file.
  * **Faster Prototyping:** Researchers can quickly prototype new experiments and add new parameters on the fly without being constrained by a predefined schema.

* **Cons of Deferring (and Rationale for Future Implementation):**
  * **Delayed Error Detection ❗:** Without pre-execution validation, errors like typos in parameter names or out-of-range values will only be discovered at runtime, potentially after significant computation time has already been spent.
  * **No Support for Ordinal Parameters:** The framework cannot intelligently sort or filter based on a defined order for non-alphanumeric parameters. This limits post-processing and visualization capabilities.
  * **Reduced Robustness for Advanced Features:** Advanced dependency resolvers (e.g., `policy=max&by=rank`) rely on convention. A schema would allow the framework to validate these lookup queries, preventing logical errors and typos.
  * **Lack of Centralized Definitions:** Parameter definitions may be repeated or inconsistent across different experiment configurations, violating the "Don't Repeat Yourself" (DRY) principle and hindering long-term maintainability.
