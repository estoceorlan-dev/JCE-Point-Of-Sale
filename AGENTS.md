# AGENTS.md

# JCE POS Development Rules & AI Agent Instructions

This document defines the development standards, architecture, and coding rules for JCE POS.

All contributors, developers, and AI agents must follow these guidelines.

---

# Core Principles

## 1. Scalability First

Every feature must be designed assuming:

* Multiple branches
* Multiple users
* Thousands of products
* Hundreds of daily transactions
* Future feature expansion

Never hardcode:

* Branch IDs
* User roles
* Product categories
* API endpoints

All values must be configurable.

---

## 2. Offline-First Architecture

The application must function even without internet access.

### Source of Truth

#### Server reachable (local network or internet)

PostgreSQL, accessed through the standalone Node.js API in `jce_backend`.

Local production uses one branch server over Wi-Fi/Ethernet without requiring
internet. Hosted production uses Render Web Service and Render Postgres. Each
deployment has one authoritative database; do not automatically fail over or
replicate between independent local and cloud databases.

#### Offline

SQLite

Workflow:

```text
User Action
    ↓
SQLite Save
    ↓
Sync Queue
    ↓
PostgreSQL
```

No feature should depend solely on an active internet connection.

The Flutter client must not connect directly to PostgreSQL or contain database
credentials. Retain SQLite-first writes and the dedicated synchronization queue.

## Backend migration status

The accepted migration plan is
`jce_backend/docs/architecture_refactor_plan.md`. Phase 0 establishes checkpoints,
ownership, inventory, and release contracts; it does not migrate runtime behavior.
Phases 3-4 select the Node runtime by default and preserve explicit Firebase
rollback adapters. Physical device acceptance remains pending; retain production
platform gates and defer Firebase retirement to Phase 7. Do not remove platform gates or authorize new
production deployments merely because a planning phase is complete.

Target clients are Windows and Android POS, with web administration. Offline
cashier sign-in uses prior per-device PIN enrollment and expiring authorization.
Product images are optional: missing images or storage failures must not block
product creation, checkout, or core sync. Local storage and S3-compatible cloud
storage must be replaceable adapters.

---

# Architecture

## Clean Architecture

```text
Feature
│
├── Presentation
├── Domain
└── Data
```

### Presentation

Contains:

* Pages
* Screens
* Widgets
* Controllers

Never:

* Directly call APIs
* Write SQL
* Contain business logic

---

### Domain

Contains:

* Entities
* Use Cases
* Business Rules
* Repository Contracts

Must remain independent from:

* Flutter
* Firebase
* SQLite

---

### Data

Contains:

* Repositories
* Local Data Sources
* Remote Data Sources
* DTOs

Responsible for:

* SQLite
* HTTP API adapters in Flutter
* PostgreSQL repositories in the Node.js backend
* File/object-storage adapters

Firebase belongs only to the legacy adapters being replaced. New backend features
must not require Firebase, Google Cloud IAM, or cloud identity for local operation.

---

# Feature First Structure

Use feature-based organization.

```text
lib/
│
├── core/
├── shared/
├── features/
│
├── auth/
├── dashboard/
├── branches/
├── products/
├── inventory/
├── sales/
├── transfers/
├── suppliers/
├── customers/
├── reports/
├── shifts/
└── settings/
```

Avoid:

```text
screens/
widgets/
controllers/
models/
services/
```

at root level.

Features must remain isolated.

---

# File Size Rules

## Maximum Responsibility

One file should do only one thing.

Preferred:

```text
create_product_usecase.dart

get_product_usecase.dart

delete_product_usecase.dart
```

Avoid:

```text
product_service.dart
```

with 2000 lines.

---

## Functionality Limit

Each file should contain:

* One primary responsibility
* Maximum two closely related functionalities

Examples:

Good:

```text
create_sale_usecase.dart
```

```text
calculate_discount_usecase.dart
```

Bad:

```text
sales_manager.dart
```

containing:

* Create Sale
* Delete Sale
* Reports
* Inventory Updates
* Receipt Printing

---

# Widget Architecture

## Reusable Widgets First

