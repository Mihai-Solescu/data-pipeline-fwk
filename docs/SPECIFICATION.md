# Specification: General-Purpose Scientific Pipeline Framework

**Version:** 0.5.0
**Date:** 2025-07-20
**To be deleted -> Split into SRS and ADD**

---

## 1. Project Vision

To create a modular, reusable, and efficient MATLAB framework for executing complex, multi-stage scientific computing workflows. The framework will serve as a general-purpose "build system" for data analysis, driven entirely by a user-defined configuration file. Its purpose is to accelerate research by automating parameter sweeps, ensuring reproducibility, eliminating redundant computations, and minimizing data storage through intelligent management of intermediate results.

## 2. Core Objectives

* **Modularity & Reusability**: Decouple the pipeline's execution logic from the scientific computation itself. The core engine should be reusable across different projects (e.g., HAVOK analysis, machine learning model training, signal processing).
* **Reproducibility**: Ensure that a given configuration file and dataset will always produce the exact same results through content-based hashing.
* **Computational Efficiency**: Implement a dependency-based workflow that avoids re-running any computational stage unless its inputs, code, or relevant parameters have changed.
* **Extensibility**: The framework must be easily extensible. Adding new parameters, computational stages, or post-processing metrics should be achievable by modifying only the configuration file and adding new, isolated component functions, without altering the core pipeline executor.
* **User-Driven Optimization**: Empower scientists to define custom, semantically-aware optimization policies for data persistence and retrieval. This enables advanced strategies like conditional storage and intelligent sharing of results between runs to minimize storage and computational costs.

## 3. Scope

### In Scope

* A generic pipeline executor script.
* A configuration system for defining parameter grids and a computational dependency graph.
* Management of a single-file, HDF5-based storage backend.
* An in-memory caching mechanism for a single pipeline run.
* Automatic dependency checking and result invalidation ("staleness" check).
* **DAG Validation**: Verification that the stage dependencies form a Directed Acyclic Graph.
* **Advanced Dependency Resolution**: Support for singleton stages (run once), per-run stages, and global barrier stages, with behavior inferred from dependency declarations.
* **Inter-Run Parallelism**: Support for executing independent parameter runs in parallel (e.g., via `parfor`).
* Support for stateless, single-responsibility computational component functions.

### Out of Scope

* **GUI**: A graphical user interface.
* **Advanced Parallelism**: Intra-run parallelism (parallelizing different branches of the DAG within a single run).
* **Distributed Computing**: Execution across multiple machines (though the architecture does not preclude this as a future extension).
* **Real-time Processing**: Streaming or real-time data ingestion and processing.
* The scientific algorithms themselves (e.g., HAVOK, SVD), which are treated as user-provided "plug-ins" to the framework.
* **Ordinal parameters**: (e.g., parameters with an inherent, non-alphanumeric order like 'LOW' < 'MEDIUM' < 'HIGH') will perhaps be supported late on. One idea on how to implement them is to add a config `struct` (e.g. `config.param_orders.model_complexity = {'SIMPLE', 'INTERMEDIATE', 'COMPLEX'}`) and modify the signature of `config.param_filter` to `@(param_combination, param_orders) ...`.
* **Human-Readable Data View**: The framework will not automatically generate a human-friendly, hierarchical view of the data within the HDF5 file (e.g., using a `/browse/` tree with soft links). While such a feature would significantly improve the browsability of the storage backend, it introduces considerable complexity. Ensuring perfect, real-time consistency between the content-addressable data store and a separate human-readable view would require robust synchronization and verification utilities to handle potential discrepancies caused by interruptions or crashes. This feature is deferred to a future version in favor of prioritizing data integrity and a simpler implementation.
* **Advanced Reproducibility Optimizations**: To ensure absolute integrity, the framework's core design will not be complicated by optimizations that could compromise reproducibility. This includes:
  * **Code Canonicalization**: A system to parse MATLAB code and strip comments or normalize whitespace before hashing. While this would prevent cosmetic code changes from triggering re-computation, it requires a complex and potentially brittle parser. The current full-file hashing provides a stricter, more predictable guarantee.
  * **Managed Random Seeds**: A feature where the executor would automatically control the seed for MATLAB's random number generator (`rng`) to make stochastic processes reproducible. While valuable, this is considered a non-essential feature for the initial version and can be added later.
