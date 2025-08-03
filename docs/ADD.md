# Architecture Design Document: General-Purpose Scientific Pipeline Framework

**Version:** 0.28.2
**Date:** 2025-08-02

---

## Source Code and Project Structure

* **`+pipeline/`**: The main package folder containing the public API (`run`, `get`, `gc`).
* **`docs/`**: Contains all project documentation.
* **`examples/`**: Contains self-contained example projects.
* **`tests/`**: Contains all unit and integration tests.

## 1. The Configuration

The `config` struct defines the entire workflow. It is the highest-level policy, containing the parameter space, the computational graph, and execution settings.

### 1.1. Parameter Space Definition

The parameter space is defined within the `config.params` struct, which is separated into two distinct parts. **Note:** Parameter names must be unique across `globals` and `grid` to prevent ambiguity. This is enforced by the configuration validation routine.

* **`config.params.globals`** (struct): Defines parameters that are **constant** for the entire experiment. Each field is a parameter name with its corresponding scalar value.
* **`config.params.grid`** (struct): Defines the parameters to be **swept over**. Each field is a parameter name, and its value is an array of values to test. The framework computes the Cartesian product of these arrays to generate the set of unique jobs.
* **`config.params.filter`** (function handle, optional): A handle to a function with the signature `f(p, G)` that filters parameter runs. `p` is the struct for a single run, and `G` is a struct containing global grid metadata (e.g., `G.max.rank`). The function must return `true` to keep the run.

#### A Note on the Filtering Approach

The framework intentionally uses a single, global filter that is applied **upfront**. This design is the most computationally efficient approach. By establishing the definitive set of valid final runs *before* any execution begins, it guarantees that the stage-wise orchestrator only ever computes tasks that are known to contribute to a pre-approved result. This prevents the wasted computation that would occur if filters were applied midway through the pipeline after upstream work had already been completed.

### 1.2. Stage Definition

The `config.stages` struct defines the computational graph. Each **field** in the `config.stages` struct defines a single computational stage, where the **field name itself serves as the unique identifier** for the stage. The value of each field is a struct containing the stage's specific configuration:

* **`.function`**: A function handle to the stateless component that performs the computation.
* **`.inputs`** (struct, optional): A struct mapping local input names for the function to their **Dependency Recipes** (e.g., `struct('data_in', 'previous_stage.output_name')`). This defines the stage's connections within the DAG. If this field is missing, the stage is considered to have no inputs.
* **`.params`** (cell array of strings, optional): A cell array of strings listing all parameter names the stage depends on, whether global or from the grid. This is crucial for granular hashing. If this field is missing, the stage is considered to have only the inherited parameter dependencies, implicitly, and no used ones. This means that at runtime the params struct passed to the function will be empty, even though the inputs that will be passed in will be those with specific values for their inherited parameters, and thus the output will be dependent on the same parameter values.
* **`.outputs`** (cell array of structs, optional): A cell array of structs, where each struct defines an output's `.name` and its `.storage_policy`. If this field is missing, the stage is considered to have no outputs.
* **`.execution_mode`** (string, optional): Controls the stage's execution scope. It defaults to `'per_run'`.
  * `'per_run'`: The stage runs once for each valid parameter combination from the grid.
  * `'global'`: The stage runs only once. If it has inputs, it acts as a synchronization barrier. If it has no inputs, it acts as a setup stage.
* The **`.storage_policy`** field for an output supports three options:
  * `'persistent'`: (Default) The output is always saved to the persistent HDF5 store. If the `.storage_policy` field is omitted for an output, this is the default behavior.
  * `'memory_only'`: The output is only kept in memory for the duration of the pipeline run.
  * **Function Handle**: A function handle with the signature `f(p, G)` for defining conditional storage rules. `p` is the current run's parameter struct, and `G` is the global grid metadata struct. If the function returns `true`, the output is persisted; if `false`, it is memory-only for that run.

