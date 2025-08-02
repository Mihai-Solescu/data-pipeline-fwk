# Contributing to the Scientific Pipeline Framework

Thank you for your interest in contributing to this project! This document provides guidelines and conventions for developers working on the framework's source code.

---

## Development Philosophy

Our goal is to create a robust, maintainable, and well-tested codebase. We adhere to a **Test-Driven Development (TDD)** model. Before implementing any new feature, corresponding tests should be written to define and verify its behavior.

All code should be clean, well-commented, and adhere to the architectural principles laid out in the `docs/ADD.md`.

### Specific Guidelines

**Testing concurrent threads has to be done using the Asynchronous Test Harness with Timeout pattern.** This is crucial for maintaining the reliability of our test suite by ensuring that tests do not hang indefinitely in the case of a deadlock. This pattern involves using `parfeval` to run operations on parallel workers and then collecting the results with `fetchOutputs(futures, 'Timeout', SECONDS)`.

We use `mathworks/advanced-logger` for all logging. When writing or modifying code:

1. **Do not use `disp()`, `fprintf()`, or `warning()` for framework-related messages.** All informational, debug, and error messages must go through the logger.
2. **Do not configure the logger directly inside your component or class.** Configuration (e.g., setting log levels or file paths) is handled centrally by the `pipeline.run()` function. Your components should only retrieve the named logger instance or accept one in their constructor.
3. **Use a specific named logger.** Always retrieve a logger with a name that corresponds to your component, using the hierarchical naming convention (e.g., `mlog.Logger('pipeline:component:subcomponent')`).
4. **Log all errors before handling them.** If a `try/catch` block is used to handle an error, the `catch` block must first log the error (at `mlog.Level.ERROR` or `mlog.Level.FATAL`) before any further processing or a graceful exit.
5. **Use correct logging argument patterns.** The advanced-logger uses `sprintf` formatting. The first argument is always the format string, and subsequent arguments are the values to substitute. For structured messages with identifiers, include the identifier in the format string:

   ```matlab
   % CORRECT: Identifier and message in single format string
   logger.debug('pipeline:component:EventName: Description with %s and %d', stringVar, numVar);
   
   % INCORRECT: Separate identifier and message arguments
   logger.debug('pipeline:component:EventName', 'Description with %s', stringVar);
   ```

   The incorrect pattern fails because the logger treats the identifier as the format string and ignores subsequent arguments when no format specifiers are present.

---

## Error and Log Taxonomy

To ensure that the framework's behavior is predictable and debuggable, we use a standardized taxonomy for all custom errors and significant log messages.

### Naming Convention

All custom error and log identifiers thrown or logged by the framework must follow a three-part convention:

**`pipeline:<ComponentName>:<Identifier>`**

* **`pipeline:`:** A consistent prefix for all framework-generated outputs.
* **`<ComponentName>`:** The CamelCase name of the internal component where the error or log originates (e.g., `StorageManager`, `Resolver`).
* **`<Identifier>`:** A concise, CamelCase name for the specific error or log event (e.g., `OverwriteAttempt`, `JobComplete`).

I've updated and expanded the taxonomy to cover the entire storage system, assigning logs and errors to the specific component responsible for them.

---

### Storage System Log and Error Taxonomy

This taxonomy is divided by component to clarify where each message originates.

#### `HDF5Backend` (L2 Persistent Store)

These logs relate to the direct management of the on-disk HDF5 file and its associated lock file.

