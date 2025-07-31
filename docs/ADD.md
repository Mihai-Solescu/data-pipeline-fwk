# Architecture Design Document: General-Purpose Scientific Pipeline Framework

**Version:** 0.25.1
**Date:** 2025-07-31

---

## 1. The Configuration

The `config` struct defines the entire workflow. It is the highest-level policy, containing the parameter space, the computational graph, and execution settings.

### Parameter Space Definition

The parameter space is defined within the `config.params` struct, which is separated into two distinct parts. **Note:** Parameter names must be unique across `globals` and `grid` to prevent ambiguity. This is enforced by the configuration validation routine.

* **`config.params.globals`** (struct): Defines parameters that are **constant** for the entire experiment. Each field is a parameter name with its corresponding scalar value.
* **`config.params.grid`** (struct): Defines the parameters to be **swept over**. Each field is a parameter name, and its value is an array of values to test. The framework computes the Cartesian product of these arrays to generate the set of unique jobs.
* **`config.params.filter`** (function handle, optional): A handle to a function with the signature `f(p, G)` that filters parameter runs. `p` is the struct for a single run, and `G` is a struct containing global grid metadata (e.g., `G.max.rank`). The function must return `true` to keep the run.

### Stage Definition

The `config.stages` struct defines the computational graph. Each **field** in the `config.stages` struct defines a single computational stage, where the **field name itself serves as the unique identifier** for the stage. The value of each field is a struct containing the stage's specific configuration:

* **.function**: A function handle to the stateless component that performs the computation.
* **.inputs**: A struct mapping local input names for the function to their **Dependency Recipes** (e.g., `struct('data_in', 'previous_stage.output_name')`). This defines the stage's connections within the DAG.
* **.params**: A cell array of strings listing all parameter names the stage depends on, whether global or from the grid. This is crucial for granular hashing.
* **.outputs**: A cell array of structs, where each struct defines an output's `.name` and its `.storage_policy`.
* **.execution_mode** (string, optional): Controls the stage's execution scope. It defaults to `'per_run'`.
  * `'per_run'`: The stage runs once for each valid parameter combination from the grid.
  * `'global'`: The stage runs only once. If it has inputs, it acts as a synchronization barrier. If it has no inputs, it acts as a setup stage.
* The **`.storage_policy`** field for an output supports three options:
  * `'persistent'`: (Default) The output is always saved to the persistent HDF5 store.
  * `'memory_only'`: The output is only kept in memory for the duration of the pipeline run.
  * **Function Handle**: A function handle with the signature `f(p, G)` for defining conditional storage rules. `p` is the current run's parameter struct, and `G` is the global grid metadata struct. If the function returns `true`, the output is persisted; if `false`, it is memory-only for that run.

### Output Storage Location

* **`config.output_filename`**: The filename for persistent storage.

### Logging and Error Configuration

The `config` struct also contains fields for controlling execution behavior:

* **`config.logging`**: A struct containing logging settings (`.console_level`, `.file_level`, `.filepath`).
* **`config.error_mode`**: A string, either `'resilient'` (default) or `'fail_fast'`.

### Parallelism Configuration

* **`config.num_workers`**: An integer specifying the number of parallel workers for executing jobs. If set to `1`, execution is serial. If greater than `1`, a parallel pool of the specified size is used. If omitted or set to `'auto'`, the framework uses the default parallel pool size determined by MATLAB.

---

## 2. Function Signatures

The framework interacts with user-provided code through three distinct types of function handles, each with a specific signature tailored to its purpose.

### Stage Computation Function

This is the primary function that performs the scientific calculation for a stage. Its signature is designed to be clean and decoupled from the overall framework configuration.

* **Signature:** `outputs = func(inputs, params)`
* **Arguments:**
  * `inputs`: A struct where each field name corresponds to a local variable name defined in the stage's `.inputs` configuration. The value of each field is the data product from the corresponding upstream dependency.
  * `params`: A struct containing **only** the parameters the stage explicitly requested in its `.params` list. The framework assembles this struct for the function, resolving the requested parameter names from both the current run's grid parameters and the global parameters.
* **Return Value:**
  * `outputs`: A struct where each **field name must exactly match** an output name defined in the stage's `.outputs` configuration. The framework uses these names to map the returned data to the correct outputs, so the order of fields in the struct does not matter.

