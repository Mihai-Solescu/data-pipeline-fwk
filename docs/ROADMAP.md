# Project Roadmap: General-Purpose Scientific Pipeline Framework

**Version:** 1.0.0
**Target:** 2025-07-30

This document outlines the implementation plan for the framework, broken down into logical phases. Each phase represents a major milestone and is designed to be developed and tested incrementally.

---

## Phase 1: The Foundation - Core Utilities & Project Setup (Est. 0.5 days)

**Goal:** Establish the project structure and create the fundamental, stateless utilities. This phase is critical for ensuring that the core of the framework is deterministic and reliable.

- [ ] **Task 1.1: Initialize Project Structure**
  - **Action:** Create the full directory structure as defined in the ADD (`+pipeline/+internal`, `docs`, `tests`, `examples`). Set up the Git repository.
  - **Deliverable:** An empty but correctly structured project.

- [ ] **Task 1.2: Implement the `Hasher` Utility**
  - **Action:** Create `+pipeline/+internal/Hasher.m` with the `hash_file`, `hash_data`, and `hash_struct` methods.
  - **TDD Approach:** Write a corresponding `tests/test_Hasher.m` file first. Create tests that verify `hash_file` consistency, deterministic `hash_struct` behavior regardless of field order, and correctness against a known SHA-256 hash.
  - **Deliverable:** A fully implemented and unit-tested `Hasher` class.

---

## Phase 2: State and Persistence - The Storage Manager (Est. 1-1.5 day)

**Goal:** Implement the component responsible for all state management. This allows us to test all data I/O logic in isolation before the complexities of the pipeline are introduced.

- [ ] **Task 2.1: Implement the `StorageManager`**
  - **Action:** Create `+pipeline/+internal/StorageManager.m`. Implement the dual-layer caching logic (L1 in-memory, L2 HDF5).
  - **TDD Approach:** Write `tests/test_StorageManager.m`. Tests should verify `save`/`load` for L2, correct promotion from L2 to L1, subsequent fast retrieval from L1, correct handling of `'memory_only'` policies, and the file-locking mechanism.
  - **Deliverable:** A fully implemented and unit-tested `StorageManager` class.

---

## Phase 3: The User Interface - Configuration & Recipes (Est. 1 day)

**Goal:** Define the public-facing API that the user will interact with. This phase focuses on the "shape" of the configuration, allowing us to write realistic test configurations for the next phases.

- [ ] **Task 3.1: Implement the `Recipe` Class and `get` Factory**
  - **Action:** Create `+pipeline/Recipe.m` and `+pipeline/get.m`. The methods (`.where`, `.transform`, etc.) should store their arguments as properties on the `Recipe` object.
  - **TDD Approach:** Write tests that verify that calling `pipeline.get(...).where(...)` produces a `Recipe` object with the correct properties set.
  - **Deliverable:** The public API for defining dependencies.

- [ ] **Task 3.2: Implement Parameter Space Generation**
  - **Action:** Write the internal logic that handles `param_mode`, `parameters`, `runs`, and `param_filter` to generate the final list of run structs.
  - **TDD Approach:** Unit-test this logic with various configurations to ensure it correctly generates grid, list, and filtered parameter sweeps.
  - **Deliverable:** A robust parameter generation utility.

---

## Phase 4: The Brains - Graph Logic & Resolution (Est. 1-2 days)

**Goal:** Implement the core intelligence of the framework. These components understand the structure of the pipeline and how to find the data for it.

- [ ] **Task 4.1: Implement the `DependencyGraph`**
  - **Action:** Create `+pipeline/+internal/DependencyGraph.m`.
  - **TDD Approach:** Write tests that feed it various `config.stages` arrays and verify that its topological sort method correctly identifies a linear execution order or throws a specific error for a cyclical graph.
  - **Deliverable:** A tested graph validation and analysis utility.

- [ ] **Task 4.2: Implement the `Resolver`**
  - **Action:** Create `+pipeline/+internal/Resolver.m`.
  - **TDD Approach:** Write tests for the `Resolver` using a **mock `StorageManager`**. This allows testing the `Resolver`'s logic (`.where`, `.transform`, `.all`) by feeding it a predefined cache index, completely isolating it from the actual HDF5 file.
  - **Deliverable:** A fully tested `Resolver` capable of executing dependency recipes.

---

## Phase 5: The Conductor - The Sequential Orchestrator (Est. 2 days)

**Goal:** Assemble all previously built components into a fully functional, end-to-end, but **sequential** pipeline executor. This is the most significant milestone.

- [ ] **Task 5.1: Implement the Sequential `Orchestrator`**
  - **Action:** Create `+pipeline/+internal/Orchestrator.m` and the public `+pipeline/run.m`. Implement the main loop as a simple, single-threaded process.
  - **TDD Approach:** Create a complete example project in the `examples/` folder. Write an end-to-end test that calls `pipeline.run()` on this example and verifies correct final outputs, caching on a second run, and cascading re-computation.
  - **Deliverable:** A working, sequential version of the framework.

---

## Phase 6: Advanced Features - Parallelism & UX (Est. 1-2 day)

**Goal:** Enhance the working sequential framework with advanced features for performance and user experience.

- [ ] **Task 6.1: Refactor `Orchestrator` for Parallelism**
  - **Action:** Modify the `Orchestrator` to implement the stateful, task-based scheduling model using `parfeval`.
  - **TDD Approach:** Re-run the existing end-to-end tests. The parallel orchestrator must produce the exact same final results as the sequential one.
  - **Deliverable:** A parallel-capable `Orchestrator`.

- [ ] **Task 6.2: Implement Logging and Error Handling**
  - **Action:** Integrate the logging and error handling logic into the `Orchestrator`.
  - **TDD Approach:** Write tests that trigger errors and verify that the `'fail_fast'` and `'resilient'` modes behave as expected. Test that logging outputs are correct at different verbosity levels.
  - **Deliverable:** A robust and user-friendly execution engine.

---

## Phase 7: Finalization & Distribution (Est. 1 day)

**Goal:** Prepare the framework for release.

- [ ] **Task 7.1: Implement the `gc` Utility**
  - **Action:** Create `+pipeline/gc.m`.
  - **TDD Approach:** Write a test that runs a pipeline, then runs a modified pipeline (orphaning some data), calls `gc`, and verifies that the orphaned data is correctly removed.
  - **Deliverable:** A working garbage collection utility.

- [ ] **Task 7.2: Finalize Documentation and Examples**
  - **Action:** Write comprehensive user guides in the `docs/` folder. Ensure the `examples/` project is clean, well-commented, and showcases all major features.
  - **Deliverable:** A well-documented project.

- [ ] **Task 7.3: Package the Toolbox**
  - **Action:** Use MATLAB's "Package Toolbox" tool to create the final `.mltbx` file.
  - **Deliverable:** The distributable framework.
