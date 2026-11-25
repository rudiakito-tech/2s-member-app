import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_config.dart';

class MemberUser {
  String id, name, phone, email, referralCode;
  bool isEmailVerified;
  int points, checkInStreak;
  DateTime? lastCheckInDate, lastSpinDate;
  List<String> claimedMissions;

  MemberUser({
    required this.id,
    required this.name,
    required this.phone,
    this.email = '',
    this.isEmailVerified = false,
    this.points = 150,
    required this.referralCode,
    this.checkInStreak = 0,
    this.lastCheckInDate,
    this.lastSpinDate,
    List<String>? claimedMissions,
  }) : claimedMissions = claimedMissions ?? [];

  String get tier {
    if (points >= 2000) return 'Platinum';
    if (points >= 1000) return 'Gold';
    if (points >= 400) return 'Silver';
    return 'Bronze';
  }
}

class ServiceOrder {
  final String id, invoiceNo, customerPhone, customerName, deviceName, complaint, replacedPart;
  String status;
  final int totalCost, warrantyDays;
  final DateTime createdAt;
  bool warrantyClaimed;

  ServiceOrder({
    required this.id,
    required this.invoiceNo,
    required this.customerPhone,
    required this.customerName,
    required this.deviceName,
    required this.complaint,
    required this.replacedPart,
    required this.status,
    required this.totalCost,
    required this.createdAt,
    this.warrantyDays = 30,
    this.warrantyClaimed = false,
  });

  DateTime get warrantyExpiredAt => createdAt.add(Duration(days: warrantyDays));
  int get remainingWarrantyDays {
    final diff = warrantyExpiredAt.difference(DateTime.now()).inDays;
    return diff < 0 ? 0 : diff;
  }
}

class StoreProduct {
  final String id, name, category;
  final int price, discountPercent;

  StoreProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.discountPercent = 0,
  });

  int get finalPrice => (price * (100 - discountPercent) / 100).round();

  IconData get icon {
    switch (category) {
      case 'Charger':
        return Icons.battery_charging_full;
      case 'Pelindung':
        return Icons.security;
      case 'Audio':
        return Icons.headphones;
      default:
        return Icons.cable;
    }
  }
}

class StoreOrder {
  final String id, userId, userName, productName;
  final int totalPaid;
  String status;
  final DateTime createdAt;

  StoreOrder({
    required this.id,
    required this.userId,
    required this.userName,
    required this.productName,
    required this.totalPaid,
    required this.status,
    required this.createdAt,
  });
}

class PointHistory {
  final String title;
  final int amount;
  final DateTime date;
  PointHistory(this.title, this.amount, this.date);
}

class AppDataController extends ChangeNotifier {
  MemberUser? currentUser;
  String? pendingOtp;
  bool isAdminMode = false;
  int extraStoreDiscount = 0;

  List<ServiceOrder> services = [];
  List<StoreProduct> products = [];
  List<StoreOrder> storeOrders = [];
  List<PointHistory> pointHistories = [];
  List<Map<String, dynamic>> leaderboard = [];

  final List<StreamSubscription> _subs = [];
  FirebaseFirestore get _db => FirebaseFirestore.instance;

  bool get isAdminUser {
    if (currentUser == null) return false;
    return AppConfig.adminPhones.map(AppConfig.normalizePhone).contains(currentUser!.id);
  }

  String formatRupiah(int value) {
    final s = value.toString();
    final buf = StringBuffer();
    for (int i = 0; i < s.length; i++) {
      if (i > 0 && (s.length - i) % 3 == 0) buf.write('.');
      buf.write(s[i]);
    }
    return 'Rp $buf';
  }

  String requestWhatsappOtp(String phone) {
    final code = (100000 + Random().nextInt(900000)).toString();
    pendingOtp = code;
    return code;
  }