### Parameter Filter Function

This function is used to selectively discard runs from the generated parameter grid before execution begins. Its signature provides the context of the single run relative to the entire experimental space.

* **Signature:** `is_valid = func(p, G)`
* **Arguments:**
  * `p`: A struct representing the complete parameter set for **one potential run**. This struct contains the specific values from the `config.params.grid` for that run, merged with **all** parameters from `config.params.globals`.
  * `G`: The complete **global grid** struct (`config.params.grid`), passed by value. This allows for powerful relative logic by giving the function access to the full range of all tested parameter values (e.g., `max(G.rank)`).
* **Return Value:** Must return `true` to keep the run or `false` to discard it.

---

### Conditional Storage Policy Function

This function is used to define complex rules for whether a stage's output should be saved to the persistent HDF5 store. Its signature is identical to the parameter filter's, providing full context for the decision.

* **Signature:** `should_store = func(p, G)`
* **Arguments:**
  * `p`: A struct representing the complete parameter set for the run that **just completed**. Like the filter, this contains both the specific grid values and all global parameters.
  * `G`: The complete **global grid** struct (`config.params.grid`), passed by value. This provides full context for storage decisions (e.g., `p.rank == max(G.rank)`).
* **Return Value:** Must return `true` to persist the data or `false` to discard it (making it memory-only for that run).

---

## 2 Hashing (ADR-012)

The framework's guarantee of reproducibility and computational efficiency is built upon a **Provenance-Based Hashing** system. Instead of hashing the *output* of a computation, the framework generates a unique and deterministic fingerprint for the computation's complete origin, or **provenance**. This allows the expected hash to be calculated *before* a stage is executed, enabling efficient cache lookups.

This fingerprint is called the **Provenance Hash**.

### The Three Components of the Provenance Hash

The Provenance Hash is an SHA-256 hash derived from three and only three sources. It is the single, consistent formula used for all data products in the system.

1. **Code Hash**: An SHA-256 hash of the stage's component `.m` file. Any change to the source code, including comments, will change this hash.
2. **Input Hashes**: An SHA-256 hash derived from a deterministically sorted list of the Provenance Hashes of all direct data inputs. For stages with multiple inputs (e.g., fan-in nodes), the list of input hashes is sorted alphabetically before being hashed to ensure the result is deterministic and independent of execution order.
3. **Granular Parameter Hash**: An SHA-256 hash of a struct containing only the specific subset of parameters the stage's function directly depends on.

### The Parameter Contract

The construction of the **Granular Parameter Hash** is governed by a strict contract between the user's configuration and the framework's executor to ensure precision and prevent unnecessary recomputations.

* **Explicit Declaration is Mandatory**: A stage's `.params` field **must** contain a complete list of every parameter the function directly uses. The framework builds the `params` struct passed to the function exclusively from this list. A function that attempts to access a parameter not declared in its `.params` field will fail.

* **Inherited Parameters are Not Included**: The `Parameter Hash` is derived **only** from the parameters explicitly listed in the stage's own `.params` field. The influence of all upstream (or "inherited") parameters is already perfectly captured by the **Input Hashes**. This elegant separation ensures that the provenance is recorded without redundancy.

### Cascading Invalidation and Efficiency

This hashing design creates a "keychain" of cryptographic dependency.

A change to any upstream component automatically propagates downstream. For example, if a global parameter `dt` is changed:

1. Any stage that **directly uses `dt`** (and therefore lists it in its `.params`) will have its `Parameter Hash` change and will be re-run.
2. Any stage that depends on the *output* of such a stage will see its `Input Hashes` change and will also be re-run, even if it doesn't use `dt` directly.

This mechanism ensures that the absolute minimum number of computations is performed. A stage is only re-run if its code, its direct parameters, or its direct inputs have changed, guaranteeing both maximum efficiency and uncompromising reproducibility.

### 2.2. The Orchestrator (Stateful Task-Based Scheduler)

The **Orchestrator** is the central coordinating component of the framework. It operates as a stateful, task-based scheduler, and its workflow is as follows:

