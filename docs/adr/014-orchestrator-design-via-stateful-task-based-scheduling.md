# ADR-014: Orchestrator Design via Stateful Task-Based Scheduling

**Status:** Accepted
**Date:** 2025-07-22

## Context

The Pipeline Orchestrator is the heart of the framework, responsible for running a complex computational graph with maximum efficiency. The chosen architecture must robustly handle non-linear dependencies (e.g., branches, fan-in nodes, global barriers) and effectively utilize modern multi-core hardware through parallelism. The elegance of the solution will be judged by its ability to maximize computational throughput, even if it requires higher implementation complexity.

## Decision

We will implement the Pipeline Orchestrator as a **Stateful, Task-Based Scheduler**.

The Orchestrator will operate as a state machine. At startup, it will build a complete **Job Registry** of every task (`(stage, run)`) required for the experiment. Each job in this registry will track its dependencies and its current status (`WAITING`, `READY`, `RUNNING`, or `COMPLETE`).

The Orchestrator's main loop will continuously monitor this registry, submitting any job whose status is `READY` to a parallel worker pool for asynchronous execution. When a worker completes a job, it reports back to the Orchestrator, which then updates the status of all dependent jobs, potentially changing them to `READY` and adding them to the execution queue.

## Alternatives Considered

### 1. Wave-Based Scheduler

This simpler alternative involves performing a topological sort to group the DAG into "layers." The Orchestrator would execute all jobs in Layer 0 in parallel, wait for all of them to finish (a hard synchronization barrier), then execute all jobs in Layer 1, and so on.

### 2. Recursive Orchestrator

This pattern involves a main function that recursively calls itself to resolve the dependencies for a given stage. It is elegant for sequential execution but is not well-suited for efficient parallelism.

## Rejection Rationale

The Stateful, Task-Based Scheduler was chosen because it is the only architecture that meets the project's core requirement of maximum computational efficiency.

* **Rejection of Wave-Based Scheduler:** While simple to implement, this model is fundamentally inefficient. It introduces artificial synchronization points that can leave parallel workers idle. For example, if a layer contains one job that takes 60 seconds and nine jobs that take 1 second, the workers that completed the fast jobs must sit idle for 59 seconds, waiting for the entire "wave" to finish before the next layer can begin. This leads to a total runtime dictated by the sum of the slowest tasks in each wave, not the true critical path of the graph.

* **Rejection of Recursive Orchestrator:** This model is elegant for sequential pipelines but is extremely difficult to parallelize effectively. Managing a worker pool within a deep, recursive call stack without introducing deadlocks or significant synchronization overhead would essentially require re-implementing the stateful scheduler in a much more convoluted and less efficient manner.

The chosen **Stateful, Task-Based Scheduler**, despite its higher implementation complexity, is the superior architecture. It achieves maximum parallel efficiency by ensuring that no worker is ever idle as long as there is a runnable job anywhere in the dependency graph. This prioritization of user-facing performance over developer-facing simplicity is a core tenet of the framework's philosophy.

## Consequences

* **Pros:**
  * **Maximum Parallel Efficiency ✅:** Achieves the highest possible computational throughput by dynamically scheduling ready tasks, minimizing idle worker time.
  * **Robust for Any Graph Shape 🔗:** The single, consistent state-machine logic can handle any valid DAG, from simple linear pipelines to complex graphs with multiple independent branches and global barriers.

* **Cons:**
  * **High Implementation Complexity ❗:** This is the most complex of the alternatives to implement, write, and debug, as it involves managing asynchronous state.
  * **Requires Parallel Computing Toolbox:** This design is fundamentally tied to a parallel execution backend, making the Parallel Computing Toolbox a hard dependency.
