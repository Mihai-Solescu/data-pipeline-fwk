# ADR-006: Task-Based Parallelism via Worker Pool

**Status:** Accepted
**Date:** 2025-07-19

## Context

While a simple parallel loop over parameter runs can offer a speedup, it is inefficient for complex pipelines containing global barriers. Such a loop would force all parallel workers to synchronize and wait at a barrier, even if independent tasks from earlier stages could still be processed. To maximize hardware utilization, a more dynamic, task-based approach to parallelism is required.

## Decision

The framework will implement a **task-based scheduling model** using a **worker pool** from MATLAB's Parallel Computing Toolbox.

The Pipeline Executor will operate like a task scheduler. It will first perform a topological sort of the stage graph to understand the overall dependency structure, including global barriers. It will then generate a list of all individual computational jobs (e.g., `(stage_B, run_5)`).

As the pipeline runs, the scheduler will submit any job whose dependencies have been met to the worker pool for asynchronous execution. When a worker completes a job, the scheduler will update the dependency status of downstream jobs, potentially unlocking new jobs to be added to the queue. This allows independent jobs from different stages and different runs to execute concurrently.

## Consequences

* **Pros:**
  * **Highly Efficient Resource Utilization 🚀:** This model keeps the CPU worker pool maximally busy by dynamically scheduling any available independent task. It can continue processing early-stage jobs for some runs while other runs are waiting for a global barrier to be met, leading to greater overall efficiency.
  * **Handles Complex DAGs Gracefully 🔗:** A task-based model is inherently better suited for complex pipelines with multiple independent branches and synchronization points than a simple parallel loop structure.
  * **Leverages Mature Technology ✅:** The implementation will be built on top of the robust features of the Parallel Computing Toolbox (e.g., `parpool`, `parfeval`), avoiding the need to create a low-level threading system.

* **Cons:**
  * **Significant Executor Complexity ❗:** The orchestrator is no longer a simple loop but a stateful scheduler. It must manage a dynamic job queue, track the dependency status of hundreds or thousands of tasks, and handle asynchronous results. This represents a substantial increase in the framework's internal complexity.
  * **Requires Parallel Computing Toolbox:** This feature remains dependent on a licensed MathWorks toolbox. The framework must verify its availability before attempting parallel execution.
  * **Debugging Challenges:** Debugging a dynamic, asynchronous system is significantly more difficult than debugging a sequential one. Identifying the root cause of errors or performance bottlenecks may require more advanced techniques.