> **Note:** The implementation of advanced features—specifically the **conditional storage policy** and the full input resolver API—will be deferred to a later development stage. These features are modular, non-breaking extensions to the core architecture. The initial release will focus on stabilizing the fundamental caching and dependency-tracking logic, which uses provenance hashing and simple string-based dependency recipes. For details on the planned resolver system, see [The Dependency Recipe and Resolution System](#8-the-dependency-recipe-and-resolution-system).

#### Hashing and Function Constraints

The provenance hashing mechanism relies on being able to locate the source file for a component function.

* **Constraint:** All component functions referenced by a function handle in the configuration **must be defined in their own `.m` files** and be located on the MATLAB path.
* **Validation:** The configuration validation routine must verify this for every stage by checking that `which(func2str(handle))` returns a valid file path. It will fail immediately if a handle is to an anonymous, nested, or otherwise unlocatable function.

### 1.3. Output Storage Location

* **`config.output_filename`**: The filename for persistent storage.

### 1.4. Logging and Error Configuration

The `config` struct also contains fields for controlling execution behavior:

* **`config.logging`**: A struct containing logging settings (`.console_level`, `.file_level`, `.filepath`).
* **`config.logging.console_level` and `config.logging.file_level`**: Strings specifying the console and file logging levels (e.g. `debug`, `info`, `warning`, `error`, `fatal`, `none`).
* **`config.error_mode`**: A string, either `'resilient'` (default) or `'fail_fast'`.

> **Note:** Either both `config.logging.filepath` and `config.logging.file_level` must be specified together, or neither, else the framework will throw an error during initialization.

### 1.5. Parallelism Configuration

* **`config.num_workers`**: An integer specifying the number of parallel workers for executing jobs. If set to `1`, execution is serial. If greater than `1`, a parallel pool of the specified size is used. If omitted or set to `'auto'`, the framework uses the default parallel pool size determined by MATLAB.

### 1.6. The `StageGraph` and Parameter Dependencies

The `StageGraph` class is not just a passive representation of the pipeline's structure; it's an intelligent model of the data and parameter flow. Its responsibilities extend beyond simple validation to include the resolution of effective parameter dependencies, ensuring the framework's execution engine receives a complete and accurate picture of each task's provenance.

#### The `StageGraph`'s Core Responsibility

The `StageGraph` object’s primary purpose is to provide a comprehensive and immutable model of the pipeline's computational graph. It ensures the graph's structural integrity and resolves all parameters that influence each stage, whether they are explicitly declared by the user or implicitly inherited through dependencies.

Specifically, the `StageGraph` constructor performs a crucial preprocessing step: for every stage, it computes a complete list of its *effective parameters* by combining the parameters explicitly listed in a stage's `.params` field with all parameters from all of its upstream dependencies.

#### The Algorithm for Effective Dependency Resolution

The `StageGraph` constructor performs a traversal of the graph to build a complete list of effective parameters for each stage. The algorithm works as follows:

1. **Initialize:** For each stage, a list of its effective parameters is initialized to contain the union of all parameters explicitly declared in the stage's `.params` field.

2. **Iterate and Aggregate:** The algorithm iterates through the stages in a reverse topological sort order (from outputs to inputs). For each stage:
    * It retrieves the effective parameters of all its direct successors (stages that depend on it).
    * It adds these parameters to the effective parameter list of the current stage.

This process ensures that by the time the algorithm reaches a given stage, all parameters from its entire downstream subtree have been propagated back and aggregated. The result is an immutable property in the `StageGraph` class called `effective_params`, which is a map where each key is a stage name and each value is a cell array of all parameter names—both explicit and effective—that influence that stage's computation.

#### Intended Use

This pre-computed `effective_params` map is intended to be used by the framework's scheduling and hashing components. When generating the unique tasks for a stage, this map ensures that the correct parameter space is considered, capturing all upstream dependencies. Similarly, when computing the `Provenance Hash`, this map is used to ensure that the hash is derived from the complete set of influencing parameters, guaranteeing that any change to an upstream parameter will correctly invalidate the cache for all affected downstream stages.

However, the framework will still honor the user's explicit `.params` list when executing the stage function itself, passing only those declared parameters to maintain a clean and decoupled interface for the scientific components.

## 1.7. Function Signatures

The framework interacts with user-provided code through three distinct types of function handles, each with a specific signature tailored to its purpose.

### 1.7.1. Stage Computation Function

This is the primary function that performs the scientific calculation for a stage. Its signature is designed to be clean and decoupled from the overall framework configuration.

* **Signature:** `outputs = func(inputs, params)`
* **Arguments:**
  * `inputs`: A struct where each field name corresponds to a local variable name defined in the stage's `.inputs` configuration. The value of each field is the data product from the corresponding upstream dependency.
  * `params`: A struct containing **only** the parameters the stage explicitly requested in its `.params` list. The framework assembles this struct for the function, resolving the requested parameter names from both the current run's grid parameters and the global parameters.
* **Return Value:**
  * `outputs`: A struct where each **field name must exactly match** an output name defined in the stage's `.outputs` configuration. The framework uses these names to map the returned data to the correct outputs, so the order of fields in the struct does not matter.

#### User Contract for Parallel Safety

The framework's parallel execution model is safe only if the user-provided code adheres to certain constraints.

* **Constraint:** All component functions **must be `parfor`-compliant**. This is a strict requirement.
* **User Responsibility:** The user is responsible for ensuring their code is free of side effects, such as accessing global variables, modifying variables in parent workspaces, or performing unsafe file I/O. The framework cannot programmatically enforce perfect function purity. This will be explicitly stated in the user documentation.

### 1.7.2. Parameter Filter Function

This function is used to selectively discard runs from the generated parameter grid before execution begins. Its signature provides the context of the single run relative to the entire experimental space.

* **Signature:** `is_valid = func(p, G)`
* **Arguments:**
  * `p`: A struct representing the complete parameter set for **one potential run**. This struct contains the specific values from the `config.params.grid` for that run, merged with **all** parameters from `config.params.globals`.
  * `G`: The complete **global grid** struct (`config.params.grid`), passed by value. This allows for powerful relative logic by giving the function access to the full range of all tested parameter values (e.g., `max(G.rank)`).
* **Return Value:** Must return `true` to keep the run or `false` to discard it.

### 1.7.3. Conditional Storage Policy Function

This function is used to define complex rules for whether a stage's output should be saved to the persistent HDF5 store. Its signature is identical to the parameter filter's, providing full context for the decision.

* **Signature:** `should_store = func(p, G)`
* **Arguments:**
  * `p`: A struct representing the complete parameter set for the run that **just completed**. Like the filter, this contains both the specific grid values and all global parameters.
  * `G`: The complete **global grid** struct (`config.params.grid`), passed by value. This provides full context for storage decisions (e.g., `p.rank == max(G.rank)`).
* **Return Value:** Must return `true` to persist the data or `false` to discard it (making it memory-only for that run).

---

## 2. Hashing (ADR-012)

The framework's guarantee of reproducibility and computational efficiency is built upon a **Provenance-Based Hashing** system. Instead of hashing the *output* of a computation, the framework generates a unique and deterministic fingerprint for the computation's complete origin, or **provenance**. This allows the expected hash to be calculated *before* a stage is executed, enabling efficient cache lookups.

This fingerprint is called the **Provenance Hash**.

### 2.1. The Three Components of the Provenance Hash

The Provenance Hash is an SHA-256 hash derived from three and only three sources. It is the single, consistent formula used for all data products in the system.

1. **Code Hash**: An SHA-256 hash of the stage's component `.m` file. Any change to the source code, including comments, will change this hash.
2. **Input Hashes**: An SHA-256 hash derived from a deterministically sorted list of the Provenance Hashes of all direct data inputs. For stages with multiple inputs (e.g., fan-in nodes), the list of input hashes is sorted alphabetically before being hashed to ensure the result is deterministic and independent of execution order.
3. **Granular Parameter Hash**: An SHA-256 hash of a canonical representation of a struct containing explicit parameters the stage depends on (the explicit parameters listed in `.params`). The struct's **field names** are the parameter names, and the **field values** are their specific values for the task. To ensure determinism, the fields of this struct are sorted alphabetically by name before being serialized and hashed.

### 2.2. The Parameter Contract

The construction of the **Granular Parameter Hash** is governed by a strict contract between the user's configuration and the framework's executor to ensure precision and prevent unnecessary recomputations.

* **Explicit Declaration is Mandatory**: A stage's `.params` field **must** contain a complete list of every parameter the function directly uses. The framework builds the `params` struct passed to the function exclusively from this list. A function that attempts to access a parameter not declared in its `.params` field will fail.

* **Inherited Parameters are Not Included**: The `Parameter Hash` is derived **only** from the parameters explicitly listed in the stage's own `.params` field. The influence of all upstream (or "inherited") parameters is already perfectly captured by the **Input Hashes**. This elegant separation ensures that the provenance is recorded without redundancy.

If a parameter is declared in `.params` but is not found in the function's code, the framework should proceed with the computation but print a clear warning to the console (e.g. `WARNING in stage 'compute_svd': Parameter 'dt' is declared in '.params' but does not appear to be used in the function 'compute_svd.m'. Including it may cause unnecessary recomputations if its value changes.`).

### 2.3. Cascading Invalidation and Efficiency

This hashing design creates a "keychain" of cryptographic dependency.

A change to any upstream component automatically propagates downstream. For example, if a global parameter `dt` is changed:

1. Any stage that **directly uses `dt`** (and therefore lists it in its `.params`) will have its `Parameter Hash` change and will be re-run.
2. Any stage that depends on the *output* of such a stage will see its `Input Hashes` change and will also be re-run, even if it doesn't use `dt` directly.

This mechanism ensures that the absolute minimum number of computations is performed. A stage is only re-run if its code, its direct parameters, or its direct inputs have changed, guaranteeing both maximum efficiency and uncompromising reproducibility.

The full algorithm integrates configuration validation, progressive parametrization, and provenance-based hashing into a coherent workflow. The process is divided into two main phases: a one-time setup and the main execution loop.

### 2.4. Scenarios

Here are a few scenarios that illustrate the desired outcomes of the provenance hashing system.

#### Scenario 1: Baseline Caching ⚡

This scenario demonstrates the framework's fundamental efficiency.

* **Initial State:** A full pipeline has been successfully run, and all results are in the persistent cache.
* **Action:** The user immediately re-runs the exact same pipeline with no changes to the code or configuration.
* **Expected Outcome:** The framework should complete almost instantly. For every task, it calculates the Provenance Hash, finds a perfect match in the cache, and skips the execution. The logs should report all tasks as `CACHED`.

#### Scenario 2: Cascading Invalidation from a Code Change 🧬

This demonstrates how the framework guarantees reproducibility when the logic changes.

* **Initial State:** The pipeline has been fully run.
* **Action:** A scientist modifies `compute_svd.m` to use a more robust algorithm.
* **Expected Outcome:** Upon re-running the pipeline:
    1. All stages **upstream** of `compute_svd` (e.g., `compute_hankel`) are `CACHED` because their provenance is unchanged.
    2. The `compute_svd` stage is **re-run** because its **Code Hash** has changed.
    3. All stages **downstream** of `compute_svd` (e.g., `compute_numerical_derivative`) are **re-run** because their **Input Hashes** (which depend on the output of `compute_svd`) have changed. This demonstrates perfect cascading invalidation.

#### Scenario 3: Cascading Invalidation from a Parameter Change ⚙️

This shows how the framework handles changes in experimental conditions.

* **Initial State:** The pipeline has been fully run with `dt = 0.001`.
* **Action:** The user changes a single global parameter to `config.params.globals.dt = 0.002`.
* **Expected Outcome:**
    1. The `compute_master_timeseries` stage, which directly uses `dt`, is **re-run** because its **Parameter Hash** changes.
    2. All stages that depend on its output (e.g., `compute_hankel`, `compute_svd`, etc.) are subsequently **re-run** due to changing **Input Hashes**.
    3. Any unrelated branch of the pipeline that does not depend on `dt` would be skipped entirely.

#### Scenario 4: Granular Caching with a Grid Expansion 🎯

This highlights the power of progressive parametrization.

* **Initial State:** The pipeline was run with `config.params.grid.truncation_rank = [10, 15]`.
* **Action:** The user expands the experiment by changing the grid to `truncation_rank = [10, 15, 20]`.
* **Expected Outcome:**
    1. All stages **upstream** of the change (e.g., `compute_hankel`) are `CACHED`. Their results are reused across all runs.
    2. For the `compute_svd` stage and all its dependents, the tasks corresponding to `rank=10` and `rank=15` are `CACHED`.
    3. The framework **only executes the new tasks** corresponding to `rank=20`. This saves the maximum amount of time by only computing what is truly new.

### 2.5. Hashing as a Merkle DAG

The provenance hashing system can be formally understood as the construction of a **Merkle DAG** (Directed Acyclic Graph). In this model, every unique data product in the framework is a node in the graph, and its **Provenance Hash serves as its unique identifier**.

A key property of a Merkle DAG is that the identifier for any node is a cryptographic hash derived from its own content and the identifiers (hashes) of its parent nodes. In our framework:

* A stage's **code and parameters** are its "content."
* The **Provenance Hashes of its inputs** are the identifiers of its parent nodes.

This model is not a different implementation, but rather the formal computer science pattern that describes our hashing strategy. It guarantees data integrity and provides a verifiable, tamper-proof audit trail for every result. Crucially, the Merkle DAG is built **iteratively** by processing stages in topological order (from inputs to outputs). This avoids any expensive runtime recursion, as the hash for any parent node is always computed and cached before it is needed by a child node.

### 2.6. Targeting stages

The ability to specify target stages for selective execution is a planned optimization for a future release. This feature will allow users to run only the minimal subgraph of dependencies required to produce a desired output, which is ideal for debugging or regenerating specific results. Its implementation will be deferred to allow for the initial focus to remain on stabilizing the core framework's ability to robustly execute and cache the entire defined pipeline. This functionality can be cleanly integrated later by adding a reverse-dependency graph traversal step that prunes the execution plan before the main orchestrator begins its work.

### 2.7 The ProvenanceHasher Service

To ensure that the logic for creating provenance hashes is centralized, robust, and testable, the framework uses a dedicated **`ProvenanceHasher`** service. This class is the sole authority on how to compute the final `ProvenanceHash` for any given computational task.

#### Core Responsibility

The `ProvenanceHasher`'s only responsibility is to correctly implement the framework's three-part hashing formula. It receives a `Task` object from the `Executor`, which contains all the necessary information for a single computation. It then uses the low-level `pipeline.internal.Hasher` utility to perform the underlying cryptographic operations.

This design cleanly separates the high-level *rules* of provenance from the low-level *mechanics* of hashing. The `ProvenanceHasher` is a non-recursive service; it is only ever asked to compute the hash for a task whose inputs are already known and provided as hashes.

#### Public API

The `ProvenanceHasher` has to be initialized with the specific `StageGraph` for the pipeline run and a logger instance for recording events and errors. This graph provides the context needed to resolve stage names and their dependencies, while the logger ensures all operations are properly tracked according to the framework's logging taxonomy.

**Constructor: `ProvenanceHasher(stageGraph, logger)`**

* **`stageGraph` (`pipeline.utility.StageGraph`):** A fully constructed StageGraph object that provides stage configuration and parameter dependency information.
* **`logger` (`mlog.Logger`):** A logger instance that follows the framework's hierarchical naming convention (e.g., `mlog.Logger('pipeline:ProvenanceHasher')`).

The `ProvenanceHasher` has one public method:

**`provenanceHash = computeProvenanceHash(task)`**

This method computes the definitive SHA-256 hash for a task.

* **`task` (`struct`):** A struct with three fields:
  * `stage_name` (`char`): The name of the stage to execute.
  * `parameters` (`struct`): The complete parameter struct for the run, which provides the values needed for hashing. The hasher will safely ignore any parameters not explicitly used by the stage.
  * `input_hashes` (`struct`): A struct mapping local input names to the provenance hash of each dependency. Should be empty for source stages.
* **Returns:** A 64-character lowercase SHA-256 hash string.

#### Internal Methods

The service uses a set of private methods to assemble the three component hashes:

* `getStageCodeHash(stage_name)`: Computes the hash of the stage's `.m` file. It uses an internal in-memory cache to avoid re-reading the same file multiple times during a single pipeline run.
* `getGranularParamHash(stage_name, all_params)`: Computes the hash of a struct containing only the parameters explicitly declared in the stage's `.params` list.
* `getInputSetHash(input_hashes_struct)`: Computes the hash of the deterministically sorted input hashes struct.

---

## 3. Algorithm Overview

The full algorithm integrates configuration validation, progressive parametrization, and the iterative construction of a **Merkle DAG** to ensure efficiency and reproducibility.

### Phase 1: Initialization & Validation ✅

This phase runs once at the beginning of the pipeline to prepare for execution.

1. **Load and Validate Config**: The framework loads the `config` struct, validates its structure, and ensures parameter names do not collide between `globals` and `grid`.

2. **Generate and Filter Runs**: The full Cartesian product of `config.params.grid` is generated to create a list of all possible final runs. The optional `config.params.filter` function is then applied to produce the definitive **`Approved_Runs` list**, which dictates the scope of the experiment.

3. **Build and Sort DAG**: The framework parses `config.stages` to build a Directed Acyclic Graph (DAG) of dependencies. It performs a **topological sort** on the graph to get a linear execution order.

4. **Pre-hash Code**: The framework iterates through all stage functions and pre-computes their **Code Hash** from the respective `.m` files.

### Phase 2: Orchestration & Execution (Building the Merkle DAG) 🚀

This phase executes the main workflow by iteratively building the Merkle DAG of results.

1. **Initialize Merkle DAG Representation**: An in-memory `containers.Map` is created. This map will store the computed **nodes** of the Merkle DAG, keyed by their **Provenance Hash**. Each node contains the output data and its associated metadata.

2. **Iterate Through Stages**: The orchestrator loops through the stages in the topologically sorted order from Phase 1.

3. **For Each Stage, Determine its Tasks**:
    * **A. Identify Relevant Parameter Space 🔬**: The framework determines the minimal set of parameters that affect the current stage by taking the **union** of the stage's own `.params` and the `relevant_parameter_space` from the cached metadata of its inputs.
    * **B. Generate Unique Tasks via Projection ⚡**: The framework generates the minimal sub-grid of unique tasks by **projecting** the `Approved_Runs` list onto the stage's relevant parameter space. This is an efficient `O(M)` in-memory operation (where `M` is the number of approved runs) that uses a hash map to find the unique set of tasks, ensuring that this overhead is negligible compared to the computational savings.

4. **For Each Task, Compute its Node in the DAG**:
    * **A. Compute Node's Merkle Hash**: The orchestrator calculates the task's final **Provenance Hash** (its Merkle hash) by assembling its three components:
        1. The pre-computed **Code Hash**.
        2. The **Granular Parameter Hash** from the task's specific parameter combination.
        3. The **Input Hashes**, which are retrieved via fast lookups from the in-memory map of already-computed parent nodes.
    * **B. Check Cache**: The framework checks for this Provenance Hash in the persistent store and the in-memory map.
    * **C. Execute (if needed)**: If the hash is not found (a cache "miss"), the stage function is executed.
    * **D. Add Node to DAG**: The output data and its metadata are stored in the in-memory map under the new Provenance Hash. If required by the storage policy, the data is also written to the persistent store.

## 4. Caching and Metadata

The framework's caching system is designed to ensure both computational efficiency and the persistent storage of rich metadata for every task. All data and metadata for a single result are stored in an individual `.mat` file, indexed by the **Provenance Hash** of that unique computational task.

### 4.1. File-Based Storage Architecture

The cache is organized around a "file-per-hash" model. Each unique **Provenance Hash** corresponds to a single `.mat` file (e.g., `a1b2c3d4....mat`), which acts as a container for everything related to that specific computation.

Inside each `.mat` file, the data is organized into three distinct top-level variables:

* **`outputs` (struct)**: A struct containing the primary data products from the stage function. Each field in the struct corresponds to a named output (e.g., `outputs.U`, `outputs.S`).
* **`provenance` (struct)**: A single, static struct containing all the information required to reconstruct the task's identity and its position in the dependency graph.
* **`telemetry` (cell array of structs)**: A cell array where each element is a struct containing the historical metrics for a single execution of this task. This allows a complete performance history to be maintained.

### 4.2. `.mat` File Structure for a Cached Task

This structure clearly separates the data payload from the static provenance and the dynamic, run-specific telemetry.

```text
a1b2c3d4...mat
├── outputs (struct)
│   ├── U (double array)
│   ├── S (double array)
│   └── V (double array)
├── provenance (struct)
└── telemetry (1xN cell array of structs)
```

### 4.3. Provenance Metadata Content

The `provenance` variable will contain a struct with the following fields:

```json
{
  "stage_name": "compute_svd",
  "code_hash": "...",
  "parameter_hash": "...",
  "inputs": {
    "local_input_name_1": "hash_of_upstream_output_1",
    "local_input_name_2": "hash_of_upstream_output_2"
  }
}
```

This ensures that the static provenance information is stored once and is immutable.

### 4.4. Telemetry and Cost Metrics

After **every** execution of a task (whether it was a cache miss or a re-run of a `memory_only` task), a new telemetry record is generated and stored.

The `FileBackend` achieves this by loading the existing `.mat` file, appending the new telemetry record to the `telemetry` cell array in memory, and then overwriting the file with the updated contents. This read-modify-write cycle is an atomic operation that guarantees the integrity of the telemetry log.

Standard telemetry fields include:

* `timestamp`
* `status` ('SUCCESS' or 'FAILURE')
* `duration_sec`
* `memory_usage_MB`
* `error_message` (if applicable)

### 4.5. Multi-Level Cache Resolution

The `StorageManager` and `Executor` work together to resolve dependencies. When the `Executor` needs an input, it asks the `StorageManager` to `load(hash)`. The `StorageManager` will:

1. Check the L1 `InMemoryBackend`. If the hash exists, it returns the `outputs` struct directly.
2. If not in L1, it checks the L2 `FileBackend`. If the file `hash.mat` exists, it loads the file, extracts the `outputs` struct, promotes it to the L1 cache, and returns it.
3. If the file does not exist, it throws a `DataNotFound` error, signaling a **Full Miss** to the `Executor`.

This ensures that the `Executor` only ever receives the data payload it needs, while the underlying storage system manages the rich metadata automatically.

## 5. The Storage System

The storage system is designed as a **two-tier architecture** to provide both high performance via in-memory caching and data integrity via persistent on-disk storage. The architecture strictly separates the caching logic from the persistence mechanism. Each component (`StorageManager`, `FileBackend`, `InMemoryBackend`, `ConcurrentStorageDecorator`) is instantiated with a dedicated logger instance to provide detailed operational telemetry.

### 5.1. Architectural Overview

The system is composed of three primary abstractions:

1. **The `StorageManager`:** This component is the single point of contact for the `Executor`. It orchestrates the flow of data between the L1 and L2 backends.

2. **The L1 `IStorageBackend` (In-Memory Store):** A concrete implementation (`InMemoryBackend`) that manages the fast, volatile, and shared in-memory cache for the duration of a single pipeline run.

3. **The L2 `IStorageBackend` (Persistent Store):** A concrete implementation (`FileBackend`) that manages the durable, on-disk store. Each result is saved as an individual `.mat` file in a designated output directory, using its `ProvenanceHash` as the filename.

The `Executor` communicates only with the `StorageManager`, which delegates commands to the appropriate L1 or L2 backend.

```plantuml
!include diagrams/storage_architecture.puml
```

### 5.2. The StorageManager API and Logic

The `StorageManager` is instantiated at the start of a run with two configured `IStorageBackend` instances (one for L1, one for L2). Its API is minimal, exposing only the methods required by the `Executor`.

* **`data = load(hash)`:** This is the primary data retrieval method.
    1. It first calls `exists(hash)` on the L1 backend. If true (**cache hit**), it calls `read(hash)` and returns the data.
    2. If the data is not in L1 (**cache miss**), the manager calls `read(hash)` on the L2 backend.
    3. The retrieved data is then **promoted** by calling `write(hash, data)` on the L1 backend before being returned.

* **`cache(hash, data)`:** This method writes a result to the L1 cache by calling `write(hash, data)` on the L1 backend.

* **`persist(hash)`:** This method promotes data from L1 to L2.
    1. It calls `read(hash)` on the L1 backend to get the data.
    2. It then calls `write(hash, data)` on the L2 backend.

### 5.3. The IStorageBackend Interface

This defines a strict contract for any storage technology to be compliant with the framework.

* **Interface Definition:** An `IStorageBackend` must implement:
  * `write(key, data)`
  * `data = read(key)`
  * `flag = exists(key)`
  * `remove(key)`

### 5.4. Concurrency and Scalability

The storage system is designed for high-throughput parallel execution by separating the concurrency strategies for the L1 and L2 caches.

#### L1 Cache (In-Memory): Concurrency via Decorator

The `InMemoryBackend` is a single object shared by all parallel workers. To ensure thread-safety, the `InMemoryBackend` instance **must** be wrapped in the `ConcurrentStorageDecorator`. This decorator uses an internal mutex to serialize all access to the shared `containers.Map`, guaranteeing the integrity of the in-memory cache.

```plantuml
!include diagrams/storage_concurrency.puml
```

#### L2 Cache (Persistent Files): Concurrency by Design

The `FileBackend` is **inherently thread-safe for writes within this framework**. This is because every unique computational task is identified by a unique `ProvenanceHash`. Since each task's result is saved to a file named after its hash (e.g., `a1b2c3d4....mat`), no two workers will ever attempt to write to the same file path simultaneously. This design completely avoids file I/O bottlenecks and allows for maximum parallel throughput to the persistent store without requiring any in-process locking at the L2 level.

### 5.5. Garbage Collection

The garbage collection utility operates directly on the L2 `FileBackend`.

* **API:** `pipeline.gc(config)`
* **Algorithm (Mark and Sweep):**
  * **Mark:** The utility first calculates the complete set of all "live" `ProvenanceHashes` that are reachable from the provided pipeline configuration.
  * **Sweep:** It then iterates through all `.mat` files in the output directory. For any file whose name (the hash) is not in the "live" set, it calls the `backend.remove(key)` method to delete the file and reclaim storage space.

---

## 6. The Logging System

To provide clear, contextual feedback to the user and aid in debugging, the framework implements a robust logging system built on the `mathworks/advanced-logger`. This system is designed for flexibility, centralized control, and graceful error handling.

### 6.1. Logger Implementation Strategy

The framework will use `mathworks/advanced-logger` directly, leveraging its **named singleton pattern** rather than passing logger objects through dependency injection. This approach simplifies component constructors and reduces "plumbing" overhead while retaining all the benefits of centralized configuration.

* **Centralized Configuration:** The core `pipeline.run()` function is the single point of control for logger configuration. It reads the user's `config.logging` settings and applies them globally to all named loggers used throughout the framework. This guarantees consistent behavior across the entire pipeline.
* **Named Singletons:** Each internal component will obtain its specific logger instance by calling `mlog.Logger('ComponentName')` directly. A hierarchical naming convention (e.g., `pipeline:orchestrator`, `pipeline:storage:manager`) will be used to provide clear context in log outputs.
* **No Internal Configuration:** Components will not configure their own logger instances. They will rely on the central configuration established by `pipeline.run()`.

### 6.2. Dual-Output and Verbosity

The logging system is capable of writing to two destinations simultaneously, with independent verbosity levels.

* **Outputs:** Log messages can be sent to the MATLAB Command Window and a user-specified log file. If `config.logging.filepath` is not provided, output will only be sent to the console.
* **Verbosity Levels:** The system supports a rich set of verbosity levels, configurable independently for the console and the log file:
  * `mlog.Level.INFO` (Default): Provides a high-level summary of pipeline progress, including job start/end, caching events, and key milestones.
  * `mlog.Level.DEBUG`: A verbose output for developers, including fine-grained details like Provenance Hashes, resolver steps, and low-level I/O operations.
  * `mlog.Level.WARNING`: Reports on potential issues that do not immediately halt the pipeline.
  * `mlog.Level.ERROR`: Documents serious issues within a job that require attention.
  * `mlog.Level.FATAL`: Reserved for unrecoverable errors that force a pipeline shutdown.
  * `mlog.Level.OFF`: Suppresses all output.

### 6.3. Robust Error Logging and Handling

The framework prioritizes logging all errors before handling them, ensuring critical information is never lost. This approach is fundamental to enabling the `config.error_mode` functionality.

* **Log Before Handling:** All errors caught within `try/catch` blocks (especially in the `Executor`) will be logged using the `mlog.Level.ERROR` or `mlog.Level.FATAL` level, including the full message and stack trace. This is done *before* the framework decides how to proceed based on `config.error_mode`.
* **Graceful Termination:** Instead of allowing unhandled errors to crash the MATLAB process, the framework will log fatal errors and perform a controlled shutdown. This ensures that resources like file locks are properly released, and the final state of the pipeline is clean and predictable.
* **Consistency with `config.error_mode`:** This controlled approach allows the `Orchestrator` to reliably respond to job failures according to the `config.error_mode` (`'resilient'` or `'fail_fast'`). The logged fatal error is the signal that triggers this state machine transition.

---

## 2.2. The Orchestrator (Stateful Task-Based Scheduler)

The **Orchestrator** is the central coordinating component of the framework. It operates as a stateful, task-based scheduler, and its workflow is as follows:

1. **Initialization:** Loads the configuration object, validates its structure, and generates the list of parameter runs.
2. **Graph Analysis:** Constructs a dependency graph from `config.stages` and performs a topological sort to create a valid execution plan and detect cycles.
3. **Task Scheduling:** Operates as a state machine, managing a registry of all jobs and their statuses (`WAITING`, `READY`, `RUNNING`, `COMPLETE`, `FAILED`, `CANCELLED`). It continuously submits `READY` jobs to the **Executor** component (which implements the `IExecutor` interface) for asynchronous execution.
4. **State Update and Error Handling:** When a job completes, the **Orchestrator** updates the state of all dependent jobs. If a job fails:
    * It is marked as `FAILED`. The error is logged.
    * If `config.error_mode` is `'fail_fast'`, the **Orchestrator** terminates the entire pipeline.
    * If `config.error_mode` is `'resilient'`, the **Orchestrator** traverses the graph downstream from the failed job, marks all its dependents as `CANCELLED`, and continues executing other independent branches.
5. **Reporting:** At the end of the run, the **Orchestrator** provides a summary report of all job statuses.

### Configuration Validation Routine

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

---

## 8. The Dependency Recipe and Resolution System

Dependencies are defined programmatically using a fluent, object-oriented **Recipe**. A Recipe is a stateful **query builder** object that creates a detailed, declarative request for a specific data product.

The system is composed of two main parts: the `Recipe` object that defines the query, and the `Resolver` component that executes it.

### The Recipe API

A user creates a Recipe using the `pipeline.get()` factory method and then chains methods to refine the query. The framework will initially support the following fundamental methods:

* **`get(stage_name, [output_names])`**: The starting point of every recipe. It specifies the source stage and which of its outputs are required.

* **`filter(func_handle)`**: The primary method for filtering runs based on their parameters.
  * **Signature**: `@(params) ...`
  * **Functionality**: The provided handle receives a `ParameterView` object, which securely exposes only the parameters declared in the source stage's `.params`. The handle must return `true` if the run is a match. This validation is performed just-in-time by the `Resolver`.

* **`all()`**: An operator that specifies the query should gather results from **all** runs that match the preceding filters, rather than a single run. This is the key to creating global, fan-in dependencies.

* **`transform(func_handle)`**: Applies a final, in-line transformation to the data after it has been fully resolved and loaded.
  * **Signature**: `@(inputs, source_params) ...`
  * **Functionality**: This is for last-mile data preparation (e.g., truncating a matrix) before the data is passed to the consuming stage.

### The Resolver's Role and Workflow

The **Resolver** is the engine that executes a `Recipe` object. Its responsibility is to translate the recipe into a specific, actionable "work order" for the `Orchestrator`. It does this by recursively calculating the **Provenance Hash** of the requested data.

The workflow is as follows:

1. **Validation**: The `Resolver` receives a `Recipe`. Its first step is to validate any `.filter()` clauses against the source stage's declared `.params`. It will throw a fatal error if the filter attempts to access an undeclared parameter.

2. **Query Execution**: It queries the cache index to find all runs that satisfy the validated filter conditions.

3. **Ambiguity Check**: For any recipe that does not use `.all()`, the `Resolver` enforces that the query must resolve to **exactly one** result. If it matches zero or multiple results, it throws a fatal error.

4. **Resolution**:
    * **For simple recipes**: The `Resolver` recursively calculates the `ProvenanceHash` for the single matching result. It returns this hash and any `.transform()` function to the `Orchestrator`.

---

## 3. Implementation Details and Constraints

This section details low-level design decisions and constraints that are critical for a robust implementation.

### 3.1. Concurrency and File Locking

To prevent cache corruption from concurrent pipeline runs on the same file, the `StorageManager` must implement a file-locking mechanism.

* **Mechanism:** Upon starting a run, the framework will create a `.lock` file next to the HDF5 cache. If this file already exists, the framework will refuse to start and will throw an error.
* **Cleanup:** The `.lock` file must be reliably deleted upon successful completion or in a `try/catch/finally` block to handle termination due to an error.

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

---

## Architectural Principles

Our architecture is guided by a core philosophy, translated into five technical rules:

1. **MATLAB-Native Experience:** The framework must feel like a natural extension of MATLAB. All user-facing interfaces will use idiomatic MATLAB syntax (e.g., programmatic recipes, function handles) over custom string-based languages.
2. **Uncompromising Reproducibility:** Every result must be verifiably reproducible. Caching is not just for speed; it is a guarantee of correctness, achieved through provenance-based hashing.
3. **Declarative Configuration as Code:** Users will declare *what* the pipeline should do in a version-controllable MATLAB file, separating the workflow definition from the execution engine.
4. **Aggressive Separation of Concerns:** A strict separation will be maintained between scientific logic (in component functions), optimization logic (in dependency recipes), and framework logic (in the executor).
5. **Flexible and Composable Data Flow:** The framework is a toolkit for building complex computational graphs. The dependency system is designed as a powerful query language to support non-linear workflows with shared sources, branches, and mixed-scope dependencies.

---
