import 'dart:math';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
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
  final String id, invoiceNo, deviceName, complaint, replacedPart;
  String status;
  final int totalCost, warrantyDays;
  final DateTime createdAt;
  bool warrantyClaimed;

  ServiceOrder({
    required this.id,
    required this.invoiceNo,
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
  MemberUser? currentUser;
  String? pendingOtp;
  bool isAdminMode = false;
  int extraStoreDiscount = 0;

  final List<ServiceOrder> services = [
    ServiceOrder(
      id: 's1',
      invoiceNo: '2S-INV-001',
      deviceName: 'Samsung Galaxy A54',
      complaint: 'Layar retak & touch macet',
      replacedPart: 'LCD Original AMOLED',
      status: 'Selesai',
      totalCost: 850000,
      createdAt: DateTime.now().subtract(const Duration(days: 5)),
      warrantyDays: 30,
    ),
    ServiceOrder(
      id: 's2',
      invoiceNo: '2S-INV-002',
      deviceName: 'iPhone 13',
      complaint: 'Baterai cepat drop (BH 72%)',
      replacedPart: 'Baterai High Capacity + Seal',
      status: 'Dikerjakan',
      totalCost: 480000,
      createdAt: DateTime.now().subtract(const Duration(hours: 4)),
      warrantyDays: 60,
    ),
  ];

  final List<StoreProduct> products = [
    StoreProduct(
      id: 'p1',
      name: 'Kabel Data Fast Charging 65W',
      category: 'Aksesoris',
      price: 65000,
      discountPercent: 20,
      icon: Icons.cable,
    ),
    StoreProduct(
      id: 'p2',
      name: 'Tempered Glass Anti-Spy',
      category: 'Pelindung',
      price: 45000,
      discountPercent: 10,
      icon: Icons.security,
    ),
    StoreProduct(
      id: 'p3',
      name: 'Charger Adapter GaN 33W',
      category: 'Charger',
      price: 150000,
      discountPercent: 15,
      icon: Icons.battery_charging_full,
    ),
    StoreProduct(
      id: 'p4',
      name: 'TWS Earbuds 2S Bass',
      category: 'Audio',
      price: 199000,
      discountPercent: 25,
      icon: Icons.headphones,
    ),
  ];

  final List<MissionItem> missions = [
    MissionItem(
      id: 'm1',
      title: 'Verifikasi Email',
      description: 'Lengkapi & verifikasi email di menu Profil',
      rewardPoints: 100,
    ),
    MissionItem(
      id: 'm2',
      title: 'Check-In Pertama',
      description: 'Lakukan check-in harian hari ini',
      rewardPoints: 30,
    ),
    MissionItem(
      id: 'm3',
      title: 'Ajak Teman Affiliate',
      description: 'Bagikan kode referral Anda ke teman',
      rewardPoints: 150,
    ),
  ];

  final List<PointHistory> pointHistories = [
    PointHistory('Bonus Member Baru 2S', 150, DateTime.now()),
  ];

  final List<Map<String, dynamic>> leaderboard = [
    {'name': 'Rizky Pratama', 'points': 2450, 'tier': 'Platinum'},
    {'name': 'Siti Aisyah', 'points': 1620, 'tier': 'Gold'},
    {'name': 'Budi Santoso', 'points': 940, 'tier': 'Silver'},
  ];

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
    final clean = phone.replaceAll(RegExp(r'\D'), '');
    final suffix = clean.length >= 4 ? clean.substring(clean.length - 4) : clean;
    currentUser = MemberUser(
      id: clean,
      name: name.trim().isEmpty ? 'Member 2S' : name.trim(),
      phone: phone.trim(),
      referralCode: '2S-$suffix',
      points: ref.trim().isNotEmpty ? 200 : 150,
    );
    if (ref.trim().isNotEmpty) {
      pointHistories.insert(0, PointHistory('Bonus Kode Referral ($ref)', 50, DateTime.now()));
    }
    if (AppConfig.useFirebase) {
      await FirebaseFirestore.instance.collection('users').doc(clean).set({
        'name': currentUser!.name,
        'phone': currentUser!.phone,
        'points': currentUser!.points,
        'referralCode': currentUser!.referralCode,
      }, SetOptions(merge: true));
    }
    notifyListeners();
    return true;
  }

  void verifyEmail(String email) {
    if (currentUser == null) return;
    currentUser!.email = email.trim();
    currentUser!.isEmailVerified = true;
    missions[0].isCompleted = true;
    addPoints(50, 'Bonus Verifikasi Email');
  }

  bool canCheckInToday() {
    final last = currentUser?.lastCheckInDate;
    if (last == null) return true;
    final now = DateTime.now();
    return !(last.year == now.year && last.month == now.month && last.day == now.day);
  }

  int performDailyCheckIn() {
    if (currentUser == null || !canCheckInToday()) return 0;
    currentUser!.checkInStreak = (currentUser!.checkInStreak % 7) + 1;
    currentUser!.lastCheckInDate = DateTime.now();
    missions[1].isCompleted = true;
    final reward = 15 + (currentUser!.checkInStreak * 5);
    addPoints(reward, 'Check-in Hari ke-${currentUser!.checkInStreak}');
    return reward;
  }

  void claimMission(MissionItem m) {
    if (!m.isCompleted || m.isClaimed) return;
    m.isClaimed = true;
    addPoints(m.rewardPoints, 'Klaim Misi: ${m.title}');
  }

  void simulateAffiliateInvite() {
    missions[2].isCompleted = true;
    addPoints(100, 'Komisi Affiliate Teman Servis');
  }

  String spinWheelReward() {
    if (currentUser == null) return '';
    if (currentUser!.freeSpinUsedToday) {
      if (currentUser!.points < 20) return 'Poin tidak cukup (butuh 20 poin)';
      addPoints(-20, 'Tiket Putar Mini Game');
    } else {
      currentUser!.freeSpinUsedToday = true;
    }
    final rewards = [10, 25, 50, 100, 0];
    final win = rewards[Random().nextInt(rewards.length)];
    if (win == 0) {
      extraStoreDiscount = 15000;
      notifyListeners();
      return 'Menang Voucher Diskon Store Rp 15.000!';
    } else {
      addPoints(win, 'Hadiah Mini Game Spin Wheel');
      return 'Selamat! Dapat +$win Poin!';
    }
  }

  void addPoints(int amount, String title) {
    if (currentUser == null) return;
    currentUser!.points += amount;
    pointHistories.insert(0, PointHistory(title, amount, DateTime.now()));
    notifyListeners();
  }

  void updateServiceStatus(ServiceOrder s, String newStatus) {
    s.status = newStatus;
    if (newStatus == 'Selesai') {
      addPoints(50, 'Poin Transaksi Servis ${s.invoiceNo}');
    }
    notifyListeners();
  }

  void addNewService(String device, String complaint, String part, int cost, int warranty) {
    final inv = '2S-INV-${100 + services.length + 1}';
    services.insert(
      0,
      ServiceOrder(
        id: 's${services.length + 1}',
        invoiceNo: inv,
        deviceName: device,
        complaint: complaint,
        replacedPart: part,
        status: 'Menunggu Cek',
        totalCost: cost,
        createdAt: DateTime.now(),
        warrantyDays: warranty,
      ),
    );
    notifyListeners();
  }

  void claimWarranty(ServiceOrder s) {
    s.warrantyClaimed = true;
    notifyListeners();
  }

  String checkoutProduct(StoreProduct p, bool usePoints) {
    if (currentUser == null) return 'Silakan login';
    int total = p.finalPrice - extraStoreDiscount;
    if (total < 0) total = 0;
    int usedPts = 0;
    if (usePoints && currentUser!.points > 0) {
      final maxCut = min(total, currentUser!.points * 100);
      usedPts = (maxCut / 100).floor();
      total -= usedPts * 100;
      if (usedPts > 0) addPoints(-usedPts, 'Tukar Poin Beli ${p.name}');
    }
    extraStoreDiscount = 0;
    addPoints(20, 'Cashback Poin Belanja Store');
    return 'Order ${p.name} berhasil! Total bayar: ${formatRupiah(total)}';
  }
}
