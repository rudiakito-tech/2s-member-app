import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data_store.dart';

class StoreTab extends StatefulWidget {
  final AppDataController ctrl;
  const StoreTab({super.key, required this.ctrl});
  @override
  State<StoreTab> createState() => _StoreTabState();
}

class _StoreTabState extends State<StoreTab> {
  bool _usePoints = true;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        if (widget.ctrl.extraStoreDiscount > 0)
          Card(
            color: Colors.amber.withValues(alpha: 0.2),
            child: ListTile(
              leading: const Icon(Icons.local_offer, color: Colors.orange),
              title: Text('Voucher Aktif: Potongan ${widget.ctrl.formatRupiah(widget.ctrl.extraStoreDiscount)}'),
            ),
          ),
        SwitchListTile(
          title: Text('Tukar Poin saat Beli (Saldo: ${widget.ctrl.currentUser!.points} pts)'),
          subtitle: const Text('1 Poin = Rp 100 potongan harga'),
          value: _usePoints,
          onChanged: (v) => setState(() => _usePoints = v),
        ),
        ...widget.ctrl.products.map((p) => Card(
              margin: const EdgeInsets.only(bottom: 10),
              child: ListTile(
                leading: CircleAvatar(child: Icon(p.icon)),
                title: Text(p.name, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${p.category} • Diskon ${p.discountPercent}%\n${widget.ctrl.formatRupiah(p.finalPrice)}'),
                isThreeLine: true,
                trailing: FilledButton(
                  onPressed: () {
                    final msg = widget.ctrl.checkoutProduct(p, _usePoints);
                    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
                  },
                  child: const Text('Beli'),
                ),
              ),
            )),
      ],
    );
  }
}

class GamesMissionTab extends StatefulWidget {
  final AppDataController ctrl;
  const GamesMissionTab({super.key, required this.ctrl});
  @override
  State<GamesMissionTab> createState() => _GamesMissionTabState();
}

class _GamesMissionTabState extends State<GamesMissionTab> {
  double _turns = 0;

  @override
  Widget build(BuildContext context) {
    final u = widget.ctrl.currentUser!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Mini Game: Spin & Win 2S', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 12),
                AnimatedRotation(
                  turns: _turns,
                  duration: const Duration(seconds: 2),
                  curve: Curves.easeOutCubic,
                  child: const CircleAvatar(
                    radius: 52,
                    backgroundColor: Colors.amber,
                    child: Icon(Icons.casino, size: 54, color: Colors.deepOrange),
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () async {
                    setState(() => _turns += 3 + Random().nextDouble());
                    await Future.delayed(const Duration(seconds: 2));
                    final result = widget.ctrl.spinWheelReward();
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
                    }
                  },
                  child: Text(u.freeSpinUsedToday ? 'Putar Lagi (20 Poin)' : 'Putar GRATIS Hari Ini!'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Misi Harian Berhadiah Poin', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...widget.ctrl.missions.map((m) => Card(
              child: ListTile(
                title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${m.description} (+${m.rewardPoints} Poin)'),
                trailing: m.isClaimed
                    ? const Chip(label: Text('Selesai'))
                    : FilledButton(
                        onPressed: m.isCompleted ? () => widget.ctrl.claimMission(m) : null,
                        child: Text(m.isCompleted ? 'Klaim' : 'Belum'),
                      ),
              ),
            )),
      ],
    );
  }
}

class LeaderboardAffiliateTab extends StatelessWidget {
  final AppDataController ctrl;
  const LeaderboardAffiliateTab({super.key, required this.ctrl});

  @override
  Widget build(BuildContext context) {
    final u = ctrl.currentUser!;
    final all = [
      ...ctrl.leaderboard,
      {'name': '${u.name} (Anda)', 'points': u.points, 'tier': u.tier},
    ]..sort((a, b) => (b['points'] as int).compareTo(a['points'] as int));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          color: Colors.indigo.withValues(alpha: 0.1),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Program Affiliate 2S Member', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                Text('Kode Referral Anda: ${u.referralCode}', style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.indigo)),
                const Text('Dapatkan +100 Poin setiap teman servis pakai kode Anda!'),
                const SizedBox(height: 10),
                Row(
                  children: [
                    OutlinedButton.icon(
                      onPressed: () {
                        Clipboard.setData(ClipboardData(text: u.referralCode));
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Kode referral disalin!')));
                      },
                      icon: const Icon(Icons.copy),
                      label: const Text('Salin Kode'),
                    ),
                    const SizedBox(width: 8),
                    FilledButton.icon(
                      onPressed: () {
                        ctrl.simulateAffiliateInvite();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Simulasi teman bergabung: +100 Poin!')));
                      },
                      icon: const Icon(Icons.share),
                      label: const Text('Tes Undang Teman'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Peringkat Member (Leaderboard)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...List.generate(all.length, (i) {
          final item = all[i];
          return Card(
            child: ListTile(
              leading: CircleAvatar(child: Text('#${i + 1}')),
              title: Text(item['name'] as String, style: const TextStyle(fontWeight: FontWeight.bold)),
              subtitle: Text('Tier: ${item['tier']}'),
              trailing: Text('${item['points']} pts', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
            ),
          );
        }),
      ],
    );
  }
}

class ProfileTab extends StatefulWidget {
  final AppDataController ctrl;
  const ProfileTab({super.key, required this.ctrl});
  @override
  State<ProfileTab> createState() => _ProfileTabState();
}

class _ProfileTabState extends State<ProfileTab> {
  final _emailC = TextEditingController();

  @override
  Widget build(BuildContext context) {
    final u = widget.ctrl.currentUser!;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: ListTile(
            leading: const CircleAvatar(child: Icon(Icons.person)),
            title: Text(u.name, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text('WA: ${u.phone} • Tier: ${u.tier}'),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Verifikasi Email (Bonus +50 Poin)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (u.isEmailVerified)
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Text('Terverifikasi: ${u.email}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold)),
                    ],
                  )
                else
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _emailC,
                          decoration: const InputDecoration(hintText: 'nama@email.com', border: OutlineInputBorder()),
                        ),
                      ),
                      const SizedBox(width: 8),
                      FilledButton(
                        onPressed: () {
                          if (_emailC.text.contains('@')) {
                            widget.ctrl.verifyEmail(_emailC.text);
                          }
                        },
                        child: const Text('Verifikasi'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Riwayat Reward Poin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        ...widget.ctrl.pointHistories.map((h) => ListTile(
              dense: true,
              title: Text(h.title),
              trailing: Text(
                '${h.amount >= 0 ? '+' : ''}${h.amount} pts',
                style: TextStyle(fontWeight: FontWeight.bold, color: h.amount >= 0 ? Colors.green : Colors.red),
              ),
            )),
      ],
    );
  }
}