1. **Initialization:** Loads the configuration object, validates its structure, and generates the list of parameter runs.
2. **Graph Analysis:** Constructs a dependency graph from `config.stages` and performs a topological sort to create a valid execution plan and detect cycles.
3. **Task Scheduling:** Operates as a state machine, managing a registry of all jobs and their statuses (`WAITING`, `READY`, `RUNNING`, `COMPLETE`, `FAILED`, `CANCELLED`). It continuously submits `READY` jobs to the **Executor** component (which implements the `IExecutor` interface) for asynchronous execution.
4. **State Update and Error Handling:** When a job completes, the **Orchestrator** updates the state of all dependent jobs. If a job fails:
    * It is marked as `FAILED`. The error is logged.
    * If `config.error_mode` is `'fail_fast'`, the **Orchestrator** terminates the entire pipeline.
    * If `config.error_mode` is `'resilient'`, the **Orchestrator** traverses the graph downstream from the failed job, marks all its dependents as `CANCELLED`, and continues executing other independent branches.
5. **Reporting:** At the end of the run, the **Orchestrator** provides a summary report of all job statuses.

#### 2.2.1. Configuration Validation Routine

Before any pipeline execution begins, the user's configuration undergoes a rigorous, multi-phase validation process. This is performed by dedicated validator components before the `Orchestrator` is created, ensuring the system fails fast on any invalid input. The validation is performed in three phases:

1. **Schema and Structural Validation:** This phase checks the basic "grammar" of the configuration file.
    * Verifying all required fields are present.
    * Checking that all values have the correct data type (e.g., stage names are strings, dependencies are in a struct).
    * Ensuring stage names are unique.
    * Confirming that function handles for stages point to existing, non-anonymous `.m` files.

2. **Graph Construction and Logical Validation:** This phase checks the "meaning" and integrity of the defined workflow.
    * The `DependencyGraph` object is constructed from the stage definitions.
    * The graph's structure is verified to be a valid **Directed Acyclic Graph (DAG)** by attempting a topological sort.
    * It ensures all dependency recipes refer to stages that exist in the graph.
    * It confirms that the parameter sweep configuration will result in at least one run.

3. **Environment Validation:** This final phase checks for external prerequisites required for the run.
    * The existence and licensing of required toolboxes (e.g., Parallel Computing Toolbox).
    * Write permissions for the specified storage path and log file path.

### 2.3. The Dependency Recipe and Resolution System

Dependencies are defined programmatically using a fluent, object-oriented **Recipe**. A Recipe is a stateful **query builder** object that creates a detailed, declarative request for a specific data product.

The system is composed of two main parts: the `Recipe` object that defines the query, and the `Resolver` component that executes it.

#### 2.3.1. The Recipe API

A user creates a Recipe using the `pipeline.get()` factory method and then chains methods to refine the query. The framework will initially support the following fundamental methods:

* **`get(stage_name, [output_names])`**: The starting point of every recipe. It specifies the source stage and which of its outputs are required.

* **`filter(func_handle)`**: The primary method for filtering runs based on their parameters.
  * **Signature**: `@(params) ...`
  * **Functionality**: The provided handle receives a `ParameterView` object, which securely exposes only the parameters declared in the source stage's `.params`. The handle must return `true` if the run is a match. This validation is performed just-in-time by the `Resolver`.

* **`all()`**: An operator that specifies the query should gather results from **all** runs that match the preceding filters, rather than a single run. This is the key to creating global, fan-in dependencies.

* **`transform(func_handle)`**: Applies a final, in-line transformation to the data after it has been fully resolved and loaded.
  * **Signature**: `@(inputs, source_params) ...`
  * **Functionality**: This is for last-mile data preparation (e.g., truncating a matrix) before the data is passed to the consuming stage.

#### 2.3.2. The Resolver's Role and Workflow

The **Resolver** is the engine that executes a `Recipe` object. Its responsibility is to translate the recipe into a specific, actionable "work order" for the `Orchestrator`. It does this by recursively calculating the **Provenance Hash** of the requested data.

The workflow is as follows:

1. **Validation**: The `Resolver` receives a `Recipe`. Its first step is to validate any `.filter()` clauses against the source stage's declared `.params`. It will throw a fatal error if the filter attempts to access an undeclared parameter.

2. **Query Execution**: It queries the cache index to find all runs that satisfy the validated filter conditions.

3. **Ambiguity Check**: For any recipe that does not use `.all()`, the `Resolver` enforces that the query must resolve to **exactly one** result. If it matches zero or multiple results, it throws a fatal error.

