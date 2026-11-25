import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data_store.dart';

class GamesMissionTab extends StatefulWidget {
  final AppDataController ctrl;
  const GamesMissionTab({super.key, required this.ctrl});
  @override
  State<GamesMissionTab> createState() => _GamesMissionTabState();
}

class _GamesMissionTabState extends State<GamesMissionTab> {
  double _turns = 0;
  bool _spinning = false;

  @override
  Widget build(BuildContext context) {
    final free = widget.ctrl.freeSpinAvailable;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                const Text('Mini Game: Spin & Win 2S', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 6),
                const Text('Hadiah: +10 s/d +100 Poin atau Voucher Diskon Rp 15.000', style: TextStyle(fontSize: 12, color: Colors.grey)),
                const SizedBox(height: 16),
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
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: _spinning
                      ? null
                      : () async {
                          setState(() {
                            _spinning = true;
                            _turns += 3 + Random().nextDouble();
                          });
                          await Future.delayed(const Duration(seconds: 2));
                          final result = await widget.ctrl.spinWheelReward();
                          if (mounted) {
                            setState(() => _spinning = false);
                            ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(result)));
                          }
                        },
                  child: Text(free ? 'Putar GRATIS Hari Ini!' : 'Putar Lagi (20 Poin)'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Misi Harian & Member', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...widget.ctrl.missions.map((m) => Card(
              child: ListTile(
                title: Text(m.title, style: const TextStyle(fontWeight: FontWeight.bold)),
                subtitle: Text('${m.description}\nHadiah: +${m.rewardPoints} Poin'),
                isThreeLine: true,
                trailing: m.isClaimed
                    ? const Chip(label: Text('Diklaim'))
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
                const Text('Bagikan kode ini ke teman. Saat teman daftar pakai kode Anda, Anda otomatis dapat +100 Poin!'),
                const SizedBox(height: 10),
                FilledButton.icon(
                  onPressed: () {
                    Clipboard.setData(ClipboardData(text: u.referralCode));
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Kode ${u.referralCode} disalin!')),
                    );
                  },
                  icon: const Icon(Icons.copy),
                  label: const Text('Salin Kode Referral'),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Peringkat Member (Top 15)', style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        if (ctrl.leaderboard.isEmpty)
          const Center(child: Padding(padding: EdgeInsets.all(16), child: Text('Memuat peringkat...'))),
        ...List.generate(ctrl.leaderboard.length, (i) {
          final item = ctrl.leaderboard[i];
          final isMe = item['phone'] == u.phone;
          return Card(
            color: isMe ? Colors.blue.withValues(alpha: 0.08) : null,
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: i == 0 ? Colors.amber : null,
                child: Text('#${i + 1}'),
              ),
              title: Text(
                isMe ? '${item['name']} (Anda)' : item['name'].toString(),
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
              subtitle: Text('Tier: ${item['tier']}'),
              trailing: Text('${item['points']} pts', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange)),
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
  final _passC = TextEditingController();
  bool _sent = false;
  bool _loading = false;

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
            trailing: IconButton(
              icon: const Icon(Icons.logout, color: Colors.red),
              tooltip: 'Keluar',
              onPressed: () => widget.ctrl.logout(),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Verifikasi Email (Bonus +50 Poin & Misi +100 Poin)', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                if (u.isEmailVerified)
                  Row(
                    children: [
                      const Icon(Icons.check_circle, color: Colors.green),
                      const SizedBox(width: 8),
                      Expanded(child: Text('Terverifikasi: ${u.email}', style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold))),
                    ],
                  )
                else ...[
                  TextField(
                    controller: _emailC,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(labelText: 'Alamat Email Aktif', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _passC,
                    obscureText: true,
                    decoration: const InputDecoration(labelText: 'Buat Password (min. 6 karakter)', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton(
                        onPressed: _loading
                            ? null
                            : () async {
                                if (!_emailC.text.contains('@') || _passC.text.length < 6) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Isi email valid & password minimal 6 karakter')),
                                  );
                                  return;
                                }
                                setState(() => _loading = true);
                                final res = await widget.ctrl.sendFirebaseEmailVerification(_emailC.text, _passC.text);
                                if (mounted) {
                                  setState(() {
                                    _loading = false;
                                    if (res == 'OK') _sent = true;
                                  });
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text(res == 'OK'
                                          ? 'Link verifikasi dikirim ke email! Cek Inbox/Spam lalu klik tombol Cek Status.'
                                          : res),
                                    ),
                                  );
                                }
                              },
                        child: Text(_loading ? 'Mengirim...' : 'Kirim Link Verifikasi'),
                      ),
                      if (_sent)
                        OutlinedButton(
                          onPressed: () async {
                            final ok = await widget.ctrl.checkAndCompleteEmailVerification();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(ok ? 'Email terverifikasi! +50 Poin masuk!' : 'Belum diklik, cek Inbox/Spam email Anda.')),
                              );
                            }
                          },
                          child: const Text('Cek Status Verifikasi'),
                        ),
                    ],
                  ),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text('Riwayat Reward Poin', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
        if (widget.ctrl.pointHistories.isEmpty)
          const Padding(padding: EdgeInsets.all(12), child: Text('Belum ada riwayat poin')),
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
