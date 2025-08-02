# Implementation and Testing Strategy for the Storage System

The storage system should be implemented using a **bottom-up approach**. You start with the most fundamental components (the interfaces and concrete backends) and build up to the higher-level abstractions (the manager and decorators). This ensures that each layer rests on a solid, tested foundation.

---

## Step 1: Define the `IStorageBackend` Interface

This is the contract that all storage components must follow.

* **How to Implement:**
  * Create an abstract class `IStorageBackend` that defines the method signatures without any implementation.

    ```matlab
    classdef (Abstract) IStorageBackend < handle
        methods (Abstract)
            write(obj, key, data);
            data = read(obj, key);
            flag = exists(obj, key);
            delete(obj, key);
        end
    end
    ```

* **How to Ensure Correctness:** This is a contract, so correctness is defined by the components that implement it.
* **How to Test:** You cannot test an interface directly. Its purpose is to enforce consistency in other classes.

---

## Step 2: Implement the L2 `HDF5Backend`

This is the first concrete component, handling persistent storage.

* **How to Implement:**
  * Create a class `HDF5Backend` that inherits from `IStorageBackend`.
  * Implement the four required methods using MATLAB's HDF5 functions (`h5create`, `h5write`, `h5read`, etc.). Store each `key` as a group within the HDF5 file.
  * **Crucially**, implement the file-locking mechanism. The constructor should create a `.lock` file, and the destructor (`delete` method) must remove it inside a `try/catch` block to ensure it's always cleaned up.
* **How to Ensure Correctness:**
  * Wrap all file I/O operations in `try/catch` blocks to handle low-level errors gracefully (e.g., disk full, permissions error).
  * Ensure the `.lock` file is *always* removed, even if the pipeline errors out. This is the most critical part for preventing hung states.
* **How to Test:**
  * Write a unit test class (`TestHDF5Backend`).
  * **Happy Path:** Test the full CRUD cycle: `write` a key, `exists` should return true, `read` should return the correct data, `delete` the key, `exists` should now return false.
  * **Edge Cases:**
    * Test reading a non-existent key (should throw a specific error).
    * Test writing to a key that already exists (should throw an "overwrite attempt" error).
    * Test the file lock: verify the `.lock` file is created on construction and deleted on destruction.

---

## Step 3: Implement the L1 `InMemoryBackend`

This is the simpler, in-memory cache.

* **How to Implement:**
  * Create a class `InMemoryBackend` that inherits from `IStorageBackend`.
  * Use a `containers.Map` as the internal data store.
  * The interface methods (`write`, `read`, `exists`, `delete`) become simple one-line calls to the map's methods (`obj.Map(key) = data`, `obj.Map(key)`, `isKey`, `remove`).
* **How to Ensure Correctness:** `containers.Map` is a robust built-in, so the main concern is correctly mapping the interface methods.
* **How to Test:**
  * Write a unit test class (`TestInMemoryBackend`).
  * Test the same CRUD cycle as the `HDF5Backend`.
  * Verify its volatility: create an instance, write data to it, then create a *new* instance and confirm the data is gone.

---

## Step 4: Implement the `StorageManager`

This component orchestrates the L1 and L2 backends.

* **How to Implement:**
  * Create the `StorageManager` class. Its constructor will accept two objects that implement `IStorageBackend` (one for L1, one for L2).
  * Implement the public API (`load`, `cache`, `persist`) precisely according to the logic in the ADD. For example, `load` checks L1, then L2, then promotes to L1.
* **How to Ensure Correctness:** The logic must be flawless. Meticulously trace the data flow for each method to ensure it matches the specification.
* **How to Test:**
  * This requires **mocking**. You cannot test the `StorageManager`'s logic without having full control over its dependencies (the L1 and L2 backends).
  * In your test class (`TestStorageManager`), create mock `IStorageBackend` objects (using MATLAB's Mocking Framework or a simple custom class).
  * **Test `load`:**
    * **L1 Hit:** Configure the L1 mock to have the key. Verify `load` returns the data and that the L2 mock was *never* called.
    * **L1 Miss / L2 Hit:** Configure L1 to be empty and L2 to have the key. Verify `load` returns the correct data, that the L2 mock's `read` was called once, and that the L1 mock's `write` was called once (for promotion).
    * **Full Miss:** Configure both mocks to be empty. Verify `load` throws a `DataNotFound` error.
  * **Test `persist`:** Configure the L1 mock to have data. Call `persist`. Verify that the L1 mock's `read` was called and the L2 mock's `write` was called with the correct data.

---

## Step 5: Implement the `ConcurrentStorageDecorator`

This is the final layer that adds thread safety.

* **How to Implement:**
  * Create the `ConcurrentStorageDecorator` class that also inherits from `IStorageBackend`.
  * Its constructor takes another `IStorageBackend` object to "wrap".
  * It should have an internal property for a lock object.
  * Implement each interface method (`write`, `read`, `exists`, `delete`) by wrapping the call to the underlying backend in a `lock`/`unlock` sequence, using a `try/finally` block to guarantee the lock is always released.
  * For the `read` method (or whichever method corresponds to the `StorageManager`'s `load`), implement the **double-checked locking** pattern precisely as discussed.
* **How to Ensure Correctness:** The `try/finally` pattern for lock release is non-negotiable. A failure to release a lock will deadlock the entire application.
* **How to Test:**
  * This is the most complex testing phase and requires the Parallel Computing Toolbox.
  * **Write Contention Test:** In a `parfor` loop, have many workers try to `write` to the *exact same key*. The test passes if it completes without error and the final value in the storage is one of the written values (i.e., no file corruption).
  * **Double-Checked Lock Test:**
        1. Set up a test where a key exists only in a mock L2 backend.
        2. Use a counter (e.g., a `parallel.pool.DataQueue`) to track how many times the L2 `read` method is called.
        3. In a `parfor` loop, have many workers try to `load` that same key through the concurrent `StorageManager`.
        4. The test passes if the final count of L2 reads is **exactly 1**. This proves that only the first thread did the expensive work and all others got the promoted result from the L1 cache.
