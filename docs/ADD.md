# Architecture Design Document: General-Purpose Scientific Pipeline Framework

**Version:** 0.12.0
**Date:** 2025-07-22

---

## 1. Architectural Principles

Our architecture is guided by the project's philosophy, translated into technical rules:

1. **Separation of Concerns:** The Executor engine is strictly decoupled from user-provided component functions.
2. **Declarative Configuration:** The entire workflow is defined in a MATLAB configuration file.
3. **Native Syntax:** Interfaces prefer idiomatic MATLAB patterns (programmatic recipes, function handles) over custom languages.
4. **Provenance-Based Caching:** All data is stored and retrieved based on a hash of its provenance, not its location or name.

---

## 2. Framework-User Interaction Model

This section describes how an end-user interacts with the framework once it is packaged as a MATLAB toolbox.

### 2.1. Toolbox Packaging and API

The framework will be distributed as a single, installable MATLAB toolbox file (`.mltbx`). This creates a read-only installation, ensuring a clean separation between the framework's internal code and the user's experiment code.

The public API will be exposed through a MATLAB package (e.g., `+pipeline`). The primary user-facing entry point will be a single function:

* `pipeline.run(config_object)`: Executes the entire pipeline as defined by the user-provided configuration object.

### 2.2. User-Provided Code and Hashing

The user provides their scientific logic as standard `.m` files. The framework is designed to find and hash these files without direct access.

* **Function Handles:** The user's configuration file references these scientific functions using **function handles** (`@`).
* **Path Discovery:** The framework's hashing mechanism will use `func2str()` to get the function name from the handle, and then `which()` to find the absolute file path. This allows it to read the file's content for hashing.
* **Prerequisite:** This requires that the user's function files be on the MATLAB path or in the current directory at runtime, which is standard MATLAB behavior.

### 2.3. Externalized Storage

All persistent data is stored externally in the user's workspace, never inside the toolbox installation folder.

* The path to the storage backend (e.g., the `.h5` file) is a **required field** in the user's configuration object (e.g., `config.storage.filepath`).
* The framework's **Storage Manager** component reads this path from the configuration and uses it exclusively for all read/write operations.

### 2.4. Integration with Version Control (Git)

The framework is designed to work seamlessly with external version control systems like Git without requiring any direct integration. This "version awareness" is an emergent property of the Provenance Hashing mechanism.

The **Code Hash** component of the Provenance Hash acts as the implicit version identifier for any computation. Because the hash is derived from the raw content of the `.m` file, any change to the code—no matter how small—results in a new hash.

This enables a robust workflow for researchers using Git: when a user switches branches, the framework automatically detects the code state on disk and uses the correct cached data for that exact version of the code.

---

## 3. System Architecture

The framework consists of several key internal components that work together.

### 3.1. The Pipeline Executor

The Executor is the central engine. Its workflow is as follows:

1. **Initialization:** Loads the configuration object and generates the list of all parameter runs.
2. **Graph Analysis:** Constructs a dependency graph from the `config.stages` collection and performs a topological sort to create a valid execution plan and detect cycles.
3. **Task Scheduling:** Operates as a task-based scheduler. It identifies all individual jobs (a stage for a given run) and submits ready jobs (whose dependencies are met) to a worker pool managed by the Parallel Computing Toolbox.
4. **Execution:** For each job, it uses the **Resolver** to gather inputs, checks the **Storage Manager** for a cached result, and if necessary, executes the component function. It then uses the **Storage Manager** to save the results according to the defined storage policy.

### 3.2. The Configuration

This is a MATLAB struct (we call it `config`). It defines the parameter space and the computational graph. The order of stages in the `config.stages` array does not matter.

A stage is defined by a struct with fields including:

* `.name`: A unique string identifier.
* `.function`: A function handle to the stateless component.
* `.dependencies`: A struct mapping input names to **Dependency Recipes**.
* `.param_dependencies`: A cell array of strings listing the parameters the stage depends on for granular hashing.
* `.outputs`: A cell array of structs, where each struct defines an output's `.name` and `.storage_policy` (`'persistent'`, `'memory_only'`, or a function handle).

### 3.3. The Dependency Recipe and Resolver

To ensure a flexible and MATLAB-native interface, dependencies are defined programmatically using a fluent interface provided by the **Resolver**.

* **Role:** The Resolver translates a dependency recipe into a specific **Provenance Hash**.
* **Syntax:** `resolver.get('source_stage').where(...).transform(...)`
* **Functionality:** The recipe specifies what data to get, the policy for retrieving it (e.g., finding a result based on a condition), and any in-line transformations (e.g., truncation) to apply before passing it to the consuming stage.

### 3.4. The Storage System

* **Storage Manager:** A component responsible for the physical reading and writing of data to either the in-memory cache or the persistent HDF5 file, given a specific Provenance Hash.
* **Provenance-Based Caching:** The HDF5 backend acts as a key-value store. Data is stored in a flat `/data/` group, where each entry's name is its unique Provenance Hash. This prevents data conflicts and enables version-aware caching.
* **Provenance Hash:** A unique fingerprint derived from three sources:
    1. The hash of the component function's M-file.
    2. The Provenance Hashes of all direct inputs (enabling cascading invalidation).
    3. A hash of the specific subset of parameters defined in `.param_dependencies`.

### 3.5. Stateless Components

User-provided scientific code must be written as stateless functions.

* They accept a single struct of inputs.
* They return a single struct of outputs.
* They must not perform any file I/O or access global state, ensuring they are pure and reproducible.

---

## 4. Source Code and Project Structure

To ensure maintainability, testability, and a clean separation between the public API and internal logic, the framework's source code is organized into a standard package structure.

The project root directory is laid out as follows:

```text
data-pipeline-framework/
│
├── +pipeline/
│   │
│   ├── +internal/
│   │   ├── Orchestrator.m
│   │   ├── Resolver.m
│   │   ├── StorageManager.m
│   │   ├── Hasher.m
│   │   ├── DependencyGraph.m
│   │   └── Job.m
│   │
│   ├── get.m
│   ├── run.m
│   └── Recipe.m
│
├── docs/
│   ├── adr/
│   │   └── ... (Architectural Decision Records)
│   ├── ADD.md
│   └── SRS.md
│
├── examples/
│   └── ... (Self-contained example projects)
│
└── tests/
    └── ... (Unit and integration tests)
```

### Component Roles

* **`+pipeline/`**: The main package folder. This creates the `pipeline` namespace and contains all user-facing API components.
  * **`run.m`**: The primary entry point for executing a pipeline.
  * **`get.m`**: The factory function for creating a dependency recipe.
  * **`Recipe.m`**: The class defining the fluent interface for dependency recipes.
* **`+pipeline/+internal/`**: A nested subpackage for all core engine components. This makes the implementation details private and inaccessible from the user's workspace, preventing misuse and creating a stable public API.
* **`docs/`**: Contains all project documentation, including the SRS, this ADD, and the ADR log.
* **`examples/`**: Contains one or more self-contained example projects that demonstrate how to use the framework.
* **`tests/`**: Contains all unit and integration tests for the framework's internal components.
