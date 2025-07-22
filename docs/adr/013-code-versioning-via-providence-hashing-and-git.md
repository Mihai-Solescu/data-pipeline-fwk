# ADR-013: Code Versioning via Provenance Hashing and Git

**Status:** Accepted
**Date:** 2025-07-22

## Context

The framework must handle the evolution of scientific code. When a user modifies an algorithm or switches between different versions of their code (e.g., using Git branches), the framework must ensure that the correct corresponding data is used, and that computations are re-run only when necessary. An explicit versioning system could be built into the framework, but this would add significant complexity.

## Decision

We will **not** implement an explicit code versioning system within the framework. Instead, we will rely on the combination of two specialized tools working in concert:

1. **External Version Control (Git):** For managing the state, history, and branches of the user's codebase.
2. **The Framework's Provenance Hashing:** The `Code Hash` component of the Provenance Hash will serve as the implicit, automatic version identifier for all cached data.

## Consequences

* **Pros:**
  * **Perfect Separation of Concerns ✅:** This approach lets each tool do what it does best. Git manages code, and the framework manages the data derived from that code. The framework does not need to reinvent a complex and likely inferior version control system.
  * **"It Just Works" User Experience 🚀:** A user's workflow is simple and intuitive. They use standard Git commands (`git checkout`, `git pull`) to manage their code. When they re-run `pipeline.run()`, the framework automatically detects the code state on disk and uses the correct data without requiring any special flags or commands.
  * **Conflict-Free Caching 🔗:** Results from different code versions (e.g., from different Git branches) can coexist peacefully in the cache, as each is tied to its unique code hash. This makes comparing results between branches trivial.
  * **Reduced Framework Complexity:** This decision keeps the framework's core logic simpler and more focused on its primary task of pipeline orchestration.

* **Cons:**
  * **Requires User Discipline:** This model relies on the user adopting good version control practices. The framework itself cannot enforce this.
  * **Risk of Uncommitted Changes ❗:** If a user runs the pipeline with uncommitted local changes, the results will be correctly tied to the hash of that specific, uncommitted code state. However, if the user later discards those changes without committing them, the provenance of that data becomes difficult to track in Git, even though it remains valid within the framework's cache.
