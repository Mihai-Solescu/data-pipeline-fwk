# ADR-010: Dependency Resolution via URI Strings

**Status:** Rejected
**Date:** 2025-07-22

**Note:** This approach was superseded by the programmatic "fluent interface" chosen in **ADR-009**.

## Context

The framework requires a mechanism to handle complex, cross-run dependencies and subsequent data transformations (e.g., retrieving a high-rank SVD and then truncating it). The mechanism must clearly separate the logic for *retrieving* data from the logic for *transforming* it post-retrieval.

## Rejected Proposal 1

This proposal was to define each dependency as a single, comprehensive URI string.

* The **retrieval logic** would be encoded in the **query string** (after `?`).
* The **transformation logic** would be encoded in the **fragment identifier** (after `#`).

1. **Dependency URIs:** Stage dependencies will be declared using a URI-like string format (e.g., `scheme://source/product?query#transformation`). This is an extensible grammar that can express both simple same-run dependencies and complex, policy-based lookups (e.g., `'havok://compute_svd/U?policy=max&by=rank'`).
2. **Resolver Engine:** The Pipeline Executor will include a resolver engine responsible for parsing these URIs. For policy-based URIs, the engine will query the storage index to find the appropriate data hash that satisfies the policy.

**Example:**
`'havok://compute_svd/U?policy=max&by=rank#transform=@utils.truncate_svd'`

The framework's Resolver would parse this string, first using the query part to find and load the source data, and then using the fragment part to apply the specified transformation before passing the final result to the consuming stage.

### Rejection Rationale of proposal 1

While this URI scheme is functionally capable, it was rejected because a programmatic, object-oriented approach (ADR-009) was deemed superior in elegance, safety, and usability. The key reasons for this rejection are:

1. **Introduces a Non-Native "Mini-Language" ❗:** The URI format is an arbitrary grammar that is foreign to MATLAB's syntax. This forces users to learn and manually type complex "magic strings," which are highly prone to typos that can only be detected at runtime.

2. **Lacks Type Safety and Editor Support:** A plain string gets no help from the MATLAB editor. In contrast, the chosen object-oriented approach (`resolver.get().where()...`) provides:
    * **Auto-completion:** Users can discover available methods (`.where`, `.transform`) as they type.
    * **Immediate Error Checking:** Syntax errors or typos in method names are caught instantly by the editor, rather than causing cryptic parser failures during a pipeline run.

3. **Poor Readability:** As more logic is added, the URI strings become exceedingly long, dense, and difficult to read. The programmatic alternative, with its chained methods and indentation, remains far more organized and self-documenting.

4. **Disconnected Logic:** This approach scatters the definition of an optimization across multiple syntaxes: a function handle for the `storage_policy`, a query string for retrieval, and a fragment string for transformation. This makes the overall pattern difficult to follow and prone to logical mismatches. The chosen solution unifies retrieval and transformation into a single, coherent recipe.

## Rejection Proposal 2

This proposal was to use a declarative struct on the source stage to define a common optimization pattern. This struct would contain fields like `'type'`, `'group_by'`, and `'select_by'` to describe the desired optimization, such as selecting the maximum value of one parameter within a group defined by several others.

**Example:**

```matlab
% On the 'compute_svd' stage
config.stages(4).optimization_policy = struct(...
    'type',      'select_max', ...
    'group_by',  {{'ts_len', 'idx_del', ...}}, ...
    'select_by', 'truncation_rank' ...
);
```

### Rejection Rationale of proposal 2

While functional, both alternatives were rejected because a programmatic, object-oriented approach (ADR-009) was deemed superior in elegance, safety, and usability. The key reasons for this rejection are:

1. **Limited Flexibility:** The static `optimization_policy` struct is not extensible. It can only support a predefined list of policy types and does not allow users to define arbitrary custom logic, unlike the function handles used in the chosen solution.