* **Advanced Parameter Schemas and Validation**: A formal system for defining and validating parameter types is deferred to a future version. While not required for the core functionality, a schema would significantly increase the framework's robustness and maintainability.
  * **What a Schema Is**: A schema would act as a centralized "data dictionary" or "type system" for the framework. It is a separate definition file that describes the fundamental properties of parameters (e.g., their type, valid ranges, default values, or order for ordinals), separating their definition from their use in a specific experiment's configuration.
  * **Why It Is Useful**:
    * **Order for filtering and visualization**: It allows filtering based on properties like order for ordinal parameters, and allows for things like plotting the parameter values in the appropriate order later down the pipeline.
    * **Validation**: It allows the framework to validate an entire experiment's configuration before execution, catching errors like out-of-range values early.
    * **Maintainability**: It follows the "Don't Repeat Yourself" (DRY) principle. Parameter definitions are centralized, making them easier to manage across multiple projects or experiments.
    * **Robustness**: It makes advanced optimizations (like the `policy=max&by=rank` resolver) more robust by allowing the framework to validate lookup queries against a well-defined data model, preventing typos and logical errors.
    * **Clarity**: It keeps the main `pipeline_config.m` file clean and focused on defining the experimental sweep, rather than being cluttered with the low-level definitions of its parameters.
  * **Future Implementation Path**: A schema would be implemented by creating a dedicated definition file (e.g., `+types/schema.m`). The pipeline executor would load this schema at startup and use it to validate the `pipeline_config.m` before any computation begins.

## 4. Versioning

The framework will follow Semantic Versioning 2.0.0 (Major.Minor.Patch).

---

## 5. System Architecture

The framework consists of three primary components: the **Configuration File**, the **Pipeline Executor**, and the **Stateless Components**.

### 5.1 The Configuration File (`pipeline_config.m`)

The configuration file is the single source of truth for the entire workflow. It is a MATLAB function that returns a `config` struct. Its primary role is to define the parameter space for the experiment and the computational dependency graph.

#### **Parameter Space Definition**

The framework processes parameters by first generating a **struct array**, where each struct represents a single, unique run and its fields correspond to the parameter names (e.g., `run.ranks`, `run.delays`). This allows for easy and readable access to parameter values throughout the pipeline. The `config` struct must contain the following fields to define this parameter space:

* **`config.param_mode`** (string, optional): Specifies the method for generating parameter runs. Defaults to `'grid'`.
  * **`'grid'`**: The framework generates the Cartesian product of all parameter values defined in `config.parameters`.
  * **`'list'`**: The framework uses an explicitly defined list of runs from `config.runs`.

* **`config.parameters`** (struct): Used when `param_mode` is `'grid'`. Each field name corresponds to a parameter, and its value is an array of the values to be tested (e.g., `config.parameters.ranks = [10, 20];`).

* **`config.runs`** (struct array): Used when `param_mode` is `'list'`. Each element of the array is a struct defining one specific parameter combination.

* **`config.param_filter`** (function handle, optional): A handle to a function that filters the generated parameter runs.
  * The function must accept a single argument (a struct for one run) and return a logical `true` to keep the run or `false` to discard it.
  * This is the primary mechanism for creating non-grid parameter sweeps, such as triangular spaces where one parameter must be greater than another.

#### **Stage Definition**

* **`config.storage.filepath`**: A string containing the path to the HDF5 file where results will be stored.

