# Cravo

Cravo is a Flutter and Firebase food-truck discovery and ordering platform with separate customer and vendor experiences. This repository contains the final MVP baseline with role-based authentication, live truck discovery, vendor go-live broadcasting, menu management, and real-time order flows.

## MVP Summary

The project is production-oriented at MVP level and includes:

- Customer app flow: discover live trucks on map, open truck details, place order, track order status.
- Vendor app flow: go live/offline, broadcast location, manage menu items, review and update incoming orders.
- Shared flow: registration, login, role-based routing, Firestore-backed real-time updates.

## Core Features

### Customer

- Live truck map using OpenStreetMap via flutter_map.
- Search and cuisine filtering.
- Proximity banner for nearby live vendors.
- Truck detail page with menu and info tabs.
- Cart-based order placement.
- Orders tab with latest-first listing.
- Profile tab.

### Vendor

- Live status toggle with periodic location broadcast.
- Vendor dashboard with today stats and recent orders.
- Vendor orders board (tabbed statuses).
- Vendor menu CRUD.
- Vendor profile tab.

### Platform and Backend

- Firebase Authentication.
- Cloud Firestore data model for users, vendors, menus, and orders.
- Firestore security rules included and deploy-ready.
- Route protection and role isolation through GoRouter.

## Tech Stack

- Flutter (Material 3)
- Dart SDK 3.11+
- Firebase Core, Auth, Firestore, Storage, Messaging
- GoRouter
- flutter_map, latlong2, geolocator, geocoding
- flutter_riverpod
- intl, shared_preferences, connectivity_plus

## Architecture Overview

- Entry point: lib/main.dart
- Routing and role redirects: lib/app/router.dart
- Customer screens: lib/screens/customer
- Vendor screens: lib/screens/vendor
- Shared auth/splash screens: lib/screens/shared
- Role resolution service: lib/services/auth_role_service.dart

## Current Route Map

Public:

- /
- /login
- /register

Customer:

- /home
- /truck-detail/:vendorId
- /order-status/:orderId

Vendor:

- /vendor-home
- /vendor-orders
- /vendor-menu
- /vendor-profile

## Firestore Data Model (MVP)

### users/{userId}

- Stores customer profile and role-linked user data.

### vendors/{vendorId}

- Core vendor profile.
- Live state and current GeoPoint location.
- Operational metadata such as locationUpdatedAt.

### menus/{vendorId}/items/{itemId}

- Vendor menu items.
- Availability controls and pricing fields.

### orders/{orderId}

- customerId, vendorId, customerName, vendorName
- items list with quantity and line totals
- totalAmount
- status lifecycle fields
- createdAt, updatedAt, placedAt timestamps

## Security

- Firestore rules are defined in firestore.rules.
- Firebase configuration includes Firestore rules mapping in firebase.json.
- Authorization intent:
  - Users can read/write only their own user documents.
  - Vendors can write only their own vendor and menu data.
  - Customers can create and read their own orders.
  - Vendors can read and update orders assigned to them.

## Setup

### Prerequisites

- Flutter SDK installed and available on PATH.
- Android Studio or Xcode toolchain for target platform.
- Firebase CLI installed for rules deployment.
- A Firebase project with Auth and Firestore enabled.

### Installation

1. Clone repository.
2. Install dependencies.

```bash
flutter pub get
```

### Firebase Configuration

1. Configure Firebase for each target platform.
2. Ensure generated options exist at lib/firebase_options.dart.
3. Confirm android/app/google-services.json is present for Android builds.
4. Deploy security rules when updated:

```bash
firebase deploy --only firestore:rules
```

## Running the App

```bash
flutter run
```

For emulator-specific launch:

```bash
flutter devices
flutter run -d <device-id>
```

## Testing and Quality

Run tests:

```bash
flutter test
```

Recommended local checks before commit:

```bash
flutter analyze
flutter test
```

## MVP Completion Scope

This repository currently represents the completed MVP baseline for:

- Role-based customer and vendor app flows.
- Live location-based discovery.
- Vendor go-live broadcasting.
- Menu and order management essentials.
- Secure Firestore access model.

## Next Release Candidates

- Push notifications for order events.
- Payment integration.
- Enhanced analytics for vendors.
- Admin tooling and moderation workflows.

## Contributing

Contributions welcome! Fork, branch, PR.

## License

MIT License. See [LICENSE](LICENSE) for details.

