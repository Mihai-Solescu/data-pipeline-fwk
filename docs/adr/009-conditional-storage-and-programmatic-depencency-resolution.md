# ADR-009: Conditional Storage and Programmatic Dependency Resolution

**Status:** Accepted
**Date:** 2025-07-22

## Context

A simple dependency model where a stage always uses the output from the same run of its prerequisite is insufficient for advanced scientific workflows. To enable critical optimizations, such as computing a high-fidelity SVD only once and reusing it for multiple lower-fidelity models, the framework needs a more sophisticated system. This system must allow users to define rules for both conditionally storing results and intelligently retrieving them, all while keeping the core scientific code free of this optimization logic.

## Decision

We will implement a two-part system for advanced storage optimization:

1. **Expanded Storage Policies with conditional storage:** The `.storage_policy` field for a stage's output will support three options:
    * `'persistent'`: (Default) The output is always saved to the persistent HDF5 store.
    * `'memory_only'`: The output is only kept in memory for the duration of the pipeline run.
    * **Function Handle:** A handle to a boolean function (e.g., `@(p, all) ...`). This provides maximum flexibility, allowing the user to define precise, state-aware rules for when an output is valuable enough to be persisted.

2. **Programmatic Dependency Recipes:** To retrieve data (especially conditionally stored data), we will replace string-based URIs with a programmatic, fluent interface. This "recipe" will define how to find and prepare an input for a consuming stage.

### Dependency Recipe Syntax

We considered two primary syntaxes for the dependency recipe:

* **Alternative 1: Name-Value Pair Function.** A single function call with key-value arguments (e.g., `define_dependency('source', '...', 'where', @...)`). This pattern is idiomatic in classic MATLAB.
* **Alternative 2: Fluent Object-Oriented Interface.** A chain of method calls that builds the request step-by-step.

We have chosen to adopt the **Fluent Interface**. The syntax will look like this:

```matlab
% In the consumer stage's config
dependency.svd_input = ...
    resolver.get('compute_svd', {'U', 'S', 'V'}) ...
            .where('rank', @(all_ranks) max(all_ranks)) ...
            .transform(@(data, params) ...);
```

This recipe will be interpreted by the framework's Resolver component to find the correct data hash, load the data, and apply any necessary transformations before passing it to the scientific function.

## Consequences

* **Pros:**

  * **Maximum Flexibility and Power ✅:** The combination of a function handle for storage and a fluent recipe for retrieval provides a complete, expressive system for defining complex, cross-run optimizations.

  * **Elegant and Self-Documenting Syntax 📖:** The chosen fluent interface reads like a sentence, making the user's intent clear and easy to understand. This improves the maintainability of the configuration and lowers the learning curve for new users compared to an arbitrary mini-language.

  * **Perfect Separation of Concerns 🔗:** This architecture cleanly separates the four key logics:

    1. **Storage Logic:** Lives in the storage_policy of the source stage.

    2. **Retrieval Logic:** Lives in the `.where()` clause of the dependency recipe.

    3. **Transformation Logic:** Lives in the `.transform()` clause of the dependency recipe.

    4. **Scientific Logic:** Lives, pure and untouched, in the final component function.

  * **Highly Extensible:** The recipe object can be easily extended with new methods (e.g., `.groupBy()`, `.orderBy()`) in the future to support even more advanced optimizations without breaking the existing API.

* **Cons:**

  * **Increased Framework Complexity ❗:** The Resolver engine becomes a more complex component, as it must interpret and execute these recipe objects.
  * **New API to Learn:** Users must learn the methods available on the recipe builder object (`.get`, `.where`, `.transform` etc.). This is a small, but non-zero, learning curve.