  Future<bool> verifyWhatsappOtp(String phone, String name, String code, String ref) async {
    if (code != pendingOtp) return false;
    final uid = AppConfig.normalizePhone(phone);
    final suffix = uid.length >= 4 ? uid.substring(uid.length - 4) : uid;
    final cleanName = name.trim().isEmpty ? 'Member 2S' : name.trim();

    if (AppConfig.useFirebase) {
      final docRef = _db.collection('users').doc(uid);
      final snap = await docRef.get();
      if (!snap.exists) {
        int startPts = 150;
        final refClean = ref.trim().toUpperCase();
        if (refClean.isNotEmpty) {
          final refQ = await _db.collection('users').where('referralCode', isEqualTo: refClean).limit(1).get();
          if (refQ.docs.isNotEmpty) {
            startPts += 50;
            final inviterDoc = refQ.docs.first;
            await inviterDoc.reference.update({'points': FieldValue.increment(100)});
            await _db.collection('point_histories').add({
              'userId': inviterDoc.id,
              'title': 'Komisi Affiliate ($cleanName)',
              'amount': 100,
              'date': FieldValue.serverTimestamp(),
            });
          }
        }
        await docRef.set({
          'name': cleanName,
          'phone': uid,
          'email': '',
          'isEmailVerified': false,
          'points': startPts,
          'referralCode': '2S-$suffix',
          'checkInStreak': 0,
          'claimedMissions': <String>[],
        });
        await _db.collection('point_histories').add({
          'userId': uid,
          'title': 'Bonus Member Baru 2S',
          'amount': startPts,
          'date': FieldValue.serverTimestamp(),
        });
      } else if (name.trim().isNotEmpty) {
        await docRef.update({'name': cleanName});
      }
      currentUser = MemberUser(id: uid, name: cleanName, phone: uid, referralCode: '2S-$suffix');
      isAdminMode = isAdminUser;
      _startFirestoreListeners(uid);
    } else {
      currentUser = MemberUser(id: uid, name: cleanName, phone: uid, referralCode: '2S-$suffix');
      isAdminMode = isAdminUser;
      _loadDemoData(uid);
    }
    notifyListeners();
    return true;
  }