* **`config.stages`**: A struct array defining the computational dependency graph. Each element represents a single stage and is defined by the following fields:

  * **`.name`** (string, Required): A unique, human-readable name for the stage (e.g., `'compute_svd'`). This name is used as the target for dependencies.

  * **`.function`** (function handle, Required): A handle to the MATLAB function that executes the stage's logic (e.g., `@processing.compute_svd`).
  
  * **(old consideration of how to handle dependencies)** **`.dependencies`** (cell array of strings): A list of the `names` of other stages that must be successfully completed before this stage can run. Special keywords like `'params'` and `'master_data'` can be used to indicate dependencies on the run's parameter set and the initial master dataset.
  * **(new consideration, still looking for alternatives)** **`.dependencies`** (struct, Required): A struct that maps the input names for the component function to their data sources using a URI-like string. This defines both the dependency graph and the input data mapping.
    * **Format**: `scheme://<source>/<product>?<policy_query>`
    * **Examples**:
      * `'havok://param/truncation_rank'`: Provides the value of the `truncation_rank` parameter for the current run.
      * `'havok://build_hankel/H'`: Provides the `H` output from the `build_hankel` stage for the current run (an exact parameter match).
      * `'havok://calculate_error/model_error:all'`: An aggregated dependency. Provides a collection of all `model_error` outputs from all runs. This implicitly makes the current stage a global barrier.
      * `'havok://compute_svd/U?policy=max&by=rank'`: A resolved dependency. Provides the `U` output from the `compute_svd` stage that corresponds to the maximum value of the `rank` parameter among all persisted results.

  * **`.outputs`** (cell array of strings, Required): A list of the names of the data products this stage generates (e.g., `{'U', 'S', 'V'}`).

  * **`.storage_policy`** (string or function handle, Optional, Default: `'persistent'`): Controls how outputs are stored after computation.
    * `'persistent'`: The output is saved to the HDF5 data store.
    * `'memory_only'`: The output is only kept in the in-memory cache for the current pipeline execution.
    * **Function Handle**: For conditional storage. Must have the signature `do_save = f(current_params, all_params)` and return `true` to save.

### 5.2 The Pipeline Executor (`main_pipeline.m`)

The executor is a generic engine that reads the `config` struct and manages the entire workflow based on the dependency graph.

#### **Execution Workflow**

The executor's process is no longer a simple loop, but a sophisticated traversal of the dependency graph:

1. **Initialization**:
    * Load the `config` structure.
    * Generate the final list of parameter run structs after applying any `param_filter`.

2. **Graph Analysis and Validation**:
    * Construct the full dependency graph from `config.stages`.
    * Perform a **topological sort** to create a linear execution order and to verify the graph is acyclic (a DAG). The pipeline will terminate with an error if a cycle is detected.
    * **Infer Stage Types**: Analyze the dependencies of each stage to classify it as a **Setup Stage** (no parameter dependencies), **Per-Run Stage** (depends on parameters), or **Global Barrier Stage** (has an aggregated `:all` dependency).

3. **Stage Execution**:
    * Traverse the topologically sorted list of stages.
    * For **Setup Stages**, execute them once and cache their results.
    * For **Per-Run Stages**, iterate through all parameter runs (potentially in parallel using `parfor`) and execute the stage for each run. For each execution, it will:
      * **Resolve Dependencies**: Parse the dependency URIs, call any necessary resolvers (e.g., for `policy=max`), and gather inputs from the in-memory cache or persistent storage.
      * **Check Cache**: Calculate the **Master Hash** for the stage's output. If a valid result exists in the persistent store, load it and skip execution.
      * **Execute**: If no valid result is found, call the component function.
      * **Store Results**: Place outputs in the in-memory cache. If the `storage_policy` dictates, save the outputs and their metadata attributes to the HDF5 file under their Master Hash and update the `index/manifest`.
    * For **Global Barrier Stages**, the executor will first ensure all prerequisite per-run stages have completed for all runs. It will then aggregate the necessary inputs and execute the global stage once.

### 5.3 Stateless Components (`+processing/`, `+metrics/`, etc.)

All functions referenced by function handles in the config file must be **pure** and **stateless**.

