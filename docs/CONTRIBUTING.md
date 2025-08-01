# Contributing to the Scientific Pipeline Framework

Thank you for your interest in contributing to this project! This document provides guidelines and conventions for developers working on the framework's source code.

---

## Development Philosophy

Our goal is to create a robust, maintainable, and well-tested codebase. We adhere to a **Test-Driven Development (TDD)** model. Before implementing any new feature, corresponding tests should be written to define and verify its behavior.

All code should be clean, well-commented, and adhere to the architectural principles laid out in the `docs/ADD.md`.

### Specific Guidelines

Testing concurrent threads has to be done using the **Asynchronous Test Harness with Timeout** pattern, in order to ensure that tests do not hang indefinitely. This is crucial for maintaining the reliability of our test suite.

We use `mathworks/advanced-logger` for all logging. When writing or modifying code:

1. **Do not use `disp()`, `fprintf()`, or `warning()` for framework-related messages.** All informational, debug, and error messages must go through the logger.
2. **Do not configure the logger directly inside your component or class.** Configuration (e.g., setting log levels or file paths) is handled centrally by the `pipeline.run()` function. Your components should only retrieve the named logger instance.
3. **Use a specific named logger.** Always retrieve a logger with a name that corresponds to your component, using the hierarchical naming convention (e.g., `mlog.Logger('pipeline:component:subcomponent')`). This ensures granular control and clear context in the log output.
4. **Log all errors before handling them.** If a `try/catch` block is used to handle an error, the `catch` block must first log the error (at `mlog.Level.ERROR` or `mlog.Level.FATAL`) before any further processing or a graceful exit. This ensures that a complete record of the error is always preserved.

---

## Error and Log Taxonomy

To ensure that the framework's behavior is predictable and debuggable, we use a standardized taxonomy for all custom errors and significant log messages.

### Naming Convention

All custom error and log identifiers thrown or logged by the framework must follow a three-part convention:

**`pipeline:<ComponentName>:<Identifier>`**

* **`pipeline:`:** A consistent prefix for all framework-generated outputs.
* **`<ComponentName>`:** The CamelCase name of the internal component where the error or log originates (e.g., `StorageManager`, `Resolver`).
* **`<Identifier>`:** A concise, CamelCase name for the specific error or log event (e.g., `OverwriteAttempt`, `JobComplete`).

### Taxonomy of `StorageManager` Outputs

This section details all defined errors and log messages originating from the `pipeline:StorageManager` component.

#### **Errors**

Errors are thrown for unrecoverable situations or violations of the framework's architectural contract.

| Error ID | Description & Trigger |
| :--- | :--- |
| `pipeline:StorageManager:FileLocked` | **Fatal.** Thrown by the constructor if it detects a `.lock` file already exists for the target HDF5 cache. This prevents two pipeline instances from corrupting the same cache file. |
| `pipeline:StorageManager:LockCreationFailed` | **Fatal.** Thrown by the constructor if it fails to create the `.lock` file, likely due to file system permission issues. |
| `pipeline:StorageManager:OverwriteAttempt` | **Fatal.** Thrown by the `persist` method if it is asked to save data to a hash that already exists in the L2 persistent (HDF5) cache. This enforces the immutability contract and signals a critical bug. |
| `pipeline:StorageManager:DataNotInL1Cache` | **Fatal.** Thrown by the `persist` method if it is called for a hash that does not first exist in the L1 in-memory cache. This enforces the correct internal workflow. |
| `pipeline:StorageManager:DataNotFound` | **Informational.** Thrown by the `load` method when a requested hash is not found in either the L1 or L2 cache. This is the expected "cache miss" signal for the Orchestrator. |
| `pipeline:StorageManager:L2SaveError` | **Fatal.** Thrown by the `persist` method if a low-level error occurs during the HDF5 write operation (e.g., disk full, file corruption). |
| `pipeline:StorageManager:L2LoadError` | **Fatal.** Thrown by the `load` method if a low-level error occurs during the HDF5 read operation (e.g., file corruption). |

#### **Logs**

Log messages provide visibility into the `StorageManager`'s internal operations.

| Log ID | Level | Description & Trigger |
| :--- | :--- | :--- |
| `pipeline:StorageManager:LockAcquired` | `DEBUG` | Logged by the constructor upon successfully creating the `.lock` file. |
| `pipeline:StorageManager:LockReleased` | `DEBUG` | Logged by the destructor upon successfully deleting the `.lock` file at the end of a run. |
| `pipeline:StorageManager:L1CacheHit` | `DEBUG` | Logged by the `load` method when it successfully finds and returns data directly from the L1 in-memory cache. |
| `pipeline:StorageManager:L2CacheHit` | `DEBUG` | Logged by the `load` method when it finds data in the L2 persistent cache. This message is logged *before* the data is promoted to L1. |
| `pipeline:StorageManager:DataCachedToL1` | `DEBUG` | Logged by the `cache` method every time a new result is successfully added to the L1 in-memory cache. |
| `pipeline:StorageManager:DataPersistedToL2`| `DEBUG` | Logged by the `persist` method upon successfully writing a data product from the L1 cache to the L2 persistent HDF5 file. |
| `pipeline:StorageManager:LockCleanupWarning`| `WARN` | A warning logged by the destructor if it fails to delete the `.lock` file. This is not a fatal error but requires user attention. |
