# Architecture Design Document: General-Purpose Scientific Pipeline Framework

**Version:** 0.21.0
**Date:** 2025-07-22

---

## 1. Architectural Principles

Our architecture is guided by a core philosophy, translated into five technical rules:

1. **MATLAB-Native Experience:** The framework must feel like a natural extension of MATLAB. All user-facing interfaces will use idiomatic MATLAB syntax (e.g., programmatic recipes, function handles) over custom string-based languages.
2. **Uncompromising Reproducibility:** Every result must be verifiably reproducible. Caching is not just for speed; it is a guarantee of correctness, achieved through provenance-based hashing.
3. **Declarative Configuration as Code:** Users will declare *what* the pipeline should do in a version-controllable MATLAB file, separating the workflow definition from the execution engine.
4. **Aggressive Separation of Concerns:** A strict separation will be maintained between scientific logic (in component functions), optimization logic (in dependency recipes), and framework logic (in the executor).
5. **Flexible and Composable Data Flow:** The framework is a toolkit for building complex computational graphs. The dependency system is designed as a powerful query language to support non-linear workflows with shared sources, branches, and mixed-scope dependencies.

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

### 3.1. The Pipeline Executor (Stateful Task-Based Scheduler)

The Executor is a stateful, task-based scheduler. Its workflow is as follows:

1. **Initialization:** Loads the configuration object, validates its structure, and generates the list of parameter runs.
2. **Graph Analysis:** Constructs a dependency graph from `config.stages` and performs a topological sort to create a valid execution plan and detect cycles.
3. **Task Scheduling:** Operates as a state machine, managing a registry of all jobs and their statuses (`WAITING`, `READY`, `RUNNING`, `COMPLETE`, `FAILED`, `CANCELLED`). It continuously submits `READY` jobs to a parallel worker pool.
4. **State Update and Error Handling:** When a worker completes a job, the Executor updates the state of all dependent jobs. If a job fails:
    * It is marked as `FAILED`. The error is logged.
    * If `config.error_mode` is `'fail_fast'`, the Executor terminates the entire pipeline.
    * If `config.error_mode` is `'resilient'`, the Executor traverses the graph downstream from the failed job, marks all its dependents as `CANCELLED`, and continues executing other independent branches.
5. **Reporting:** At the end of the run, the Executor provides a summary report of all job statuses.

#### 3.1.1. Configuration Validation Routine

The Executor's "Fail-Fast" validation is performed in three phases:

1. **Schema and Structural Validation:** Checks the basic "grammar" of the configuration (e.g., required fields, data types, unique names).
2. **Graph and Logical Validation:** Checks the "meaning" and integrity of the workflow, including:
    * Verifying the dependency graph is a valid DAG via topological sort.
    * Ensuring all dependency recipes and parameter links are valid (e.g., a `.where('rank', ...)` clause refers to an existing parameter).
    * Confirming the parameter sweep will result in at least one run.
3. **Environment Validation:** Checks for external prerequisites, such as:
    * The existence and licensing of required toolboxes (e.g., Parallel Computing Toolbox).
    * Write permissions for the specified storage path.

### 3.2. The Configuration

The `config` struct defines the entire workflow. It contains two main parts: the parameter space and the computational graph.

#### Parameter Space Definition

* **`config.param_mode`** (string, optional): Specifies the method for generating parameter runs. Defaults to `'grid'`.
  * `'grid'`: The framework generates the Cartesian product of all parameter values defined in `config.parameters`.
  * `'list'`: The framework uses an explicitly defined list of runs from `config.runs`.
* **`config.parameters`** (struct): Used when `param_mode` is `'grid'`. Each field name corresponds to a parameter, and its value is an array of the values to be tested.
* **`config.runs`** (struct array): Used when `param_mode` is `'list'`. Each element of the array is a struct defining one specific parameter combination.
* **`config.param_filter`** (function handle, optional): A handle to a function that filters the generated parameter runs. It must accept a single run struct and return `true` to keep it.

#### Stage Definition

The `config.stages` array defines the computational graph. A stage in the `config.stages` array is defined by a struct with fields including:

* `.name`: A unique string identifier.
* `.function`: A function handle to the stateless component.
* `.dependencies`: A struct mapping input names to **Dependency Recipes**.
* `.param_dependencies`: A cell array of strings listing the parameters the stage depends on for granular hashing.
* `.outputs`: A cell array of structs, where each struct defines an output's `.name` and `.storage_policy`.

