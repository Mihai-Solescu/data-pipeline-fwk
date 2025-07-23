# A General-Purpose Scientific Pipeline Framework for MATLAB

[![License](https://img.shields.io/badge/License-Apache_2.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)
[![Status: In Development](https://img.shields.io/badge/status-in_development-orange.svg)](./docs/ROADMAP.md)

A modular, reproducible, and efficient MATLAB framework for executing complex, multi-stage scientific computing workflows. This framework acts as a "build system" for data analysis, designed to accelerate research by automating parameter sweeps, guaranteeing reproducibility, and eliminating redundant computations through intelligent, provenance-based caching.

For a deep dive into the project's requirements, architecture, and design decisions, please see the full documentation in the `/docs/` directory.

---

## Vision and Philosophy

This framework is built on a simple premise: scientific computing in MATLAB should be both powerful and elegant. Our philosophy is guided by five core principles:

1. **A MATLAB-Native Experience:** The framework feels like a natural extension of MATLAB, not a foreign tool. All configuration uses idiomatic MATLAB syntax.
2. **Uncompromising Reproducibility:** Every result is cryptographically tied to its full origin—the code, parameters, and data that produced it.
3. **Declarative Configuration as Code:** You define *what* your workflow should do in a clean, version-controllable file. The framework handles the *how*.
4. **Aggressive Separation of Concerns:** Your scientific code remains pure. All the complex logic for caching, parallelism, and optimization lives in the configuration.
5. **Flexible and Composable Data Flow:** This is more than a linear pipeline. It's a toolkit for building complex computational graphs to model sophisticated research workflows.

## What Makes This Framework Different?

While many workflow tools exist, this framework is purpose-built to address the specific needs of scientific research within the MATLAB environment.

* **It's Not Just a Scheduler:** Unlike generic task runners, this framework is deeply aware of the scientific process. Its advanced dependency resolution and provenance-based hashing are designed to handle common research patterns like parameter sweeps and multi-scale modeling natively.
* **It Embraces MATLAB, It Doesn't Fight It:** Other powerful tools like DVC or Snakemake are command-line driven, which can break the interactive workflow that makes MATLAB great. This framework is designed to be called directly from your scripts and functions, integrating seamlessly into your existing process.
* **Optimization is a First-Class Citizen:** The ability to define complex, cross-run data sharing and transformation logic (e.g., "use the SVD from the run with the highest rank, then truncate it") is not an afterthought—it's a core feature of the dependency system.

## Core Features

* **Provenance-Based Caching:** Never re-run a computation unless its code, parameters, or inputs have actually changed.
* **Complex DAG Support:** Natively model non-linear workflows with branches, merges, and global barriers.
* **Advanced Dependency Resolution:** A powerful, programmatic API for defining complex, cross-run data retrieval and transformation logic.
* **Parallel Execution:** A stateful, task-based scheduler maximizes the use of multi-core hardware.
* **Seamless Git Integration:** The caching system is inherently version-aware. Switch Git branches, and the framework automatically uses the correct cached data for that version of your code.

## A Glimpse of the API

The entire workflow is controlled by a simple configuration and a single command.

**1. Define your workflow in `my_pipeline_config.m`:**

```matlab
function config = my_pipeline_config()
    % Define parameters...
    config.parameters.rank = [10, 20, 50];

    % Define stages and their dependencies...
    config.stages(1).name = 'compute_svd';
    config.stages(1).function = @processing.compute_svd;
    
    config.stages(2).name = 'build_model';
    config.stages(2).function = @models.build_model;
    config.stages(2).dependencies.svd_data = ...
        pipeline.get('compute_svd', {'U', 'S', 'V'}) ...
                .where('rank', @max) ...
                .transform(@(data, params) ...); % Truncation logic
end
```

**2. Run it from your main script:**

```matlab
% In main_runner.m
config = my_pipeline_config();
results = pipeline.run(config);
```

## Documentation

For the complete design and usage guide, please see the documents in the `/docs/` directory:

* **`SRS.md`:** The Software Requirements Specification (The **What**).
* **`ADD.md`:** The Architecture Design Document (The **How**).
* **`/docs/adr/`:** The Architectural Decision Record Log (The **Why**).

## Roadmap & Contributing

This project is currently in active development. You can view our implementation plan in the [ROADMAP.md](./ROADMAP.md) file. Contributions and suggestions are welcome.