4. **Resolution**:
    * **For simple recipes**: The `Resolver` recursively calculates the `ProvenanceHash` for the single matching result. It returns this hash and any `.transform()` function to the `Orchestrator`.

### 2.4. The Storage System

The storage system is designed as a **two-tier architecture** to provide both high performance via in-memory caching and data integrity via persistent on-disk storage. The architecture strictly separates the caching logic from the persistence mechanism, allowing different storage backends to be used in the future without altering the core pipeline engine.

#### Storage System Diagram

The following diagram illustrates the main components and relationships in the storage subsystem:

```plantuml
!include diagrams/storage.plantuml
```

#### 2.4.1. Architectural Overview

1. **The `StorageManager` (L1 Cache Handler):** This component is the single point of contact for the `Executor`. It owns the fast, volatile in-memory cache (`containers.Map`) that exists for the duration of a single pipeline run. Its only job is to orchestrate data access, serving results from memory when possible and delegating to the `StorageBackend` when necessary.

2. **The `StorageBackend` (L2 Persistent Store):** This is an interface (an abstract class) that defines how to save, load, and delete data from a slow, durable, on-disk store. Concrete implementations (`HDF5Backend`, `SQLiteBackend`) handle the specifics of a given storage technology. The backend knows nothing about the L1 cache.

The `Executor` communicates only with the `StorageManager`, which in turn commands the `StorageBackend`.

#### 2.4.2. The StorageManager API and Logic

The `StorageManager` is instantiated at the start of a run with a configured `StorageBackend`. Its API gives the `Executor` explicit control over the caching and persistence lifecycle.

* **`data = load(hash)`:** This is the primary data retrieval method.
    1. It first checks the L1 in-memory cache. If the `hash` exists (**cache hit**), the data is returned instantly.
    2. If the data is not in L1 (**cache miss**), the manager calls `load(hash)` on its `StorageBackend` to fetch the data from disk.
    3. The retrieved data is then **promoted** into the L1 cache before being returned to the caller.

* **`cache(hash, data)`:** This method writes a newly computed result **only** to the L1 in-memory cache. This action ensures the data is immediately available for subsequent stages within the same pipeline run, regardless of the persistence policy.

* **`persist(hash)`:** This method promotes data from the L1 cache to the L2 persistent store. It takes only the `hash`, retrieves the corresponding data from the in-memory cache, and commands the `StorageBackend` to save it. This method is called by the `Executor` only when a `StoragePolicy` dictates that a result should be persisted.

#### 2.4.3. The StorageBackend Interface

This defines a strict contract for any persistent storage technology to be compliant with the framework.

* **Interface Definition:** A `StorageBackend` must implement the following methods:
  * `save(key, data)`: Writes a data object to the persistent store, indexed by its key.
  * `data = load(key)`: Retrieves a data object from the persistent store.
  * `flag = exists(key)`: Returns `true` if the key exists in the persistent store.
  * `delete(key)`: Removes a key and its associated data from the persistent store.

#### 2.4.5. Garbage Collection

The garbage collection utility operates directly on the `StorageBackend`.

* **API:** `pipeline.gc(config)`
* **Algorithm (Mark and Sweep):**
  * **Mark:** The utility first calculates the complete set of all "live" Provenance Hashes that are reachable from the provided pipeline configuration.
  * **Sweep:** It then iterates through all keys in the `StorageBackend`. For any key that is not in the "live" set, it calls the `backend.delete(key)` method to reclaim storage space.

---

### 2.5. Stateless Components

User-provided scientific code must be written as stateless functions.

* They accept a single struct of inputs.
* They return a single struct of outputs.
* They must not perform any file I/O or access global state, ensuring they are pure and reproducible.

---

## 2.6. The Logging System

To provide clear feedback to the user, the framework implements a flexible, dual-output logging system.

* **Outputs:** The logger can write to two destinations simultaneously: the MATLAB Command Window and a user-specified log file. The log file is optional; if `config.logging.filepath` is not provided, output is sent only to the console.
* **Verbosity Levels:** The system supports three named levels, configurable independently for the console and the file:
  * `'info'` (Default): Provides a high-level summary of progress, including which jobs are starting, finishing, and whether they were cached.
  * `'debug'`: A verbose output for developers, including detailed information like Provenance Hashes and resolver steps.
  * `'silent'`: Suppresses all output except for fatal errors and the final summary.
