# About Our Documentation System

This directory, `/docs/`, contains the living documentation for the scientific pipeline framework. It is organized according to a "three-way split" to ensure clarity and maintainability.

## The Three-Way Split

Our documentation is divided into three categories, each answering a fundamental question:

1. **The "What" 📄 (Software Requirements Specification - SRS)**
    * **Purpose:** Describes what the system must do from a user's perspective. It includes the vision, scope, use cases, and functional requirements.
    * **Location:** `SRS.md`

2. **The "How" 🏗️ (Architecture Design Document - ADD)**
    * **Purpose:** The technical blueprint describing how the system is built. It covers architecture, data models, key algorithms, and component interfaces.
    * **Location:** `ADD.md`

3. **The "Why" ✍️ (Architectural Decision Record Log)**
    * **Purpose:** The folder `/adr/` contains a chronological log explaining why key architectural decisions were made. It serves as the project's design journal.
    * **Location:** `docs/adr/`.

## What is an ADR?

An **Architectural Decision Record (ADR)** is a short text file that captures a single important architectural decision. Each ADR describes the context of the problem, the decision made, and the consequences of that decision. This creates a clear historical record that is invaluable for understanding the evolution of the project.
