# Software Requirements Specification: General-Purpose Scientific Pipeline Framework

**Version:** 0.18.0
**Date:** 2025-07-22

---

## 1. Project Philosophy and Vision

### 1.1. Vision

To create a modular, reusable, and efficient MATLAB framework for executing complex, multi-stage scientific computing workflows. The framework will serve as a general-purpose "build system" for data analysis, driven entirely by a user-defined configuration file. Its purpose is to accelerate research by ensuring reproducibility, eliminating redundant computations, and enabling advanced, user-driven optimization strategies.

### 1.2. Guiding Philosophy

* **MATLAB-Native Experience:** The framework will feel like a natural extension of MATLAB, using idiomatic syntax and prioritizing interactivity over external tools or languages.
* **Uncompromising Reproducibility:** Every result will be verifiably reproducible through a robust content-hashing mechanism that tracks the full provenance of data.
* **Declarative Configuration as Code:** Users will declare *what* the pipeline should do in a version-controllable MATLAB file, separating the workflow definition from the execution engine.
* **Aggressive Separation of Concerns:** A strict separation will be maintained between scientific logic, optimization logic, and framework logic.
* **Flexible and Composable Data Flow:** The framework will be a toolkit for building complex computational graphs, not just a linear pipeline runner.

---

## 2. Core Objectives

* **Modularity & Reusability**: Decouple the pipeline's execution logic from the scientific computation itself.
* **Reproducibility**: Ensure a given configuration and dataset will always produce the exact same results. This includes ensuring that results are cryptographically tied to the exact version of the code that produced them, allowing seamless integration with version control systems like Git.
* **Computational Efficiency**: Avoid re-running any stage unless its code, inputs, or relevant parameters have changed.
* **Extensibility**: Allow users to add new stages and parameters by modifying only the configuration file and adding new, isolated component functions.
* **User-Driven Optimization**: Empower scientists to define custom optimization policies for data persistence and retrieval.

---

## 3. Scope

### 3.1. In Scope

* A generic pipeline executor engine.
* A configuration system for defining parameter sweeps and a computational dependency graph.
* Management of a single-file, HDF5-based storage backend, including a **garbage collection utility**.
* A configurable, dual-output **logging system** with multiple verbosity levels.
* User-configurable **error handling modes** (resilient and fail-fast).
* An in-memory caching mechanism for a single pipeline run.
* Automatic dependency checking and result invalidation based on content hashing.
* Validation that the stage dependencies form a Directed Acyclic Graph (DAG).
* Support for singleton (setup), per-run, and global (barrier) stages.
* Task-based parallelism for executing independent jobs concurrently.
* Support for stateless, single-responsibility computational component functions.

### 3.2. Out of Scope

* A graphical user interface (GUI).
* Intra-run parallelism (parallelizing the DAG itself within a single run).
* Distributed computing across multiple machines.
* Real-time or streaming data processing.
* The scientific algorithms themselves, which are treated as plug-ins.
* A formal parameter schema and validation system (deferred to a future version).

---

## 4. Functional Requirements (FR)

* **FR-1**: The system shall execute a computational pipeline defined by a collection of stage definitions.
* **FR-2**: The system shall generate a set of parameter runs based on grid or list definitions, and optionally filter them.
* **FR-3**: The system shall persist results to a content-addressable storage backend.
* **FR-4**: The system shall not re-execute a stage if a valid result, determined by its provenance hash, already exists.
* **FR-5**: The system shall support singleton (setup), per-run, and global (barrier) stage execution modes.
* **FR-6**: The system shall allow users to define conditional storage policies for stage outputs.
* **FR-7**: The system shall support advanced, user-defined data retrieval and transformation policies to enable intelligent, cross-run data sharing.
* **FR-8**: The system shall automatically detect any change to a component function's source code by comparing cryptographic hashes (e.g., SHA-256).
* **FR-9**: The system shall provide a utility to perform garbage collection, deleting any cached data that is not reachable from a given pipeline configuration, in order to reclaim storage space.
* **FR-10**: The system shall provide a logging mechanism that can output to both the MATLAB Command Window and an optional log file, as specified in the configuration.
* **FR-11**: The system shall support at least three named verbosity levels (`'info'`, `'debug'`, `'silent'`) for logging, with separate controls for console and file outputs.
* **FR-12**: The system shall support two user-configurable error handling modes: `'resilient'` (continue executing independent jobs upon failure) and `'fail_fast'` (terminate immediately upon any failure).
* **FR-13**: In resilient mode, the system shall log all errors from failed jobs and provide a final summary report of all job statuses (`SUCCEEDED`, `CACHED`, `FAILED`, `CANCELLED`).
* **FR-14**: The system shall perform a comprehensive validation of the user-provided configuration at startup. If any validation check fails, the pipeline must terminate immediately with a clear and informative error message. Validation must include, at a minimum verification that the dependency graph is a DAG (no circular dependencies), and ensuring all stage dependencies refer to existing, defined stages.

---

## 5. Non-Functional Requirements (NFR)

* **NFR-1 (Performance)**: The framework overhead for executing a stage with no computational work shall be less than 300 milliseconds.
* **NFR-2 (Usability)**: Adding a new stage shall only require creating a component function and adding its definition to the configuration.
* **NFR-3 (Reliability)**: The pipeline shall be resumable; an interrupted run can be continued without re-computing completed stages.
* **NFR-4 (Maintainability)**: The framework's code shall be modular with a strict separation of concerns.

---

## 6. Use Cases and Scenarios

* **Scenario 1: Multi-Scale Model Analysis:** The framework shall allow a user to compute a computationally expensive result (e.g., SVD) once at a high fidelity and have multiple downstream stages intelligently retrieve and reuse that single result, transformed for their specific needs (e.g., truncated to a lower rank).
* **Scenario 2: Hyperparameter Sweep with Global Analysis:** The framework shall support running a large number of independent model training jobs, followed by a single global analysis stage that gathers and processes a specific metric from all previous jobs.
* **Scenario 3: Resuming After Code Change:** After a user modifies the code for a single stage in a multi-stage pipeline, re-running the pipeline shall automatically re-execute only the modified stage and any downstream stages that depend on it.
* **Scenario 4: Singleton Data Source:** The framework shall be able to generate a single, master dataset once at the beginning of a workflow, which is then used as a source for multiple per-run stages that select or subset it based on their parameters.
* **Scenario 5: Global dependency in local stage** A scientist is analyzing the error from multiple model runs. For each individual run, they want to compute a normalized error score, which is the run's raw error divided by the global maximum error found across all runs in the experiment.
* **Scenario 6: Ingesting an External Data File:** A user has a pre-existing dataset stored in an external file (e.g., a `.csv` or `.mat` file). The first stage of the pipeline must read this file to begin the workflow. The path to this external file shall be configurable as a parameter for the run.