* They must accept a single struct argument, `inputs`, which contains all necessary data for the computation (e.g., `inputs.H`, `inputs.params`).
* They must return a single struct, `outputs`, containing all generated data products, with field names matching those listed in the stage's `.outputs` configuration.
* They must **not** perform any file I/O or access any global state. Their only job is to compute.

### 5.4 Hash-Based Storage and Data Management

To ensure maximum computational efficiency and resilience to configuration changes, the framework employs a content-addressable storage strategy instead of a traditional hierarchical one based on parameter names. This system is composed of a data store, an index, and a garbage collection utility.

#### **HDF5 File Structure**

The HDF5 storage file is organized into two primary components:

* **`/data/`**: A flat group that serves as the primary data store. Every data product generated by any stage is stored in its own subgroup within `/data/`. The name of this subgroup is a unique **Master Hash**, which acts as a fingerprint for the data based on its content and provenance.
* **`/index/manifest`**: A single, table-like dataset that acts as the source of truth for the entire storage system. It maps human-readable concepts to the content hashes in the data store. Each row in the manifest contains at least the `stage_name`, the hash of the relevant parameter subset (`param_subset_hash`), and the corresponding `master_hash` pointing to the result in `/data/`.

#### **The Master Hash: A Unique Fingerprint**

The framework avoids re-computation by checking for the existence of a valid result. A result is considered valid if its "Master Hash" already exists and is up-to-date. This hash is computed from three sources to guarantee reproducibility:

1. **Code Hash**: A hash of the component function's M-file (e.g., a SHA-256 hash of `compute_svd.m`). This detects any changes to the algorithm's implementation.
2. **Input Data Hashes**: The Master Hashes of all data products that serve as inputs to the current stage. This detects changes in any upstream dependency.
3. **Parameter Hash**: A hash of the specific subset of parameters that the stage depends on. This allows the framework to reuse results even when unrelated parameters are changed.

#### **Execution and Storage Workflow**

1. **Lookup**: Before executing a stage, the executor computes the expected Master Hash based on the current code, inputs, and relevant parameters. It then queries the `/index/manifest` to see if this hash is already registered.
2. **Reuse**: If a valid entry is found in the index, the executor skips the computation and loads the result directly from `/data/<master_hash>`.
3. **Compute & Store**: If no valid entry is found, the executor runs the component function. It then saves the resulting data product to a new group `/data/<new_master_hash>` and adds a corresponding entry to the `/index/manifest` table.
4. **Metrics**: Execution metadata, such as `computation_time` or `timestamp`, are not stored as datasets. They are saved as **HDF5 attributes** directly onto the result's group (e.g., on `/data/<new_master_hash>`).

#### **Garbage Collection**

This storage strategy never overwrites data; it only adds new results. To manage storage space, a separate **garbage collection** utility (`pipeline_gc.m`) is required. This utility performs a "Mark and Sweep" operation:

* **Mark**: It first identifies the complete set of all "live" Master Hashes that are reachable from the *current* `pipeline_config.m`.
* **Sweep**: It then scans the `/data/` store and the `/index/manifest`. Any entry whose hash is not in the "live" set is considered orphaned and is deleted, reclaiming storage space.

---

## 6. Functional Requirements

* **FR-1**: The system shall execute a computational pipeline defined entirely by the `config.stages` struct.
* **FR-2**: The system shall generate a set of parameter runs based on grid or list definitions, and optionally filter them.
* **FR-3**: The system shall persist results to a content-addressable HDF5 file, using a unique hash for each data product.
* **FR-4**: The system shall not re-execute a stage if a valid result—determined by hashing the stage's code, inputs, and relevant parameters—already exists.
* **FR-5**: The system shall support singleton (setup), per-run, and global (barrier) stages, with behavior inferred from dependency declarations.
* **FR-6**: The system shall allow fine-grained, conditional storage of stage outputs via the `storage_policy` field.
* **FR-7**: The system shall support user-defined resolver policies in dependency declarations to enable intelligent, cross-run data sharing and retrieval.

