# Cravo - Food Truck Discovery App

Cravo is a startup-style **food truck discovery and ordering app** (similar to Swiggy/Zomato but specialized for food trucks). Built with Flutter + Firebase, it enables **customers to discover nearby food trucks on a map** and **vendors to go live and receive orders** with real-time interaction.

## 🚀 Features Implemented So Far (MVP Progress)

### Customer Features
- 🔍 **Map-based food truck discovery** using `flutter_map` (OpenStreetMap)
- 🏠 **Bottom navigation**: Home (map), Orders, Profile
- 📱 **Truck detail screen** with vendor info
- 🛒 **Order placement flow** (basic)
- 🌙 **Dark themed modern UI**

### Vendor Features
- ✅ **Go Live / Go Offline toggle**
- 📍 **Real-time location updates** via Geolocator
- 📊 **Vendor dashboard UI** (home, orders)
- 🍽️ **Vendor menu screen** (UI ready)

### Backend Integration
- 👤 **Firebase Authentication** (Email/Password + role-based: Customer/Vendor)
- 🔥 **Firestore** for vendors, orders data
- 🔄 Real-time sync for live status and location

## 🏗️ Tech Stack

| Category | Technologies |
|----------|--------------|
| **Frontend** | Flutter |
| **Backend** | Firebase (Auth, Firestore, Storage, Messaging) |
| **Maps & Location** | flutter_map, latlong2, geolocator, geocoding |
| **State Management** | Riverpod |
| **Navigation** | GoRouter |
| **UI/UX** | Material Design, Lottie, Shimmer, fl_chart |
| **Utilities** | cached_network_image, image_picker, uuid, intl |

## 📂 Project Structure

```
lib/
├── app/              # App-wide config (router.dart)
├── models/           # Data models (Vendor, Order, etc.)
├── providers/        # Riverpod state providers
├── screens/          # All screens
│   ├── customer/     # Customer screens (home, orders, profile, truck_detail)
│   ├── vendor/       # Vendor screens (home, orders, menu)
│   ├── admin/        # Admin panel (TBD)
│   └── shared/       # Shared screens (login, register, splash)
├── services/         # Services (auth_role_service.dart, firebase)
└── widgets/          # Reusable widgets
└── main.dart         # App entry point
```

## ⚙️ Setup Instructions

### 1. Clone & Install
```bash
git clone <your-repo-url>
cd cravo
flutter pub get
```

### 2. Firebase Setup
1. Create a [Firebase project](https://console.firebase.google.com/)
2. Enable **Authentication** → Email/Password
3. Enable **Firestore Database**
4. Add Android app → Download `google-services.json` to `android/app/`
5. (iOS) Add iOS app → Download `GoogleService-Info.plist`

### 3. Run the App
```bash
flutter run
```

**Pro Tip**: Use physical device for location testing!

## 🔥 Firestore Collections (Current Structure)

### `vendors/{vendorId}`
```json
{
  "isLive": true,
  "location": { "latitude": 12.97, "longitude": 77.59 },  // GeoPoint
  "isApproved": true,
  "businessName": "Street Eats",
  "ownerName": "John Doe"
}
```

### `orders/{orderId}`
```json
{
  "customerId": "user123",
  "vendorId": "vendor456",
  "items": ["Burger x2", "Fries x1"],
  "totalAmount": 250,
  "status": "pending",
  "createdAt": "2024-01-15T10:30:00Z"
}
```

### Planned: `menus/{vendorId}/{itemId}`
```json
{
  "name": "Classic Burger",
  "price": 150,
  "imageUrl": "...",
  "available": true
}
```

## 🧪 Current Status

✅ **Working**:
- Vendor LIVE status + location updates to Firestore
- Role-based auth (Customer/Vendor)
- Customer map discovery UI
- Vendor dashboard (home/orders)
- Basic order flow UI

⏳ **In Progress**:
- End-to-end order processing
- Vendor menu integration

## ⚠️ Known Issues / Pending Work

- [ ] Vendor menu system (add/edit items)
- [ ] Complete order lifecycle (accept/reject/ready)
- [ ] Map filtering (approved vendors only)
- [ ] Real-time order notifications (FCM)
- [ ] Payment integration (Razorpay/Stripe)

## 🤝 Contribution Guide

1. **Fork & Clone** → Create feature branch: `feat/your-feature`
2. **Follow structure** - don't break navigation or auth flow
3. **Test locally** → `flutter test` + manual testing
4. **Commit cleanly**:
   ```bash
   git commit -m "feat: add vendor menu CRUD"
   ```
5. **PR to `main`** - include screenshots/demo

**Coding Standards**:
- Use Riverpod for all state
- Type-safe models (freezed/json_serializable)
- Consistent dark theme

## 📌 Future Roadmap

| Phase | Features |
|-------|----------|
| **v1.0** | Menu system, full order flow, FCM notifications |
| **v1.1** | Live truck tracking, ratings/reviews |
| **v2.0** | Admin panel, analytics, payments |

## 📄 License

MIT License - See [LICENSE](LICENSE) file.

---

⭐ **Star us on GitHub** | 🐛 **Found a bug?** Open an issue | 💬 **Questions?** Discussions welcome!

