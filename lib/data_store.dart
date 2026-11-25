import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'app_config.dart';

class MemberUser {
  String id, name, phone, email, referralCode;
  bool isEmailVerified, freeSpinUsedToday;
  int points, checkInStreak;
  DateTime? lastCheckInDate;

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
    this.freeSpinUsedToday = false,
  });

  String get tier {
    if (points >= 2000) return 'Platinum';
    if (points >= 1000) return 'Gold';
    if (points >= 400) return 'Silver';
    return 'Bronze';
  }
}

class ServiceOrder {
  final String id, invoiceNo, customerPhone, deviceName, complaint, replacedPart;
  String status;
  final int totalCost, warrantyDays;
  final DateTime createdAt;
  bool warrantyClaimed;

  ServiceOrder({
    required this.id,
    required this.invoiceNo,
    required this.customerPhone,
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
  final IconData icon;

  StoreProduct({
    required this.id,
    required this.name,
    required this.category,
    required this.price,
    this.discountPercent = 0,
    required this.icon,
  });

  int get finalPrice => (price * (100 - discountPercent) / 100).round();
}

class MissionItem {
  final String id, title, description;
  final int rewardPoints;
  bool isCompleted, isClaimed;

  MissionItem({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardPoints,
    this.isCompleted = false,
    this.isClaimed = false,
  });
}

class PointHistory {
  final String title;
  final int amount;
  final DateTime date;
  PointHistory(this.title, this.amount, this.date);
}

class AppDataController extends ChangeNotifier {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  MemberUser? currentUser;
  bool isAdminMode = false;
  int extraStoreDiscount = 0;

  String? activeOtpSessionId;
  String? activeOtpCode;
  StreamSubscription<DocumentSnapshot>? _otpSub;
  StreamSubscription<QuerySnapshot>? _srvSub;

  List<ServiceOrder> services = [];
  List<PointHistory> pointHistories = [];
  List<Map<String, dynamic>> leaderboard = [];

  final List<StoreProduct> products = [
    StoreProduct(id: 'p1', name: 'Kabel Data Fast Charging 65W', category: 'Aksesoris', price: 65000, discountPercent: 20, icon: Icons.cable),
    StoreProduct(id: 'p2', name: 'Tempered Glass Anti-Spy', category: 'Pelindung', price: 45000, discountPercent: 10, icon: Icons.security),
    StoreProduct(id: 'p3', name: 'Charger Adapter GaN 33W', category: 'Charger', price: 150000, discountPercent: 15, icon: Icons.battery_charging_full),
    StoreProduct(id: 'p4', name: 'TWS Earbuds 2S Bass', category: 'Audio', price: 199000, discountPercent: 25, icon: Icons.headphones),
  ];

  final List<MissionItem> missions = [
    MissionItem(id: 'm1', title: 'Verifikasi Email', description: 'Verifikasi email asli di menu Profil', rewardPoints: 100),
    MissionItem(id: 'm2', title: 'Check-In Pertama', description: 'Lakukan check-in harian hari ini', rewardPoints: 30),
    MissionItem(id: 'm3', title: 'Ajak Teman Affiliate', description: 'Teman daftar pakai kode referral Anda', rewardPoints: 150),
  ];

  String normalizePhone(String p) {
    var d = p.replaceAll(RegExp(r'\D'), '');
    if (d.startsWith('0')) d = '62${d.substring(1)}';
    return d;
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

  // Mulai Reverse OTP via Firestore + Fonnte Webhook
  Future<String> createReverseOtpSession(String inputName, String refCode) async {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    final rnd = Random();
    final code = '2S-${List.generate(6, (_) => chars[rnd.nextInt(chars.length)]).join()}';

    final doc = await _db.collection('otp_sessions').add({
      'code': code,
      'name': inputName.trim(),
      'refCode': refCode.trim().toUpperCase(),
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    activeOtpSessionId = doc.id;
    activeOtpCode = code;

    await _otpSub?.cancel();
    _otpSub = doc.snapshots().listen((snap) async {
      final data = snap.data();
      if (data != null && data['status'] == 'verified') {
        await _otpSub?.cancel();
        final phone = normalizePhone(data['phone'] ?? '');
        final waName = (data['waName'] ?? '').toString();
        final finalName = inputName.trim().isNotEmpty ? inputName.trim() : (waName.isNotEmpty ? waName : 'Member 2S');
        if (phone.isNotEmpty) {
          await _completeLoginFromFirestore(phone, finalName, refCode.trim().toUpperCase());
        }
      }
    });

    notifyListeners();
    return code;
  }

  Future<void> _completeLoginFromFirestore(String phone, String name, String refCode) async {
    final userRef = _db.collection('users').doc(phone);
    final doc = await userRef.get();

    if (!doc.exists) {
      final suffix = phone.length >= 4 ? phone.substring(phone.length - 4) : phone;
      int startPts = 150;
      if (refCode.isNotEmpty) {
        final refSnap = await _db.collection('users').where('referralCode', isEqualTo: refCode).limit(1).get();
        if (refSnap.docs.isNotEmpty) {
          startPts = 200;
          await refSnap.docs.first.reference.update({'points': FieldValue.increment(100)});
          await refSnap.docs.first.reference.collection('point_histories').add({
            'title': 'Komisi Affiliate ($name)',
            'amount': 100,
            'date': FieldValue.serverTimestamp(),
          });
        }
      }
      await userRef.set({
        'name': name,
        'phone': phone,
        'email': '',
        'isEmailVerified': false,
        'points': startPts,
        'referralCode': '2S-$suffix',
        'checkInStreak': 0,
        'lastCheckInDate': null,
        'freeSpinUsedToday': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
      await userRef.collection('point_histories').add({
        'title': startPts > 150 ? 'Bonus Member Baru + Referral' : 'Bonus Member Baru 2S',
        'amount': startPts,
        'date': FieldValue.serverTimestamp(),
      });
    }

    final fresh = await userRef.get();
    final d = fresh.data()!;
    currentUser = MemberUser(
      id: phone,
      name: d['name'] ?? name,
      phone: phone,
      email: d['email'] ?? '',
      isEmailVerified: d['isEmailVerified'] ?? false,
      points: (d['points'] ?? 150) as int,
      referralCode: d['referralCode'] ?? '2S-$phone',
      checkInStreak: (d['checkInStreak'] ?? 0) as int,
      lastCheckInDate: (d['lastCheckInDate'] as Timestamp?)?.toDate(),
      freeSpinUsedToday: d['freeSpinUsedToday'] ?? false,
    );
    missions[0].isCompleted = currentUser!.isEmailVerified;

    await _loadUserHistories();
    await _loadLeaderboard();
    _listenServices();
    notifyListeners();
  }

  void _listenServices() {
    _srvSub?.cancel();
    _srvSub = _db.collection('services').orderBy('createdAt', descending: true).snapshots().listen((snap) {
      services = snap.docs.map((doc) {
        final d = doc.data();
        return ServiceOrder(
          id: doc.id,
          invoiceNo: d['invoiceNo'] ?? '-',
          customerPhone: d['customerPhone'] ?? '',
          deviceName: d['deviceName'] ?? '-',
          complaint: d['complaint'] ?? '-',
          replacedPart: d['replacedPart'] ?? '-',
          status: d['status'] ?? 'Menunggu Cek',
          totalCost: (d['totalCost'] ?? 0) as int,
          createdAt: (d['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          warrantyDays: (d['warrantyDays'] ?? 30) as int,
          warrantyClaimed: d['warrantyClaimed'] ?? false,
        );
      }).toList();
      notifyListeners();
    });
  }

  Future<void> _loadUserHistories() async {
    if (currentUser == null) return;
    final snap = await _db
        .collection('users')
        .doc(currentUser!.id)
        .collection('point_histories')
        .orderBy('date', descending: true)
        .limit(20)
        .get();
    pointHistories = snap.docs.map((doc) {
      final d = doc.data();
      return PointHistory(
        d['title'] ?? 'Poin',
        (d['amount'] ?? 0) as int,
        (d['date'] as Timestamp?)?.toDate() ?? DateTime.now(),
      );
    }).toList();
  }

  Future<void> _loadLeaderboard() async {
    final snap = await _db.collection('users').orderBy('points', descending: true).limit(10).get();
    leaderboard = snap.docs.map((doc) {
      final d = doc.data();
      final pts = (d['points'] ?? 0) as int;
      final tier = pts >= 2000 ? 'Platinum' : (pts >= 1000 ? 'Gold' : (pts >= 400 ? 'Silver' : 'Bronze'));
      return {'name': d['name'] ?? 'Member', 'points': pts, 'tier': tier};
    }).toList();
  }

  Future<String> sendRealEmailVerification(String email, String password) async {
    try {
      final auth = FirebaseAuth.instance;
      UserCredential cred;
      try {
        cred = await auth.createUserWithEmailAndPassword(email: email.trim(), password: password);
      } on FirebaseAuthException catch (e) {
        if (e.code == 'email-already-in-use') {
          cred = await auth.signInWithEmailAndPassword(email: email.trim(), password: password);
        } else {
          return 'Gagal: ${e.message}';
        }
      }
      if (cred.user != null && !cred.user!.emailVerified) {
        await cred.user!.sendEmailVerification();
        return 'Link verifikasi dikirim ke $email! Cek Inbox/Spam lalu klik tombol Cek Verifikasi.';
      } else if (cred.user?.emailVerified == true) {
        await markEmailVerifiedInDb(email.trim());
        return 'Email sudah terverifikasi!';
      }
      return 'Silakan cek email Anda.';
    } catch (e) {
      return 'Error: $e';
    }
  }

  Future<bool> checkEmailVerificationStatus() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return false;
    await user.reload();
    final refreshed = FirebaseAuth.instance.currentUser;
    if (refreshed != null && refreshed.emailVerified) {
      await markEmailVerifiedInDb(refreshed.email ?? '');
      return true;
    }
    return false;
  }

  Future<void> markEmailVerifiedInDb(String email) async {
    if (currentUser == null || currentUser!.isEmailVerified) return;
    currentUser!.email = email;
    currentUser!.isEmailVerified = true;
    missions[0].isCompleted = true;
    await _db.collection('users').doc(currentUser!.id).update({
      'email': email,
      'isEmailVerified': true,
    });
    await addPoints(50, 'Bonus Verifikasi Email');
  }

  bool canCheckInToday() {
    final last = currentUser?.lastCheckInDate;
    if (last == null) return true;
    final now = DateTime.now();
    return !(last.year == now.year && last.month == now.month && last.day == now.day);
  }

  Future<int> performDailyCheckIn() async {
    if (currentUser == null || !canCheckInToday()) return 0;
    currentUser!.checkInStreak = (currentUser!.checkInStreak % 7) + 1;
    currentUser!.lastCheckInDate = DateTime.now();
    missions[1].isCompleted = true;
    final reward = 15 + (currentUser!.checkInStreak * 5);
    await _db.collection('users').doc(currentUser!.id).update({
      'checkInStreak': currentUser!.checkInStreak,
      'lastCheckInDate': Timestamp.fromDate(currentUser!.lastCheckInDate!),
    });
    await addPoints(reward, 'Check-in Hari ke-${currentUser!.checkInStreak}');
    return reward;
  }

  Future<void> claimMission(MissionItem m) async {
    if (!m.isCompleted || m.isClaimed) return;
    m.isClaimed = true;
    await addPoints(m.rewardPoints, 'Klaim Misi: ${m.title}');
  }

  Future<String> spinWheelReward() async {
    if (currentUser == null) return '';
    if (currentUser!.freeSpinUsedToday) {
      if (currentUser!.points < 20) return 'Poin tidak cukup (butuh 20 poin)';
      await addPoints(-20, 'Tiket Putar Mini Game');
    } else {
      currentUser!.freeSpinUsedToday = true;
      await _db.collection('users').doc(currentUser!.id).update({'freeSpinUsedToday': true});
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

  Future<void> addPoints(int amount, String title) async {
    if (currentUser == null) return;
    currentUser!.points += amount;
    pointHistories.insert(0, PointHistory(title, amount, DateTime.now()));
    await _db.collection('users').doc(currentUser!.id).update({'points': FieldValue.increment(amount)});
    await _db.collection('users').doc(currentUser!.id).collection('point_histories').add({
      'title': title,
      'amount': amount,
      'date': FieldValue.serverTimestamp(),
    });
    await _loadLeaderboard();
    notifyListeners();
  }

  Future<void> addNewService(String custPhone, String device, String complaint, String part, int cost, int warranty) async {
    final inv = '2S-INV-${100 + services.length + 1}';
    await _db.collection('services').add({
      'invoiceNo': inv,
      'customerPhone': normalizePhone(custPhone),
      'deviceName': device,
      'complaint': complaint,
      'replacedPart': part,
      'status': 'Menunggu Cek',
      'totalCost': cost,
      'warrantyDays': warranty,
      'warrantyClaimed': false,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateServiceStatus(ServiceOrder s, String newStatus) async {
    await _db.collection('services').doc(s.id).update({'status': newStatus});
    if (newStatus == 'Selesai' && s.customerPhone.isNotEmpty) {
      await _db.collection('users').doc(s.customerPhone).set({
        'points': FieldValue.increment(50),
      }, SetOptions(merge: true));
      if (s.customerPhone == currentUser?.id) {
        currentUser!.points += 50;
        pointHistories.insert(0, PointHistory('Poin Servis ${s.invoiceNo}', 50, DateTime.now()));
      }
    }
    notifyListeners();
  }

  Future<void> claimWarranty(ServiceOrder s) async {
    await _db.collection('services').doc(s.id).update({'warrantyClaimed': true});
  }

  Future<String> checkoutProduct(StoreProduct p, bool usePoints) async {
    if (currentUser == null) return 'Silakan login';
    int total = p.finalPrice - extraStoreDiscount;
    if (total < 0) total = 0;
    if (usePoints && currentUser!.points > 0) {
      final maxCut = min(total, currentUser!.points * 100);
      final usedPts = (maxCut / 100).floor();
      total -= usedPts * 100;
      if (usedPts > 0) await addPoints(-usedPts, 'Tukar Poin Beli ${p.name}');
    }
    extraStoreDiscount = 0;
    await addPoints(20, 'Cashback Poin Belanja Store');
    return 'Order ${p.name} berhasil! Total bayar: ${formatRupiah(total)}';
  }

  @override
  void dispose() {
    _otpSub?.cancel();
    _srvSub?.cancel();
    super.dispose();
  }
}
