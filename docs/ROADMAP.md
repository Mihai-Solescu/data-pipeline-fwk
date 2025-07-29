# Project Roadmap: General-Purpose Scientific Pipeline Framework

**Version:** 1.1.0
**Methodology:** Test-Driven Development (TDD)
**Target**: 2025-07-30

This document provides a detailed, atomic, and test-driven implementation plan. Each task is designed to be a small, verifiable step. "Key Concepts" links provide necessary context for implementation.

---

## Phase 1: The Foundation - Core Utilities & Project Setup (Est. 0.5 days)

**Goal:** Establish a deterministic and reliable foundation for the entire framework.

- [x] **Task 1.1: Initialize Project Structure**
  - [x] **Action:** Create the full directory structure as defined in the [ADD, Section 5](ADD.md#5-source-code-and-project-structure) (`+pipeline/+internal`, `docs`, `tests`, `examples`).
  - [x] **Action:** Initialize the Git repository and add a `.gitignore` file for MATLAB artifacts (e.g., `*.asv`, `slprj/`).

- [x] **Task 1.2: Implement the `Hasher` Utility**
  - **Key Concepts:**
    - [SHA-256 Cryptographic Hash Functions](https://en.wikipedia.org/wiki/SHA-2)
    - [MATLAB-Java Interface](https://www.mathworks.com/help/matlab/matlab_external/j-ava-libraries-and-matlab.html)
    - [MATLAB `getByteStreamFromArray`](https://www.mathworks.com/help/matlab/ref/getbytestreamfromarray.html)

  - [x] **Sub-Task 1.2.1: Test `hash_file`**
    - **TDD:** In `tests/test_Hasher.m`, write a test case that:
            1. Creates two identical temporary text files and one different one.
            2. Asserts that the hashes of the identical files are equal.
            3. Asserts that the hashes of the different files are not equal.
            4. Asserts that the hash of a known file content matches a pre-computed, known SHA-256 hash.

  - [x] **Sub-Task 1.2.2: Implement `hash_file`**
    - **Action:** In `+pipeline/+internal/Hasher.m`, create the static method `hash_file(filePath)`. Implement it using the `java.security.MessageDigest` class to compute the SHA-256 hash of the file's raw bytes.

  - [x] **Sub-Task 1.2.3: Test `hash_data`**
    - **TDD:** In `tests/test_Hasher.m`, write test cases for various MATLAB data types (double, string, struct) asserting that identical data produces identical hashes.

  - [x] **Sub-Task 1.2.4: Implement `hash_data`**
    - **Action:** In `+pipeline/+internal/Hasher.m`, create the static method `hash_data(data)`. Implement it using `getByteStreamFromArray` to serialize the data, then hash the resulting byte stream with the Java `MessageDigest`.

  - [x] **Sub-Task 1.2.5: Test `hash_struct`**
    - **TDD:** In `tests/test_Hasher.m`, write a test case that creates two structs with the same fields and values but in a different order of definition. Assert that `hash_struct` produces the exact same hash for both.

  - [x] **Sub-Task 1.2.6: Implement `hash_struct`**
    - **Action:** In `+pipeline/+internal/Hasher.m`, create the static method `hash_struct(s)`. Implement it by sorting the struct's field names alphabetically, creating a new struct in that order, and then calling `hash_data` on the sorted struct.

  - [ ] **Sub-Task 1.2.4: Add Error Handling to `Hasher`**
    - **TDD:** Write tests to verify that `hash_file` throws a specific error if the file doesn't exist.
    - **Action:** Implement the `try/catch` logic and throw the `pipeline:Hasher:FileError`.
  
  - [ ] **Sub-Task 1.2.5: Document `Hasher` Outputs**
    - **Action:** Add the `pipeline:Hasher:FileError` to the taxonomy in `CONTRIBUTING.md`.

---

## Phase 2: State and Persistence - The Storage Manager (Est. 1-1.5 days)

**Goal:** Implement a robust, testable component for all data I/O and state management.

- [ ] **Task 2.1: Implement the Storage Subsystem (excluding garbage utility)**
  - The implementation details and step-by-step instructions are maintained in:
    - [ADD Section 3.4: Storage System](ADD.md#34-the-storage-system)
    - [docs/instructions/storage.md](instructions/storage.md)
  - This includes all aspects of caching, persistence, file locking, provenance-based indexing, error handling, and logging, following strict test-driven development.
  - The garbage collection utility (`pipeline.gc`) will be implemented in Phase 7.
  - All low-level implementation and test steps are tracked in the above documents.

---

## Phase 3: The User Interface - Configuration & Recipes (Est. 1 day)

**Goal:** Define the public-facing API.

- [ ] **Task 3.1: Implement the `Recipe` Class and `get` Factory**
  - **TDD:** In a new test file, write tests that call `pipeline.get(...).where(...).transform(...)` and assert that the resulting `Recipe` object has the correct properties set.
  - **Action:** Create `+pipeline/Recipe.m` and `+pipeline/get.m`. Implement the methods to store their arguments as properties.

- [ ] **Task 3.2: Implement Parameter Space Generation**
  - **TDD:** Write unit tests that provide sample `config` structs and verify that the parameter generation logic correctly handles `'grid'`, `'list'`, and `param_filter` modes.
  - **Action:** Create the internal utility function for generating the final list of run structs.

---

## Phase 4: The Brains - Graph Logic & Resolution (Est. 1-2 days)

**Goal:** Implement the core intelligence of the framework.

- [ ] **Task 4.1: Implement the `DependencyGraph`**
  - **TDD:** Write tests for `+pipeline/+internal/DependencyGraph.m`. Provide it with valid DAG configurations and assert it produces a correct linear order. Provide it with a configuration containing a cycle and assert that it throws a specific, identifiable error.
  - **Action:** Implement the `DependencyGraph` class and its topological sort method.

- [ ] **Task 4.2: Implement the `Resolver`**
  - **Key Concepts:**
    - [Mocking Objects for Testing](https://www.mathworks.com/help/matlab/matlab_mock/what-is-a-mock-object.html)
  - **TDD:** Write tests for `+pipeline/+internal/Resolver.m`. The key here is to use a **mock `StorageManager` object**. This allows you to test the `Resolver`'s complex query logic (`.where`, `.transform`, `.all`) by feeding it a predefined cache index without any actual file I/O.
  - **Action:** Implement the `Resolver` class, which takes a `Recipe` object and a `StorageManager` instance and executes the recipe.

---

## Phase 5: The Conductor - The Sequential Orchestrator (Est. 2 days)

**Goal:** Assemble all components into a functional, end-to-end, **sequential** pipeline.

- [ ] **Task 5.1: Implement the Sequential `Orchestrator`**
  - **TDD:** This is the first major **end-to-end test**.
        1. Create a complete, simple project in the `examples/` folder.
        2. Write a test in `tests/` that calls `pipeline.run()` on this example.
        3. Assert that the correct final outputs are produced.
        4. Call `pipeline.run()` a second time and assert that the logs (or a mock `StorageManager`) show that results were loaded from cache.
        5. Modify a component function file, run again, and assert that only the necessary stages were re-computed.
  - **Action:** Create `+pipeline/+internal/Orchestrator.m` and `+pipeline/run.m`. Implement the main logic as a single-threaded process that iterates through the topologically sorted stages and runs, using all previously built components.

---

## Phase 6: Advanced Features - Parallelism & UX (Est. 1-2 days)

**Goal:** Enhance the working sequential framework.

- [ ] **Task 6.1: Refactor `Orchestrator` for Parallelism**
  - **Key Concepts:**
    - [MATLAB `parfeval`](https://www.mathworks.com/help/parallel-computing/parfeval.html)
    - [Asynchronous Programming](https://en.wikipedia.org/wiki/Asynchrony_(computer_programming))
  - **TDD:** Re-run the existing end-to-end tests from Phase 5. The parallel orchestrator **must** produce the exact same final results as the sequential one. Write new, more complex tests with independent branches to verify that it correctly executes tasks out of order.
  - **Action:** Modify the `Orchestrator` to implement the stateful, task-based scheduling model using a job registry and a `parfeval` worker pool.

- [ ] **Task 6.2: Implement Logging and Error Handling**
  - **TDD:** Write specific tests that:
        1. Use a component function designed to throw an error.
        2. Run the pipeline in `'fail_fast'` mode and assert that it terminates immediately.
        3. Run in `'resilient'` mode and assert that it completes, with the correct jobs marked as `FAILED` and `CANCELLED`.
        4. Test that different `config.logging` settings produce the expected output in the console and/or a log file.
  - **Action:** Integrate the logging and error handling logic into the `Orchestrator` and its job execution loop.

---

## Phase 7: Finalization & Distribution (Est. 1 day)

**Goal:** Prepare the framework for release.

- [ ] **Task 7.1: Implement the `gc` Utility**
  - **TDD:** Write a test that runs a pipeline, then runs a modified pipeline (which will orphan some data), calls `pipeline.gc()`, and verifies that the orphaned data is correctly removed from the HDF5 file.
  - **Action:** Create `+pipeline/gc.m` and its internal logic.

- [ ] **Task 7.2: Finalize Documentation and Examples**
  - **Action:** Write comprehensive user guides and tutorials in the `docs/` folder. Ensure the `examples/` project is clean, well-commented, and showcases all major features.

- [ ] **Task 7.3: Package the Toolbox**
  - **Key Concepts:**
    - [MATLAB "Package a Toolbox"](https://www.mathworks.com/help/matlab/matlab_apps/create-and-share-toolboxes.html)
  - **Action:** Use MATLAB's "Package Toolbox" tool to create the final `.mltbx` file for distribution.
