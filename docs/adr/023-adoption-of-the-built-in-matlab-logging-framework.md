# ADR-023: Adoption of the Built-in MATLAB Logging Framework

**Status:** Accepted
**Date:** 2025-07-23

## Context

The framework requires a robust and configurable logging system to provide users with feedback and to aid in debugging. We considered two primary approaches: implementing a custom `Logger` class from scratch or adopting the built-in logging framework provided by MATLAB (`matlab.log`). The chosen solution must be powerful, maintainable, and align with our core principle of providing a MATLAB-native experience.

## Decision

We will exclusively use the built-in **`matlab.log` framework** for all logging.

The implementation will follow a dependency injection pattern:

1. The `Orchestrator` will be responsible for creating and configuring a single, shared logger instance at the beginning of a pipeline run, based on the user's `config.logging` settings.
2. This configured logger instance will be passed to the constructors of all other internal components (e.g., `StorageManager`, `Resolver`) that require logging capabilities.
3. We will adhere to the standard, hierarchical verbosity levels provided by the framework (e.g., `INFO`, `DEBUG`, `WARN`). We will not implement a more complex, per-message filtering system, as the standard levels provide the best balance of control and simplicity.

## Alternatives Considered

### Custom `Logger` Class

We designed a simple, custom `Logger` class that would handle `fprintf` calls to the console and a log file based on custom verbosity levels.

* **Pros:** Simple initial implementation, complete control over the API.
* **Cons:** This approach reinvents a solved problem. It is less extensible, requires more custom code to maintain, and lacks the powerful features (like the `Appender` model) of the built-in solution.

## Rationale for Choosing the Built-in Framework

Adopting the `matlab.log` framework is the superior architectural choice for several compelling reasons:

* **Adherence to the "MATLAB-Native" Philosophy ✅:** Using the official, idiomatic tool provided by MathWorks is the quintessential MATLAB-native approach. It ensures the framework feels professional and integrates seamlessly with the broader MATLAB ecosystem.
* **Superior Extensibility and Separation of Concerns 🔗:** The built-in framework's **`Appender` model** is a more elegant and powerful design. The logger is responsible for creating log records, while separate `Appender` objects are responsible for the destination (console, file, etc.). This makes it trivial to add new logging destinations in the future without changing any core framework code.
* **Reduced Maintenance Burden:** By leveraging a mature, well-tested system from MathWorks, we reduce the amount of custom code we need to write, test, and maintain.
* **Standardization and Clarity:** The use of standard, hierarchical log levels (`INFO`, `DEBUG`, `WARN`) is an industry best practice. It makes the framework's output immediately understandable to other developers and provides a clear, simple model for users to control verbosity.

This decision ensures our logging system is robust, maintainable, and aligned with the high standards of the overall framework architecture.
