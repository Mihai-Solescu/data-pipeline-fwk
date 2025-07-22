# ADR-007: Separation of Stage Definition from Implementation

**Status:** Accepted
**Date:** 2025-07-20

## Context

The framework requires a standard method for defining computational stages. One approach is to use a single, monolithic structure that encapsulates both a stage's configuration and its computational logic. An alternative is to decouple these concerns, where the definition of a stage's role within the pipeline is defined separately from the code that performs the actual computation. The chosen design must prioritize modularity, reusability, and ease of use for scientists.

## Decision

We will adopt an architecture where a stage's configuration is fully separated from its computational logic. The pipeline configuration will define a stage's metadata (its dependencies, its products, its role in the graph), and will separately link to a self-contained, reusable component that executes the stage's logic.

## Consequences

This decision to decouple configuration from logic has several key implications:

* **Pros:**
  * **Separation of Concerns**: This design allows a scientist to focus entirely on the computational code, while the pipeline's structure and optimizations can be managed independently in the configuration. This separation of roles simplifies both scientific development and pipeline management.
  * **Lower Learning Curve**: Users are not required to learn a specific object-oriented paradigm or class inheritance structure to add a new computational stage. They can contribute by providing standard, self-contained functions, which aligns with common scientific programming practices.
  * **Enhanced Reusability**: By keeping the computational logic independent of any specific pipeline structure, the resulting components are inherently more reusable. They can be tested individually, used in other scripts, or easily integrated into different workflows.
  * **Simplified Reproducibility**: Guaranteeing the integrity of a self-contained code component for reproducibility checks (e.g., via hashing) is more direct and unambiguous than it would be for logic embedded within a larger, more complex structure.

* **Cons:**
  * **Weaker Interface Contract**: The link between a stage's declared metadata (e.g., its expected inputs and outputs) and the actual implementation relies on convention rather than a strictly enforced interface. This may lead to runtime errors if the implementation does not match its declaration.
  * **Reduced Encapsulation**: To fully understand a single stage, a developer may need to consult two separate locations: the pipeline configuration for its role in the graph and the component file for its internal logic.
