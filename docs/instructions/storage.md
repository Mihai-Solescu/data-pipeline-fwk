# Storage Component Implementation Instructions

This document provides detailed guidance for implementing the storage subsystem of the pipeline framework. Follow the architectural design in the ADD and use strict test-driven development (TDD) practices. All code must be accompanied by comprehensive, class-based unit tests.

## 1. Overview

The storage subsystem consists of:

- `StorageManager`: Handles L1 (in-memory) cache and delegates to L2 (persistent) backend.
- `StorageBackend` (interface): Abstracts persistent storage operations.
- `HDF5Backend`: Implements `StorageBackend` for HDF5 files.
- Storage policies and error handling.

**File Organization:**
All storage component files should be placed under the `+pipeline/+storage/` directory for modularity and clarity:

- `+pipeline/+storage/StorageManager.m`
- `+pipeline/+storage/StorageBackend.m`
- `+pipeline/+storage/HDF5Backend.m`

This keeps the storage subsystem organized as its own package within the framework.

## 2. Implementation Steps

### 2.1. StorageBackend Interface

- Define an abstract class with methods:
  - `save(key, data)`
  - `load(key)`
  - `exists(key)`
  - `delete(key)`
- Write tests to ensure any implementation throws errors for missing keys and handles all method contracts.

### 2.2. HDF5Backend Implementation

- Implement all interface methods using MATLAB's HDF5 functions.
- Write tests for:
  - Saving and loading data
  - Checking existence
  - Deleting data
  - Handling file I/O errors

### 2.3. StorageManager Class

- Properties:
  - `L1_Cache` (containers.Map)
  - `L2_Backend` (StorageBackend)
- Methods:
  - `cache(key, data)`: Store in L1 only
  - `persist(key)`: Move from L1 to L2
  - `load(key)`: Try L1, then L2, promote to L1
- Write tests for:
  - L1 cache hit/miss
  - L2 fallback and promotion
  - Data consistency between caches
  - Error handling for missing data

### 2.4. File Locking

- Implement `.lock` file mechanism in `StorageManager` constructor/destructor.
- Write tests to:
  - Prevent concurrent access
  - Clean up lock files on exit/error
  - Throw specific errors when locked

### 2.5. Provenance-Based Indexing

- Ensure all keys are provenance hashes as described in the ADD.
- Write tests to verify correct hash calculation and indexing.

### 2.6. Storage Policies

- Implement support for `persistent`, `memory_only`, and function-handle policies.
- Write tests for each policy, ensuring correct persistence and memory behavior.

### 2.7. Error Handling and Logging

- Define and document all error types (e.g., `FileLocked`, `OverwriteAttempt`, `DataNotFound`).
- Integrate logging for all key events (cache hits, persistence, errors).
- Use the `advanced-logger` package (see `vendor/advanced-logger`) as the single logger for this project. Do not use a mock logger; all logging should go through advanced-logger.
- Write tests to trigger and verify each error and log output.

### 2.8. Garbage Collection (DO NOT IMPLEMENT THIS NOW)

- Implement `pipeline.gc(config)` using mark-and-sweep.
- Write tests to:
  - Mark live hashes
  - Sweep and delete unreachable data
  - Verify correct data retention and deletion

## 3. Test-Driven Development (TDD) Instructions

- Write all tests before implementing functionality.
- Use MATLAB's class-based unit testing framework.
- Each method and feature must have:
  - Positive tests (expected behavior)
  - Negative tests (error cases)
  - Edge case tests (boundary conditions)
- Use temporary files and mock objects to isolate tests.
- Ensure tests are independent and repeatable.

## 4. Documentation

- Document all public methods and error types.
- Update `CONTRIBUTING.md` with error taxonomy and logging conventions.

## 5. References

- See ADD Section 3.4 for architecture and API details.
- See ROADMAP Phase 2 for implementation and testing tasks.

- Refer to the PlantUML diagram in `docs/diagrams/storage.puml` for component relationships.
- Storage component source files are located in `+pipeline/+storage/`.

---

Follow these instructions strictly to ensure a robust, maintainable, and fully tested storage subsystem for the pipeline framework.
