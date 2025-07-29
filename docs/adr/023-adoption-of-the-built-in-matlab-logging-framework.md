# ADR-023: Adoption of mathworks/advanced-logger

**Status:** Accepted
**Date:** 2025-07-29

## Context

The framework requires a robust and configurable logging system to provide users with feedback and to aid in debugging. We considered three primary approaches: a custom `Logger` class, the built-in `matlab.log` framework, and the `mathworks/advanced-logger` available on File Exchange. The chosen solution must be powerful, maintainable, and align with our core principle of providing a MATLAB-native experience.

## Decision

We will exclusively use the **`mathworks/advanced-logger`** framework for all logging.

The implementation will follow a dependency injection pattern:

1. The `Orchestrator` will be responsible for creating and configuring a single, shared logger instance at the beginning of a pipeline run, based on the user's `config.logging` settings. This is simplified by the higher-level API of `advanced-logger`.
2. This configured logger instance will be passed to the constructors of all other internal components (e.g., `StorageManager`, `Resolver`) that require logging capabilities.
3. We will adhere to the standard, hierarchical verbosity levels provided by the framework (e.g., `INFO`, `DEBUG`, `WARN`).

## Rationale for Choosing `mathworks/advanced-logger`

Adopting `mathworks/advanced-logger` is the superior architectural choice for several compelling reasons:

* **Adherence to the "MATLAB-Native" Philosophy ✅:** While not built-in, this framework is developed and maintained by MathWorks. Adopting it means we are using the officially-endorsed, best-practice solution for advanced logging needs, ensuring a professional and integrated feel.
* **Superior Developer Experience & Simplicity 🔗:** The `advanced-logger` provides a cleaner, higher-level API that simplifies common logging patterns. Setting up complex configurations (like dual file/console output) is often a single, clear command, reducing boilerplate code in our `Orchestrator`.
* **Reduced Maintenance Burden:** By leveraging a mature, well-tested system from MathWorks that is built on top of the core `matlab.log` engine, we get the best of both worlds: a convenient API and a stable foundation, all while reducing the amount of custom configuration code we need to maintain.
* **Standardization and Clarity:** The framework uses the same standard log levels (`INFO`, `DEBUG`, `WARN`) as the built-in system, making the framework's output immediately understandable to other developers.

This decision ensures our logging system is robust and maintainable, and that it utilizes the most modern and officially recommended tooling from MathWorks.