  void _startFirestoreListeners(String uid) {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();

    _subs.add(_db.collection('users').doc(uid).snapshots().listen((doc) {
      if (!doc.exists || doc.data() == null) return;
      final d = doc.data()!;
      currentUser = MemberUser(
        id: doc.id,
        name: d['name'] ?? 'Member 2S',
        phone: d['phone'] ?? doc.id,
        email: d['email'] ?? '',
        isEmailVerified: d['isEmailVerified'] ?? false,
        points: (d['points'] ?? 0) as int,
        referralCode: d['referralCode'] ?? '2S',
        checkInStreak: (d['checkInStreak'] ?? 0) as int,
        lastCheckInDate: (d['lastCheckInDate'] as Timestamp?)?.toDate(),
        lastSpinDate: (d['lastSpinDate'] as Timestamp?)?.toDate(),
        claimedMissions: List<String>.from(d['claimedMissions'] ?? []),
      );
      notifyListeners();
    }));

    final srvStream = isAdminUser
        ? _db.collection('services').snapshots()
        : _db.collection('services').where('customerPhone', isEqualTo: uid).snapshots();
    _subs.add(srvStream.listen((snap) {
      services = snap.docs.map((doc) {
        final d = doc.data();
        return ServiceOrder(
          id: doc.id,
          invoiceNo: d['invoiceNo'] ?? '-',
          customerPhone: d['customerPhone'] ?? '',
          customerName: d['customerName'] ?? '',
          deviceName: d['deviceName'] ?? '',
          complaint: d['complaint'] ?? '',
          replacedPart: d['replacedPart'] ?? '',
          status: d['status'] ?? 'Menunggu Cek',
          totalCost: (d['totalCost'] ?? 0) as int,
          warrantyDays: (d['warrantyDays'] ?? 30) as int,
          warrantyClaimed: d['warrantyClaimed'] ?? false,
          createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }));

    _subs.add(_db.collection('products').snapshots().listen((snap) async {
      if (snap.docs.isEmpty && isAdminUser) {
        await _seedDefaultProducts();
        return;
      }
      products = snap.docs.map((doc) {
        final d = doc.data();
        return StoreProduct(
          id: doc.id,
          name: d['name'] ?? '',
          category: d['category'] ?? 'Aksesoris',
          price: (d['price'] ?? 0) as int,
          discountPercent: (d['discountPercent'] ?? 0) as int,
        );
      }).toList();
      notifyListeners();
    }));

    final ordStream = isAdminUser
        ? _db.collection('store_orders').snapshots()
        : _db.collection('store_orders').where('userId', isEqualTo: uid).snapshots();
    _subs.add(ordStream.listen((snap) {
      storeOrders = snap.docs.map((doc) {
        final d = doc.data();
        return StoreOrder(
          id: doc.id,
          userId: d['userId'] ?? '',
          userName: d['userName'] ?? '',
          productName: d['productName'] ?? '',
          totalPaid: (d['totalPaid'] ?? 0) as int,
          status: d['status'] ?? 'Menunggu',
          createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList()
        ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
      notifyListeners();
    }));

    _subs.add(_db.collection('point_histories').where('userId', isEqualTo: uid).snapshots().listen((snap) {
      pointHistories = snap.docs.map((doc) {
        final d = doc.data();
        return PointHistory(
          d['title'] ?? '',
          (d['amount'] ?? 0) as int,
          (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
        );
      }).toList()
        ..sort((a, b) => b.date.compareTo(a.date));
      notifyListeners();
    }));

    _subs.add(_db.collection('users').orderBy('points', descending: true).limit(10).snapshots().listen((snap) {
      leaderboard = snap.docs.map((doc) {
        final d = doc.data();
        final pts = (d['points'] ?? 0) as int;
        final tier = pts >= 2000 ? 'Platinum' : pts >= 1000 ? 'Gold' : pts >= 400 ? 'Silver' : 'Bronze';
        return {'id': doc.id, 'name': d['name'] ?? 'Member', 'points': pts, 'tier': tier};
      }).toList();
      notifyListeners();
    }));
  }

  Future<void> _seedDefaultProducts() async {
    final defaults = [
      {'name': 'Kabel Data Fast Charging 65W', 'category': 'Aksesoris', 'price': 65000, 'discountPercent': 20},
      {'name': 'Tempered Glass Anti-Spy', 'category': 'Pelindung', 'price': 45000, 'discountPercent': 10},
      {'name': 'Charger Adapter GaN 33W', 'category': 'Charger', 'price': 150000, 'discountPercent': 15},
      {'name': 'TWS Earbuds 2S Bass', 'category': 'Audio', 'price': 199000, 'discountPercent': 25},
    ];
    for (final p in defaults) {
      await _db.collection('products').add(p);
    }
  }

  void _loadDemoData(String uid) {
    products = [
      StoreProduct(id: 'p1', name: 'Kabel Data 65W', category: 'Aksesoris', price: 65000, discountPercent: 20),
      StoreProduct(id: 'p2', name: 'Tempered Glass Anti-Spy', category: 'Pelindung', price: 45000, discountPercent: 10),
    ];
    pointHistories = [PointHistory('Bonus Member Baru 2S', 150, DateTime.now())];
    leaderboard = [{'id': uid, 'name': currentUser!.name, 'points': 150, 'tier': 'Bronze'}];
  }

  bool _isSameDay(DateTime? d) {
    if (d == null) return false;
    final now = DateTime.now();
    return d.year == now.year && d.month == now.month && d.day == now.day;
  }

  bool canCheckInToday() => !_isSameDay(currentUser?.lastCheckInDate);
  bool get hasFreeSpinToday => !_isSameDay(currentUser?.lastSpinDate);

  Future<int> performDailyCheckIn() async {
    if (currentUser == null || !canCheckInToday()) return 0;
    final nextStreak = (currentUser!.checkInStreak % 7) + 1;
    final reward = 15 + (nextStreak * 5);
    currentUser!.checkInStreak = nextStreak;
    currentUser!.lastCheckInDate = DateTime.now();
    if (AppConfig.useFirebase) {
      await _db.collection('users').doc(currentUser!.id).update({
        'checkInStreak': nextStreak,
        'lastCheckInDate': FieldValue.serverTimestamp(),
      });
    }
    await addPoints(reward, 'Check-in Hari ke-$nextStreak');
    return reward;
  }

  Future<String> spinWheelReward() async {
    if (currentUser == null) return '';
    if (!hasFreeSpinToday) {
      if (currentUser!.points < 20) return 'Poin tidak cukup (butuh 20 poin)';
      await addPoints(-20, 'Tiket Putar Mini Game');
    } else {
      currentUser!.lastSpinDate = DateTime.now();
      if (AppConfig.useFirebase) {
        await _db.collection('users').doc(currentUser!.id).update({'lastSpinDate': FieldValue.serverTimestamp()});
      }
    }
    final rewards = [10, 25, 50, 100, 0];
    final win = rewards[Random().nextInt(rewards.length)];
    if (win == 0) {
      extraStoreDiscount = 15000;
      notifyListeners();
      return 'Menang Voucher Diskon Store Rp 15.000!';
    } else {
      await addPoints(win, 'Hadiah Mini Game Spin Wheel');
      return 'Selamat! Dapat +$win Poin!';
    }
  }

  bool isMissionDone(String id) {
    if (id == 'm1') return currentUser?.isEmailVerified ?? false;
    if (id == 'm2') return !canCheckInToday();
    if (id == 'm3') return services.any((s) => s.status == 'Selesai' || s.status == 'Diambil');
    return false;
  }

  Future<void> claimMission(String id, String title, int pts) async {
    if (currentUser == null || currentUser!.claimedMissions.contains(id) || !isMissionDone(id)) return;
    currentUser!.claimedMissions.add(id);
    if (AppConfig.useFirebase) {
      await _db.collection('users').doc(currentUser!.id).update({
        'claimedMissions': FieldValue.arrayUnion([id]),
      });
    }
    await addPoints(pts, 'Klaim Misi: $title');
  }

  Future<void> addPoints(int amount, String title) async {
    if (currentUser == null) return;
    currentUser!.points += amount;
    if (AppConfig.useFirebase) {
      await _db.collection('users').doc(currentUser!.id).update({'points': FieldValue.increment(amount)});
      await _db.collection('point_histories').add({
        'userId': currentUser!.id,
        'title': title,
        'amount': amount,
        'date': FieldValue.serverTimestamp(),
      });
    } else {
      pointHistories.insert(0, PointHistory(title, amount, DateTime.now()));
      notifyListeners();
    }
  }

  Future<String> sendFirebaseEmailVerification(String email, String password) async {
    if (!AppConfig.useFirebase) {
      currentUser!.email = email.trim();
      currentUser!.isEmailVerified = true;
      await addPoints(50, 'Bonus Verifikasi Email');
      return 'Email terverifikasi (Mode Simulasi)!';
    }
    try {
      final auth = FirebaseAuth.instance;
      UserCredential cred;
      try {
        cred = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          cred = await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        } else {
          return e.message ?? 'Gagal mendaftarkan email';
        }
      }
      await cred.user?.sendEmailVerification();
      await _db.collection('users').doc(currentUser!.id).update({'email': email.trim()});
      return 'Link verifikasi dikirim ke $email! Klik link di inbox/spam lalu tekan Cek Status.';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<String> checkEmailVerificationStatus() async {
    if (!AppConfig.useFirebase) return 'Sudah terverifikasi';
    final u = FirebaseAuth.instance.currentUser;
    if (u == null) return 'Kirim link verifikasi terlebih dahulu';
    await u.reload();
    if (FirebaseAuth.instance.currentUser?.emailVerified == true) {
      if (!currentUser!.isEmailVerified) {
        await _db.collection('users').doc(currentUser!.id).update({'isEmailVerified': true});
        await addPoints(50, 'Bonus Verifikasi Email');
      }
      return 'Berhasil! Email Anda sudah terverifikasi (+50 Poin).';
    }
    return 'Email belum diklik. Cek kotak masuk atau folder Spam Anda.';
  }

  Future<void> addNewService(String custPhone, String custName, String device, String complaint, String part, int cost, int warranty) async {
    final normPhone = AppConfig.normalizePhone(custPhone);
    final inv = '2S-INV-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}';
    if (AppConfig.useFirebase) {
      await _db.collection('services').add({
        'invoiceNo': inv,
        'customerPhone': normPhone,
        'customerName': custName.trim().isEmpty ? 'Pelanggan' : custName.trim(),
        'deviceName': device,
        'complaint': complaint,
        'replacedPart': part,
        'status': 'Menunggu Cek',
        'totalCost': cost,
        'warrantyDays': warranty,
        'warrantyClaimed': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } else {
      services.insert(0, ServiceOrder(
        id: inv, invoiceNo: inv, customerPhone: normPhone, customerName: custName,
        deviceName: device, complaint: complaint, replacedPart: part,
        status: 'Menunggu Cek', totalCost: cost, createdAt: DateTime.now(), warrantyDays: warranty,
      ));
      notifyListeners();
    }
  }

  Future<void> updateServiceStatus(ServiceOrder s, String newStatus) async {
    if (AppConfig.useFirebase) {
      await _db.collection('services').doc(s.id).update({'status': newStatus});
      if (newStatus == 'Selesai' && s.status != 'Selesai') {
        final custDoc = _db.collection('users').doc(s.customerPhone);
        if ((await custDoc.get()).exists) {
          await custDoc.update({'points': FieldValue.increment(50)});
          await _db.collection('point_histories').add({
            'userId': s.customerPhone,
            'title': 'Poin Servis Selesai (${s.invoiceNo})',
            'amount': 50,
            'date': FieldValue.serverTimestamp(),
          });
        }
      }
    } else {
      s.status = newStatus;
      notifyListeners();
    }
  }

  Future<void> claimWarranty(ServiceOrder s) async {
    if (AppConfig.useFirebase) {
      await _db.collection('services').doc(s.id).update({'warrantyClaimed': true});
    } else {
      s.warrantyClaimed = true;
      notifyListeners();
    }
  }

  Future<void> addProduct(String name, String category, int price, int disc) async {
    if (AppConfig.useFirebase) {
      await _db.collection('products').add({
        'name': name,
        'category': category,
        'price': price,
        'discountPercent': disc,
      });
    } else {
      products.add(StoreProduct(id: '${products.length + 1}', name: name, category: category, price: price, discountPercent: disc));
      notifyListeners();
    }
  }

  Future<String> checkoutProduct(StoreProduct p, bool usePoints) async {
    if (currentUser == null) return 'Silakan login';
    int total = p.finalPrice - extraStoreDiscount;
    if (total < 0) total = 0;
    if (usePoints && currentUser!.points > 0) {
      final usedPts = (min(total, currentUser!.points * 100) / 100).floor();
      total -= usedPts * 100;
      if (usedPts > 0) await addPoints(-usedPts, 'Tukar Poin Beli ${p.name}');
    }
    extraStoreDiscount = 0;
    if (AppConfig.useFirebase) {
      await _db.collection('store_orders').add({
        'userId': currentUser!.id,
        'userName': currentUser!.name,
        'productName': p.name,
        'totalPaid': total,
        'status': 'Menunggu',
        'createdAt': FieldValue.serverTimestamp(),
      });
    }
    await addPoints(20, 'Cashback Belanja ${p.name}');
    return 'Pesanan ${p.name} dibuat! Total: ${formatRupiah(total)}';
  }

  Future<void> updateOrderStatus(StoreOrder o, String status) async {
    if (AppConfig.useFirebase) {
      await _db.collection('store_orders').doc(o.id).update({'status': status});
    }
  }

  void logout() {
    for (final s in _subs) {
      s.cancel();
    }
    _subs.clear();
    currentUser = null;
    isAdminMode = false;
    notifyListeners();
  }
}
