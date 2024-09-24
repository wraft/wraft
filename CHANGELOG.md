# Changelog

## v0.3.1 - 2024-06-05

### Added
- Created a recursive algorithm to automatically replace form fields with values in document instances.
- Added Form Fields Realignment API with field ordering.

### Changed
- Moved ProseMirror JSON to Markdown conversion to the backend for bulk document generation.

---

## v0.3.0 - 2024-04-17

### Added
- Approval system.
- Template file upload.

### Fixed
- Various bug fixes.

---

## v0.2.0 - 2024-03-15

### Changed
- Improvements to the approval system.

---

## v0.1.0 - 2024-01-10

### Added
- Role-Based Access Control (RBAC) and organization management.
- User registration flow.
- MinIO integration with Wraft.
- Waiting list flow.
- Improved filtering and sorting.
- Internal user flow.
- Access token and refresh token authorization.
- Multiple theme file uploads.
- Sentry integration for error tracking.
- Updated payment API.
- Theme and layout module.
- Updated seed data.
- Document module.

---

## v0.0.31 - 2021-04-19

## Added

- User with multiple roles
- Organisation admin panel on kaffy
- Specific role on invitation token
- Send invitation to primary email of organisation with admin role
- Sign up with admin role
- Super admin role
- Organisation can create role
- Control of content type on specific roles
## Changed
- token signup with specific role
- Resource schema resource type to atom
- Check permission for specific resource
- Authorized plug to verify the user have permission on specific task

## Fixed
- Multiple email acceptance on token signup

## v0.0.30 - 2021-04-12

## Added
- Members index
- Search organisation api
- Vendors
- Credo
- Webpack
- Kaffy admin panel
## Changed
- Approval system
- Credo modifications
- Warnings resolved

## v0.0.29 - 2020-06-08


## Added

- Payment and Billing

## v0.0.28 - 2020-05-23

### Added

- All first stage feature of pipeline
- Create Gantt Chart from latex code
- E-signature system

## v0.0.27 - 2020-05-17

### Added

- Beta version of pipeline

### Fixed

- Fixed a vulnerability.

## v0.0.26 - 2020-05-10

### Added

- Bulk import for Data template and Block template
- Action logging
- Integrated Approval system with Flow

## v0.0.25 - 2020-05-03

### Added

- Improved test coverage
- Added CI
- Approval system
- Creates default states for every newly created flows

## v0.0.24 - 2020-04-26

### Added

- Improved test coverage
- Generate latex charts

## v0.0.2.3 - 2020-04-18

### Added

- Blocks
- Field type and content type fields
- Activity stream
- Bulk build
- Keep build hitory
- Versioning of instances
- Commenting on data templates and instances
- Block templates
- Integrated Phoenix live dashboard
- Update state of an instance
- Account management for users

## v0.0.2.2 - 2020-03-27

### Added

- Invite new members to organisation
- Improved tests
- Added documentation

## v0.0.2.1 - 2020-03-23

### Added

- Access control system
- Cron job to delete unused assets
- Generate QR code for documents build

## v0.0.2.0 - 2020-03-17

### Added

- Build documents
- Keep build history

## v0.0.1.10 - 2020-03-12

### Added

- Added pagination to all index APIs
- Added current users organisation details to current user plug

## v0.0.1.9_2 - 2020-03-10

### Added

- List of data templates in current user's organisation

## v0.0.1.9_1 - 2020-03-10

### Changed

- Added color to content type

## v0.0.1.9 - 2020-03-10

### Added

- List of all instances in current user's organisation

### Changed

- Show state of instance in instance index

## v0.0.1.8 - 2020-03-09

### Added

- Create, index, show, update and delete asset

## v0.0.1.7 - 2020-03-06

### Added

- Index, show, update and delete instances

## v0.0.1.6 - 2020-03-05

### Added

- Create, index, show, update and delete theme
- Create, index, show, update and delete data template

## v0.0.1.5 - 2020-03-04

### Added

- Create, update, list, delete and show flows
- Create, updare, list and delete states
- Create unique ID for instances
- Create theme

## v0.0.1.4 - 2020-03-02

### Added

- Create instances of a content type

### Changed

- Updated APIs to accept UUID instead of IDs of associations
- Moved Guardian secret key to env file

## v0.0.1.3_1 - 2020-02-28

### Added

- API to get current user details

## v0.0.1.3 - 2020-02-28

### Added

- List engines
- List, show, update and delete layouts
- List, show, update and delete content types

## v0.0.1.2_1#fix - 2020-02-28

### Fixed

- Changed registration and login routes

## v0.0.1.2_1 - 2020-02-27

### Added

- Documentation

## v0.0.1.2 - 2020-02-27

### Added

- User registraion
- User login
- Role, admin user, and engine seeds
- Create layout
- Create content type

## v0.0.1.1_1 - 2020-02-24

### Fixed

- Heroku delpoy fix

## v0.0.1.1_0 - 2020-02-24

### Fixed

- Heroku delpoy fix

## v0.0.1.1 - 2020-02-24

### Added

- Deployed to Heroku

## v0.0.1 - 2020-02-24

### Added

- Set up DB structure