* **Error Logging:** All errors caught by the Executor are logged with their full message and stack trace, regardless of the verbosity level, to ensure critical information is never lost.

## 3. Implementation Details and Constraints

This section details low-level design decisions and constraints that are critical for a robust implementation.

### 3.1. Concurrency and File Locking

To prevent cache corruption from concurrent pipeline runs on the same file, the `StorageManager` must implement a file-locking mechanism.

* **Mechanism:** Upon starting a run, the framework will create a `.lock` file next to the HDF5 cache. If this file already exists, the framework will refuse to start and will throw an error.
* **Cleanup:** The `.lock` file must be reliably deleted upon successful completion or in a `try/catch/finally` block to handle termination due to an error.

### 3.2. Hashing and Function Constraints

The provenance hashing mechanism relies on being able to locate the source file for a component function.

* **Constraint:** All component functions referenced by a function handle in the configuration **must be defined in their own `.m` files** and be located on the MATLAB path.
* **Validation:** The configuration validation routine must verify this for every stage by checking that `which(func2str(handle))` returns a valid file path. It will fail immediately if a handle is to an anonymous, nested, or otherwise unlocatable function.

### 3.3. Data Serialization Strategy

The HDF5 file format has limitations regarding complex MATLAB data types.

* **Constraint:** For the initial version, component functions must only output data types that are natively compatible with HDF5 (e.g., numerical arrays, char arrays, and structs containing these types).
* **Future Scope:** Support for arbitrary data types (e.g., complex cell arrays, objects) would require a dedicated serialization layer (e.g., converting the variable to a binary blob or JSON string before saving), which is out of scope for the initial implementation.

### 3.4. Index Manifest Design for Performance

To ensure that dependency resolution is performant even with thousands of cached results, the storage index must be designed for efficient queries.

* **Design:** The `/index/manifest` within the HDF5 file will be a single, queryable table. For each cached result, this table will store not only its `ProvenanceHash` but also the key parameters (e.g., `rank`, `ts_len`) associated with that result.
* **Benefit:** This allows the `Resolver`'s `.where()` clause to execute a fast, indexed query on this single table, rather than needing to load metadata from thousands of individual cache entries.

### 3.5. Memory Footprint and Scalability

The current architecture prioritizes performance by holding the job registry and the L1 cache in memory.

* **Known Trade-off:** This design is optimized for workflows whose state and temporary data can fit within a single machine's available RAM.
* **Future Scope:** For extremely large-scale workflows, future versions could explore optimizations like spilling the job registry to disk or implementing a more sophisticated L1 cache eviction policy. These are out of scope for the initial implementation.

### 3.6. User Contract for Parallel Safety

The framework's parallel execution model is safe only if the user-provided code adheres to certain constraints.

* **Constraint:** All component functions **must be `parfor`-compliant**. This is a strict requirement.
* **User Responsibility:** The user is responsible for ensuring their code is free of side effects, such as accessing `global` variables, modifying variables in parent workspaces, or performing unsafe file I/O. The framework cannot programmatically enforce perfect function purity. This will be explicitly stated in the user documentation.

---

## 4. Source Code and Project Structure

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

## 5. Architectural Principles

Our architecture is guided by a core philosophy, translated into five technical rules:

1. **MATLAB-Native Experience:** The framework must feel like a natural extension of MATLAB. All user-facing interfaces will use idiomatic MATLAB syntax (e.g., programmatic recipes, function handles) over custom string-based languages.
2. **Uncompromising Reproducibility:** Every result must be verifiably reproducible. Caching is not just for speed; it is a guarantee of correctness, achieved through provenance-based hashing.
3. **Declarative Configuration as Code:** Users will declare *what* the pipeline should do in a version-controllable MATLAB file, separating the workflow definition from the execution engine.
4. **Aggressive Separation of Concerns:** A strict separation will be maintained between scientific logic (in component functions), optimization logic (in dependency recipes), and framework logic (in the executor).
5. **Flexible and Composable Data Flow:** The framework is a toolkit for building complex computational graphs. The dependency system is designed as a powerful query language to support non-linear workflows with shared sources, branches, and mixed-scope dependencies.

---