| Identifier | Log Level | Description |
| :--- | :--- | :--- |
| `pipeline:HDF5Backend:FileLocked` | `FATAL` | The `.lock` file for the target cache already exists, preventing a new pipeline instance from starting. |
| `pipeline:HDF5Backend:LockCreationFailed`| `FATAL` | The framework failed to create the `.lock` file, likely due to file system permission issues. |
| `pipeline:HDF5Backend:WriteError` | `ERROR` | A low-level error occurred during an HDF5 write operation (e.g., disk full, file corruption). |
| `pipeline:HDF5Backend:ReadError` | `ERROR` | A low-level error occurred during an HDF5 read operation (e.g., file corruption, dataset not found). |
| `pipeline:HDF5Backend:OverwriteAttempt` | `ERROR` | An attempt was made to write to a key that already exists, which violates the immutability contract. |
| `pipeline:HDF5Backend:LockCleanupFailed`| `WARN` | The destructor failed to delete the `.lock` file. This is not fatal but requires user attention to prevent future runs from failing. |
| `pipeline:HDF5Backend:LockAcquired` | `DEBUG` | Logged upon successfully creating the `.lock` file for the HDF5 store. |
| `pipeline:HDF5Backend:LockReleased` | `DEBUG` | Logged upon successfully deleting the `.lock` file at the end of a run. |

#### `InMemoryBackend` (L1 In-Memory Store)

This component is a simple wrapper around `containers.Map` and has minimal specific logging.

| Identifier | Log Level | Description |
| :--- | :--- | :--- |
| `pipeline:InMemoryBackend:CacheCleared` | `INFO` | The in-memory cache has been cleared, for example, at the end of a pipeline run. |

#### `StorageManager` (The Orchestrator)

These logs describe the flow of data between the L1 and L2 caches.

| Identifier | Log Level | Description |
| :--- | :--- | :--- |
| `pipeline:StorageManager:DataNotFound` | `ERROR` | A requested key was not found in the L1 in-memory cache **or** the L2 persistent store. This is the official "cache miss" signal. |
| `pipeline:StorageManager:PersistRequestFailed`|`ERROR` | A request was made to persist data from L1 to L2, but the key did not exist in the L1 cache. This indicates a logic error. |
| `pipeline:StorageManager:L2CacheHit` | `INFO` | Data was not found in the L1 cache but was successfully retrieved from the L2 persistent store. |
| `pipeline:StorageManager:DataPromotedToL1` | `DEBUG` | Data retrieved from the L2 store was successfully written to the L1 cache for faster access. |
| `pipeline:StorageManager:L1CacheHit` | `DEBUG` | Data was successfully found and returned directly from the L1 in-memory cache. |
| `pipeline:StorageManager:DataCachedToL1` | `DEBUG` | A new result (from the `Executor`) was successfully written to the L1 in-memory cache. |
| `pipeline:StorageManager:DataPersistedToL2`| `DEBUG` | Data was successfully written from the L1 cache to the L2 persistent store. |

#### `ConcurrentStorageDecorator`

These logs are specific to the thread-safety wrapper and are crucial for debugging parallel execution.

| Identifier | Log Level | Description |
| :--- | :--- | :--- |
| `pipeline:ConcurrentStorageDecorator:LockWait`|`DEBUG`| A thread is waiting to acquire a lock held by another thread, indicating contention. |
| `pipeline:ConcurrentStorageDecorator:LockAcquired`|`DEBUG`| A thread successfully acquired the in-process lock to perform a storage operation. |
| `pipeline:ConcurrentStorageDecorator:LockReleased`|`DEBUG`| A thread successfully released the in-process lock after a storage operation. |

---

### ProvenanceHasher

This taxonomy covers all logs and errors generated by the `pipeline:ProvenanceHasher` service during the computation of a task's `ProvenanceHash`.

| Identifier | Log Level | Description |
| :--- | :--- | :--- |
| `pipeline:ProvenanceHasher:FunctionNotFound` | `FATAL` | The source `.m` file for a stage's function handle could not be located on the MATLAB path. This is a critical configuration error. |
| `pipeline:ProvenanceHasher:MissingParameter` | `FATAL` | A stage required an explicit parameter that was not provided in the parameter set for the task. This indicates a logic error in the `Orchestrator`. |
| `pipeline:ProvenanceHasher:HashComponentComputed` | `DEBUG` | A detailed log containing the three component hashes (code, params, inputs) along with the stage name just before they are combined into the final `ProvenanceHash`. Useful for debugging hash computations and understanding why a particular task has a specific hash value. |
| `pipeline:ProvenanceHasher:CodeHashCacheHit` | `DEBUG` | A `Code Hash` was successfully retrieved from the in-memory cache, avoiding a file read operation. |
| `pipeline:ProvenanceHasher:CodeHashComputed` | `DEBUG` | A `Code Hash` was computed by reading a stage's source file for the first time and has been added to the in-memory cache. |

