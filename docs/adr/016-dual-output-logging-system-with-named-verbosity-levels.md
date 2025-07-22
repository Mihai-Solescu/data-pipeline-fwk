# ADR-016: Dual-Output Logging System with Named Verbosity Levels

**Status:** Accepted
**Date:** 2025-07-22

## Context

A long-running, non-interactive scientific pipeline can be opaque and frustrating for a user. To ensure a good user experience and aid in debugging, the framework must provide clear, configurable feedback about its progress, status, and any errors that occur.

## Decision

We will implement a flexible, dual-output logging system.

1. **Dual Output:** The logger will be capable of writing to both the MATLAB Command Window (for immediate feedback) and a persistent log file (for post-mortem analysis). The log file is optional and will only be used if a path is provided in `config.logging.filepath`.

2. **Named Verbosity Levels:** The system will support three named levels to control the amount of detail:
    * `'info'` (Default): High-level progress updates.
    * `'debug'`: Verbose, developer-focused output.
    * `'silent'`: Suppresses all non-critical output.

3. **Granular Configuration:** The verbosity level will be configurable independently for the console and the log file via `config.logging.console_level` and `config.logging.file_level`. This allows a user to have a clean console view while capturing detailed debug information in the log file.

## Consequences

* **Pros:**
  * **Excellent User Experience ✅:** Provides both immediate feedback and a persistent record, serving the needs of both interactive use and long-term debugging.
  * **High Flexibility:** The granular configuration gives users precise control over the information they see.
  * **Standard Practice:** This model aligns with best practices from established logging frameworks in other languages.

* **Cons:**
  * **Minor Framework Complexity:** The logging component must manage two separate output streams and verbosity levels, adding a small amount of internal complexity.
  * **Slightly More Verbose Configuration:** The user must manage a few extra fields in their configuration file.