Before creating a new widget ask:

"Can this already be reused elsewhere?"

Create reusable components.

Examples:

```text
AppButton

AppTextField

AppDropdown

AppCard

AppDialog

AppTable

AppBadge

AppSearchField
```

Use them everywhere.

---

## Avoid Screen-Specific Widgets

Bad:

```text
product_add_button.dart
```

Good:

```text
app_button.dart
```

---

# UI Design System

## Design Inspiration

The UI should resemble:

* Stripe Dashboard
* Linear
* Tailwind UI
* Vercel Dashboard
* Notion

Characteristics:

* Clean
* Spacious
* Minimal
* Professional
* Business-focused

---

# Design Rules

## Colors

Primary:

```text
#2563EB
```

Success:

```text
#22C55E
```

Warning:

```text
#F59E0B
```

Danger:

```text
#EF4444
```

Background:

```text
#F8FAFC
```

Surface:

```text
#FFFFFF
```

Text:

```text
#0F172A
```

Secondary Text:

```text
#64748B
```

---

## Radius

Use consistent rounded corners.

```text
12px
```

or

```text
16px
```

Avoid:

```text
2px
4px
50px
```

mixed together.

---

## Shadows

Use soft shadows.

Example:

```text
0 1px 3px rgba(0,0,0,0.08)
```

Avoid heavy shadows.

---

## Spacing System

Use 8-point spacing.

```text
4
8
12
16
24
32
48
```

Never use random values.

---

# State Management

Use:

```text
Riverpod
```

Recommended structure:

```text
providers/
```

inside each feature.

Example:

```text
products/providers/
```

Avoid global providers unless necessary.

---

# Dependency Injection

Use:

```text
GetIt
```

or

```text
Riverpod Providers
```

Never instantiate services directly inside widgets.

Bad:

```dart
final repo = ProductRepository();
```

Good:

```dart
final repo = ref.read(productRepositoryProvider);
```

---

# Repository Pattern

Every feature must expose interfaces.

Example:

```dart
abstract class ProductRepository {
  Future<List<Product>> getProducts();
}
```

Implementation:

```dart
ProductRepositoryImpl
```

UI must never know the implementation.

---

# Database Rules

## PostgreSQL

Acts as master database.

Contains:

* Branches
* Products
* Sales
* Inventory
* Users

---

## SQLite

Acts as local cache.

Contains:

* Recent products
* Transactions
* Offline queue

---

## No Raw Queries In UI

Never:

```dart
db.query(...)
```

inside screens.

Always go through repositories.

---

# Synchronization Rules

Create dedicated sync module.

```text
core/sync/
```

Responsibilities:

* Upload pending changes
* Download updates
* Conflict resolution

No feature should manage synchronization directly.

---

# Error Handling

Use Result pattern.

Example:

```dart
Result<Product>
```

instead of:

```dart
try {
} catch() {
}
```

throughout UI code.

---

# Logging

Create centralized logger.

```text
core/logger/
```

Log:

* API Errors
* Sync Failures
* Authentication Errors

Never use:

```dart
print()
```

in production.

---

# Testing Requirements

Every feature should support:

## Unit Tests

* Use Cases
* Repositories

## Widget Tests

* Forms
* Buttons
* Screens

## Integration Tests

* Sales Flow
* Inventory Flow
* Authentication Flow

---

# Performance Rules

Avoid:

* Nested FutureBuilders
* Excessive rebuilds
* Large widgets

Prefer:

* Pagination
* Lazy loading
* Riverpod selectors

---

# Naming Conventions

## Files

```text
snake_case.dart
```

Examples:

```text
create_sale_usecase.dart

product_repository.dart

inventory_page.dart
```

---

## Classes

```text
PascalCase
```

Examples:

```text
Product

CreateSaleUseCase

InventoryRepository
```

---

## Variables

```text
camelCase
```

Examples:

```text
productName

totalAmount
```

---

# Golden Rule

Every new feature must be:

* Reusable
* Testable
* Scalable
* Offline-capable
* Branch-aware
* Clean Architecture compliant

If a solution is faster but violates these principles, choose the maintainable solution.