## 7. Non-Functional Requirements

* **NFR-1 (Performance)**: The overhead of the pipeline executor itself shall be negligible (<1%) compared to the total time of the computational tasks themselves.
* **NFR-2 (Usability)**: Adding a new computational stage to the workflow shall only require creating a new component function and adding a corresponding entry to the `config.stages` struct, with no modifications to the pipeline executor.
* **NFR-3 (Reliability)**: The pipeline shall be resumable. If interrupted, it should pick up from the first missing stage on the next run.
* **NFR-4 (Maintainability)**: The framework's code shall be modular, with a strict separation of concerns between the engine, configuration, and the computational components.

## 8. Acceptance Criteria

* **AC-1**: Given a pipeline with two stages (A -> B), if A's output is missing from the HDF5 file, the executor runs both stage A and stage B.
* **AC-2**: Given the same pipeline, if A's output exists in the HDF5 file but B's is missing, the executor loads A's result from the file and executes only stage B.
* **AC-3**: If a stage (e.g., Hankel generation) is configured with `storage_policy = 'cache_only'`, its output (the Hankel matrix) is not written to the HDF5 file but is successfully passed in memory to the next stage (e.g., SVD).
* **AC-4**: After a successful run, adding a new metric stage to the end of the `config.stages` array and re-running the pipeline results in only the new metric stage being executed for all parameter combinations, with all previous stages being skipped.

## 9. Use Cases and Scenarios

This section describes several complex, real-world research scenarios and explains how the framework's architecture is designed to handle them efficiently and robustly.

### Use Case 1: Multi-Scale Model Analysis with Shared SVD

* **Scenario**: A scientist wants to analyze a system using HAVOK at multiple truncation ranks (`r = [10, 20, 50, 100]`). The Singular Value Decomposition (SVD) of the data matrix is the most computationally expensive step. To save time, the SVD should only be computed once at the highest required fidelity (`r=100`), and all lower-rank models should use a truncated version of this single, high-fidelity SVD.
* **Framework Implementation**:
  1. The `build_model` stage declares its dependency on the SVD outputs using a resolver policy: `dependencies.U = 'havok://compute_svd/U?policy=max&by=rank'`.
  2. The `compute_svd` stage uses a conditional storage policy to only persist the result for the run with the maximum rank: `storage_policy = @(p, all) p.rank == max([all.rank])`.
* **How the Framework Shines**:
  * **Intelligent Retrieval**: For the `r=10` run, the resolver queries the persistent store, finds the SVD result for `r=100` (the only one saved), and provides it as the input. The component function for `build_model` is responsible for truncating this SVD to the required 10 dimensions.
  * **Resilience to Change**: If the scientist later adds `rank=120` to the sweep, the framework will see that a new "max" rank exists. It will execute `compute_svd` for `r=120`, persist this new result, and automatically use it for all other runs in the new sweep. The old `r=100` SVD becomes orphaned, ready for garbage collection.

### Use Case 2: Hyperparameter Sweep with Global Analysis

* **Scenario**: A machine learning model is trained over a grid of hyperparameters (e.g., `learning_rate`, `layer_size`). Each of the 100+ training runs produces a validation error metric. After all runs are complete, a single global stage must execute to find the parameters of the best-performing model and generate a summary plot of the error surface.
* **Framework Implementation**:
  1. A per-run stage, `train_and_validate`, outputs a `validation_error`.
  2. A final stage, `analyze_results`, declares an aggregated dependency: `dependencies.all_errors = 'havok://train_and_validate/validation_error:all'`.
* **How the Framework Shines**:
  * **Inferred Global Barrier**: The executor sees the `:all` aggregator and understands that `analyze_results` is a global barrier. It will execute all 100+ training runs first (potentially in parallel using `parfor`).
  * **Data Aggregation**: Once all training runs are complete, the executor gathers every `validation_error` output from the cache and persistent store into a single collection and provides it to the `analyze_results` stage, which runs only once.