---

### StageGraph

This taxonomy covers logs and errors generated by the `pipeline:StageGraph` component during its construction and validation. The `StageGraph` receives a logger instance in its constructor and uses it to report the outcome of the graph-building process.

| Identifier | Log Level | Description |
| :--- | :--- | :--- |
| `pipeline:StageGraph:InvalidInput` | `FATAL` | The `config.stages` object passed to the constructor was not a valid, non-empty struct. |
| `pipeline:StageGraph:CircularDependency` | `FATAL` | A cycle was detected in the stage dependencies. The graph is not a valid Directed Acyclic Graph (DAG). |
| `pipeline:StageGraph:InvalidDependencyTarget` | `FATAL` | An input recipe for a stage refers to a source stage that does not exist in the configuration. |
| `pipeline:StageGraph:StageNotFound` | `FATAL` | An internal or external call requested information for a stage name that does not exist in the graph. |
| `pipeline:StageGraph:ConstructionSuccess` | `INFO` | The StageGraph was successfully constructed, validated as a DAG, and is ready for use. |
| `pipeline:StageGraph:ParameterResolutionComplete` | `DEBUG` | The recursive process of resolving all implicit and explicit parameter dependencies for every stage has completed successfully. |

---

### ConfigValidator

This taxonomy covers logs and errors generated during the initial validation of the `config` struct.

| Identifier | Log Level | Description |
| :--- | :--- | :--- |
| `pipeline:ConfigValidator:MissingRequiredField` | `FATAL` | A required field (e.g., `config.stages`) is missing from the configuration. |
| `pipeline:ConfigValidator:InvalidFieldType` | `FATAL` | A field has an incorrect data type (e.g., `stages` is not a struct). |
| `pipeline:ConfigValidator:ParameterNameCollision` | `FATAL` | A parameter name is defined in both `globals` and `grid`. |
| `pipeline:ConfigValidator:IncompleteLoggingConfig` | `FATAL` | Either `config.logging.filepath` or `config.logging.file_level` is specified without the other. Both must be provided together for file logging. |
| `pipeline:ConfigValidator:CircularDependency` | `FATAL` | The stage graph is not a valid DAG; a cycle was detected. |
| `pipeline:ConfigValidator:InvalidDependencyTarget` | `FATAL` | An input recipe in a stage's `.inputs` field points to a stage or output that does not exist. |
| `pipeline:ConfigValidator:UnexpectedField` | `WARN` | An unrecognized field was found in the `config` struct. The field will be ignored. |

## Implementation Details

### Logger Initialization Sequence

To ensure that all framework actions, including configuration validation errors, are reliably captured, the logging system is initialized in a specific sequence within `pipeline.run()`. When contributing to this part of the codebase, it is crucial to adhere to this order:

1. **Initialize with Defaults:** The very first action upon entering `pipeline.run` is to configure the `mlog` system with safe, hardcoded defaults (e.g., log to the console at `INFO` level). This guarantees that a logger is immediately available to report any subsequent errors.

2. **Partial Validation of Logging Config:** The `ConfigValidator` is invoked to check *only* the `config.logging` struct. This isolated check ensures the user-provided logging settings are syntactically correct before they are applied.

3. **Reconfigure Logger:** If the logging configuration is valid, the `mlog` system is immediately reconfigured using the user's settings from `config.logging`.

4. **Full Configuration Validation:** The `ConfigValidator` is invoked again to validate the remainder of the `config` struct.

This sequence ensures that if the user's logging configuration itself is invalid, the error is caught and reported by the default logger. All subsequent validation warnings and errors are then correctly routed to the user's specified destinations (e.g., a log file).