The `.storage_policy` field supports three options:

* `'persistent'`: (Default) The output is always saved to the persistent HDF5 store.
* `'memory_only'`: The output is only kept in memory for the duration of the pipeline run.
* **Function Handle:** A handle to a boolean function (`@(p, all) ...`) for defining complex, conditional storage rules.

#### Logging and Error Configuration

The `config` struct also contains fields for controlling execution behavior:

* **`config.logging`**: A struct containing logging settings (`.console_level`, `.file_level`, `.filepath`).
* **`config.error_mode`**: A string, either `'resilient'` (default) or `'fail_fast'`.

### 3.3. The Dependency Recipe and Resolver

Dependencies are defined programmatically using a fluent, object-oriented interface. This was chosen over URI strings or static structs for its superior readability, safety, and extensibility.

* **Role:** The **Resolver** is a component that translates a dependency recipe into a specific **Provenance Hash**.
* **Syntax:** `resolver.get('source_stage').where(...).transform(...)`
* **Functionality:** The recipe specifies what data to get, the policy for retrieving it (including cross-run and global lookups), and any in-line transformations (e.g., truncation) to apply before passing it to the consuming stage.

### 3.4. The Storage System

The Storage System is composed of the `StorageManager` component and the HDF5 backend. It is designed around the principles of high performance, parallel safety, and uncompromising data integrity.

* **Storage Manager:** A component responsible for the physical reading and writing of data. It has a simple, explicit API and manages the dual-layer cache. It does **not** evaluate high-level storage policies; it only executes direct commands from the Orchestrator.
* **Provenance-Based Caching:** The HDF5 backend acts as a key-value store where data is stored in a flat `/data/` group, indexed by its unique Provenance Hash. A single computational event that produces multiple outputs (e.g., `U, S, V`) results in one Provenance Hash and one stored result set (e.g., a struct).
* **Provenance Hash:** A unique fingerprint derived from three sources:
    1. The hash of the component function's M-file.
    2. The hash of a deterministically sorted list of the Provenance Hashes of all direct inputs.
    3. A hash of the specific subset of parameters defined in `.param_dependencies`.

#### 3.4.1. The Caching Mechanism and API

The `StorageManager` implements a **dual-layer caching system** and a strict API to ensure performance and parallel safety.

1. **In-Memory Cache (L1):** A `containers.Map` that exists for the duration of a single `pipeline.run()` execution, holding all data for the current run.
2. **Persistent Cache (L2):** The long-term, on-disk HDF5 file, treated as a **Write-Once-Read-Many (WORM)** store.

The `StorageManager`'s public API for data manipulation is as follows:

* **`load(hash)`:**
    1. Checks the **L1 in-memory cache**. If the hash exists, the object is returned instantly.
    2. If not found, it checks the **L2 persistent cache**.
    3. If found in L2, it loads the data, **promotes it to the L1 cache** for future fast access, and then returns it.
    4. If not found anywhere, the load fails, signaling to the Executor that a computation is required.

* **`cache(hash, data)`:**
  * This method's only responsibility is to write the provided data object to the **L1 in-memory cache**. It is called by the `Orchestrator` for every newly computed result.

* **`persist(hash)`:**
  * This method's only responsibility is to promote data from the L1 cache to the L2 persistent store.
  * It takes only a hash, retrieves the corresponding data from the L1 cache, and writes it to the HDF5 file.
  * It enforces immutability: if the hash already exists in the L2 cache, this method will **throw a fatal `StorageManager:OverwriteAttempt` error**.

#### 3.4.2. Garbage Collection

Because the storage strategy is non-destructive, a separate utility is required to manage storage space.

* **API:** `pipeline.gc(config)`
* **Algorithm (Mark and Sweep):**
  * **Mark:** The utility first identifies the complete set of all "live" Provenance Hashes that are reachable from the *current* `pipeline_config.m`.
  * **Sweep:** It then scans the storage backend. Any data whose hash is not in the "live" set is considered orphaned and is deleted, reclaiming storage space.

### 3.5. Stateless Components

User-provided scientific code must be written as stateless functions.