### Use Case 3: Resuming a Pipeline After a Code Change

* **Scenario**: A pipeline with three stages (A -> B -> C) is executed. After it completes, the scientist modifies the code for stage B. They want to re-run the pipeline to get the updated results for B and C, without re-computing the expensive stage A.
* **Framework Implementation**: The user simply re-runs the main pipeline script.
* **How the Framework Shines**:
  * **Content Hashing**: When the executor evaluates stage A, it finds that its code, inputs, and parameters are unchanged. Its Master Hash matches the one in the index, so it reuses the persisted result instantly.
  * **Cascading Invalidation**: For stage B, the executor detects that its **Code Hash** has changed. This invalidates its Master Hash, so it re-executes stage B. When it gets to stage C, it sees that the **Input Data Hash** (from the new output of B) is different from what's stored. This invalidates C's Master Hash, and it is also re-executed. The framework automatically does the minimum work necessary.

### Use Case 4: Singleton Data Source with Per-Run Subsetting

* **Scenario**: A researcher wants to test the HAVOK algorithm on different combinations of variables from the Lorenz system (`x`, `y`, `z`). The full Lorenz timeseries should be generated only once. For each run, a parameter `variable_subset` (e.g., with values `'x'`, `'xz'`, `'xyz'`) determines which variables (columns) are selected from the master timeseries to build the Hankel matrix.
* **Framework Implementation**:
  1. A **setup stage**, `generate_lorenz_data`, has no parameter dependencies. It runs only once, generating the full 3-column timeseries and persisting it.
  2. A **per-run stage**, `select_variables`, depends on the output of `generate_lorenz_data` and the `param:variable_subset`. For each run, it takes the full timeseries and the subset key (e.g., `'xz'`) and outputs a new matrix containing only the required columns. Its `storage_policy` is `'memory_only'`.
  3. Downstream stages, like `build_hankel`, depend on the output of `select_variables`.
* **How the Framework Shines**:
  * **Automatic Singleton Detection**: The executor sees that `generate_lorenz_data` has no parameter dependencies and automatically treats it as a setup stage, running it only once and reusing its result for all subsequent runs.
  * **Efficient Data Flow**: The expensive data generation is completely decoupled from the parameter sweep. The lightweight `select_variables` stage runs for each parameter combination, creating cheap, in-memory "views" of the master data without cluttering the persistent storage.

### Use Case 5: Adaptive Model Persistence via a Collector Stage

* **Scenario**: A scientist is searching for stable dynamical models. They sweep several parameters, including `embedding_dim`. For each `embedding_dim`, they want to persist **only the most stable model** found across all other parameter variations. If no stable models are found for a given `embedding_dim`, they want to persist the *least unstable* one as a fallback, ensuring they have at least one representative model for each dimension.
* **Framework Implementation**:
  1. A per-run stage `build_and_evaluate_model` computes a `model_object` and an `instability_metric` for every single parameter combination. Its `storage_policy` is `'memory_only'`, so none of these hundreds of models are initially saved.
  2. A **global barrier stage**, `select_best_models`, declares an aggregated dependency on all `model_object` and `instability_metric` outputs from the previous stage (`havok://...:all`).
  3. The component function for `select_best_models` receives all models and their metrics. It contains the logic to group the models by `embedding_dim`, find the most stable (or least unstable) one in each group, and then explicitly save only these "best" models to the HDF5 file.
* **How the Framework Shines**:
  * **Decoupled Computation and Storage**: This demonstrates a powerful **two-pass optimization**. The first pass computes all possible results in memory, leveraging parallel execution. The second pass, a single collector stage, makes an intelligent, results-aware decision about the small subset of data that is valuable enough for long-term persistence.
  * **Complex Logic Encapsulation**: The sophisticated logic for "what is the best model" is not scattered across conditional storage policies but is cleanly encapsulated in a single, well-defined global analysis stage. This makes the optimization strategy clear and maintainable.
