# ADR-022: Centralized Taxonomy for Errors and Logs in CONTRIBUTING.md

**Status:** Accepted
**Date:** 2025-07-23

## Context

For the framework to be maintainable and debuggable, all of its possible outputs — both errors and significant log messages — must be documented. We considered two primary approaches for this documentation: a hybrid model with high-level conventions in a central document and detailed specifics in in-code comments, versus a single, exhaustive central document.

## Decision

We will adopt a **single, centralized taxonomy** for all custom errors and significant log messages. This complete reference will be maintained in the `CONTRIBUTING.md` file.

All entries in this taxonomy will follow a strict, three-part naming convention to ensure clarity and traceability:

**`pipeline:<ComponentName>:<Identifier>`**

* **`pipeline:`:** A consistent prefix for all framework-generated outputs.
* **`<ComponentName>`:** The CamelCase name of the internal component where the error or log originates (e.g., `StorageManager`, `Resolver`).
* **`<Identifier>`:** A concise, CamelCase name for the specific error or log event (e.g., `OverwriteAttempt`, `JobComplete`).

## Rationale

While a hybrid approach (documentation in both code and a central guide) has benefits in large teams, the single-document strategy is more elegant and efficient for the current scale of the project.

* **Single Source of Truth ✅:** For a solo developer or a small, focused team, having one definitive "dictionary" of all possible framework outputs is highly efficient. It provides a holistic view of the system's behavior and is easier to maintain than synchronizing multiple documentation sources.
* **Clarity through Convention 🔗:** The strict `pipeline:<ComponentName>:<Identifier>` naming convention is sufficiently informative to allow a developer to immediately trace any output back to its source component in the codebase. This mitigates the "loss of proximity" drawback of not having the documentation directly in the code comments.
* **Establishes a Clear Contribution Guide:** Placing this taxonomy in `CONTRIBUTING.md` establishes a clear pattern for future development. Any new contribution that adds an error or significant log message must also include an update to this central document, making it a core part of the development workflow.

This approach provides the best balance of clarity, maintainability, and comprehensiveness for the project's current needs.