* They accept a single struct of inputs.
* They return a single struct of outputs.
* They must not perform any file I/O or access global state, ensuring they are pure and reproducible.

---

## 3.6. The Logging System

To provide clear feedback to the user, the framework implements a flexible, dual-output logging system.

* **Outputs:** The logger can write to two destinations simultaneously: the MATLAB Command Window and a user-specified log file. The log file is optional; if `config.logging.filepath` is not provided, output is sent only to the console.
* **Verbosity Levels:** The system supports three named levels, configurable independently for the console and the file:
  * `'info'` (Default): Provides a high-level summary of progress, including which jobs are starting, finishing, and whether they were cached.
  * `'debug'`: A verbose output for developers, including detailed information like Provenance Hashes and resolver steps.
  * `'silent'`: Suppresses all output except for fatal errors and the final summary.
* **Error Logging:** All errors caught by the Executor are logged with their full message and stack trace, regardless of the verbosity level, to ensure critical information is never lost.

## 4. Implementation Details and Constraints

This section details low-level design decisions and constraints that are critical for a robust implementation.

### 4.1. Concurrency and File Locking

To prevent cache corruption from concurrent pipeline runs on the same file, the `StorageManager` must implement a file-locking mechanism.

* **Mechanism:** Upon starting a run, the framework will create a `.lock` file next to the HDF5 cache. If this file already exists, the framework will refuse to start and will throw an error.
* **Cleanup:** The `.lock` file must be reliably deleted upon successful completion or in a `try/catch/finally` block to handle termination due to an error.

### 4.2. Hashing and Function Constraints

The provenance hashing mechanism relies on being able to locate the source file for a component function.

* **Constraint:** All component functions referenced by a function handle in the configuration **must be defined in their own `.m` files** and be located on the MATLAB path.
* **Validation:** The configuration validation routine must verify this for every stage by checking that `which(func2str(handle))` returns a valid file path. It will fail immediately if a handle is to an anonymous, nested, or otherwise unlocatable function.

### 4.3. Data Serialization Strategy

The HDF5 file format has limitations regarding complex MATLAB data types.

* **Constraint:** For the initial version, component functions must only output data types that are natively compatible with HDF5 (e.g., numerical arrays, char arrays, and structs containing these types).
* **Future Scope:** Support for arbitrary data types (e.g., complex cell arrays, objects) would require a dedicated serialization layer (e.g., converting the variable to a binary blob or JSON string before saving), which is out of scope for the initial implementation.

### 4.4. Index Manifest Design for Performance

To ensure that dependency resolution is performant even with thousands of cached results, the storage index must be designed for efficient queries.

* **Design:** The `/index/manifest` within the HDF5 file will be a single, queryable table. For each cached result, this table will store not only its `ProvenanceHash` but also the key parameters (e.g., `rank`, `ts_len`) associated with that result.
* **Benefit:** This allows the `Resolver`'s `.where()` clause to execute a fast, indexed query on this single table, rather than needing to load metadata from thousands of individual cache entries.

### 4.5. Memory Footprint and Scalability

The current architecture prioritizes performance by holding the job registry and the L1 cache in memory.

* **Known Trade-off:** This design is optimized for workflows whose state and temporary data can fit within a single machine's available RAM.
* **Future Scope:** For extremely large-scale workflows, future versions could explore optimizations like spilling the job registry to disk or implementing a more sophisticated L1 cache eviction policy. These are out of scope for the initial implementation.

### 4.6. User Contract for Parallel Safety

The framework's parallel execution model is safe only if the user-provided code adheres to certain constraints.

* **Constraint:** All component functions **must be `parfor`-compliant**. This is a strict requirement.
* **User Responsibility:** The user is responsible for ensuring their code is free of side effects, such as accessing `global` variables, modifying variables in parent workspaces, or performing unsafe file I/O. The framework cannot programmatically enforce perfect function purity. This will be explicitly stated in the user documentation.

---

## 5. Source Code and Project Structure

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
│   ├── gc.m
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

* **`+pipeline/`**: The main package folder containing the public API (`run`, `get`, `gc`).
* **`+pipeline/+internal/`**: A nested subpackage for all private core engine components.
* **`docs/`**: Contains all project documentation.
* **`examples/`**: Contains self-contained example projects.
* **`tests/`**: Contains all unit and integration tests.
