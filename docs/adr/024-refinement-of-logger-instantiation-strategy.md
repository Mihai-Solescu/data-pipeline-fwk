# ADR-024: Refinement of Logger Instantiation Strategy

**Status:** Accepted
**Date:** 2025-07-29
**Related ADR:** ADR-023: Adoption of mathworks/advanced-logger

## Context

ADR-023 established the adoption of `mathworks/advanced-logger` as the framework's primary logging solution, emphasizing its MATLAB-native experience, superior developer experience, and reduced maintenance burden. The initial decision in ADR-023 also stipulated that logger instances would be passed via dependency injection (DI) into component constructors.

Upon further consideration of `mathworks/advanced-logger`'s specific implementation details, particularly its use of named singleton instances, a re-evaluation of the logger instantiation strategy is warranted. The question arises whether the benefits of strict constructor-based DI for loggers outweigh the convenience and inherent capabilities of the named singleton pattern provided by the library.

## Decision

We will **rely on the named singleton pattern** provided by `mathworks/advanced-logger` for all logger instances, thereby **explicitly avoiding dependency injection of logger objects** into component constructors. Furthermore, individual components will **not configure their logger instances internally**.

The revised implementation strategy is as follows:

1. The `Orchestrator` (or a dedicated `LoggerFactory` component within the `Orchestrator`'s initialization flow) will be solely responsible for **configuring all named loggers centrally** based on the user's `config.logging` settings. This includes setting global console/file levels, file paths, and any specific overrides for named loggers.
2. Each internal component requiring logging (e.g., `StorageManager`, `Resolver`, `HDF5Backend`) will obtain its specific logger instance by calling `mlog.Logger('ComponentName')` (e.g., `mlog.Logger('pipeline:storage:manager')`) directly within its constructor or relevant method. **Crucially, these components will *only* retrieve the logger and *not* apply any configuration settings to it.**
3. A **hierarchical naming convention** (e.g., `pipeline:orchestrator`, `pipeline:storage:manager`, `pipeline:storage:backend:hdf5`) will be used for logger names to provide clear context in log outputs and enable granular configuration.

## Rationale for Revised Decision

This revision maintains the core benefits of ADR-023 while leveraging the `advanced-logger`'s design more idiomatically:

* **Centralized Configuration (Retained Benefit and Clarified Enforcement):** The `mathworks/advanced-logger` implements named loggers as global singletons. This means that a call to `mlog.Logger('MyComponentName')` will always return the *same* underlying logger instance across the entire MATLAB session. By mandating that configuration *only* happens in a central location (e.g., the `Orchestrator`) and that components *do not* configure their own loggers, we ensure consistent and predictable logging behavior across the application. Any configuration set centrally will persist and apply to the retrieved singleton instance.

* **Reduced "Plumbing" and Simplified Constructors:** By relying on the named singleton lookup, components no longer need to accept a logger instance as a constructor argument. This reduces "constructor bloat," simplifies class signatures, and streamlines the instantiation chains throughout the framework, making the codebase cleaner and potentially easier to read for developers less familiar with strict DI patterns.

* **Granular Control and Contextual Logging (Enhanced):** Using distinct named loggers (e.g., `pipeline:storage:manager`, `pipeline:storage:backend:hdf5`) allows for highly granular control over logging levels for different subsystems. For instance, `pipeline:storage:manager` could be set to `INFO` for general operation, while `pipeline:storage:backend:hdf5` could be temporarily set to `DEBUG` to troubleshoot low-level I/O issues without flooding logs with irrelevant messages from other parts of the system. The logger name automatically provides valuable context in each log message.

* **Acceptable Trade-off for Testability:** While strict constructor-based DI generally improves unit testability by facilitating mocking, the nature of a logging utility (especially an official, stable one like `advanced-logger`) makes this a less critical concern. The primary goal when testing logging is often to verify that a component *attempts* to log a message under certain conditions, rather than mocking the logger's internal behavior. The convenience and centralized configuration benefits of the named singleton pattern outweigh the minor complexities introduced in testing logger interactions directly. For more complex testing scenarios, the `advanced-logger`'s public event mechanism could potentially be leveraged.

This refined approach aligns with the framework's pragmatic design philosophy by embracing the idiomatic usage of a key third-party dependency while still achieving the desired architectural goals for logging.
