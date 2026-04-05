import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'add_meal_screen.dart';
import 'meal_list_screen.dart';
import 'meal_planner_screen.dart';
import 'profile_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  String _displayName = '';
  bool _loadingName = true;

  @override
  void initState() {
    super.initState();
    _loadDisplayName();
  }

  Future<void> _loadDisplayName() async {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) {
      setState(() => _loadingName = false);
      return;
    }
    final data = await Supabase.instance.client
        .from('user_profiles')
        .select('display_name')
        .eq('user_id', userId)
        .maybeSingle();
    if (mounted) {
      setState(() {
        _displayName = (data?['display_name'] as String? ?? '').trim();
        _loadingName = false;
      });
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning!';
    if (hour < 17) return 'Good afternoon!';
    return 'Good evening!';
  }

  @override
  Widget build(BuildContext context) {
    final user = Supabase.instance.client.auth.currentUser;
    final email = user?.email ?? '';
    final greeting = _greeting();
    final displayLabel = _displayName.isNotEmpty ? _displayName : email;

    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FA),
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context, greeting, displayLabel),
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'What would you like to do?',
                      style: TextStyle(
                        fontSize: 15,
                        color: Color(0xFF6B7280),
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 16),
                    _NavCard(
                      icon: Icons.menu_book_rounded,
                      iconColor: Colors.white,
                      iconBg: const Color(0xFF4CAF50),
                      title: 'My Meals',
                      subtitle: 'Browse and manage your saved recipes',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MealListScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _NavCard(
                      icon: Icons.add_circle_rounded,
                      iconColor: Colors.white,
                      iconBg: const Color(0xFFFF7043),
                      title: 'Add New Meal',
                      subtitle: 'Create a recipe with ingredients & nutrition',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const AddMealScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _NavCard(
                      icon: Icons.calendar_month_rounded,
                      iconColor: Colors.white,
                      iconBg: const Color(0xFF5C6BC0),
                      title: 'Meal Planner',
                      subtitle: 'Plan your week & generate a shopping list',
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(builder: (_) => const MealPlannerScreen()),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _NavCard(
                      icon: Icons.person_rounded,
                      iconColor: Colors.white,
                      iconBg: const Color(0xFF0288D1),
                      title: 'Profile & Goals',
                      subtitle: 'Set your daily nutrition targets',
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => const ProfileScreen()),
                        );
                        // Reload display name in case user updated it
                        _loadDisplayName();
                      },
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, String greeting, String displayLabel) {
    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF2E7D32), Color(0xFF66BB6A)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(28),
          bottomRight: Radius.circular(28),
        ),
      ),
      padding: const EdgeInsets.fromLTRB(24, 20, 16, 28),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  greeting,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                const Text(
                  'Dinner Planner',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 6),
                if (_loadingName)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white70,
                    ),
                  )
                else if (displayLabel.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      displayLabel,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 12,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
              ],
            ),
          ),
          Column(
            children: [
              const Icon(Icons.restaurant_menu, color: Colors.white, size: 40),
              const SizedBox(height: 8),
              IconButton(
                icon: const Icon(Icons.logout, color: Colors.white70, size: 20),
                tooltip: 'Sign out',
                onPressed: () async {
                  await Supabase.instance.client.auth.signOut();
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _NavCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBg;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _NavCard({
    required this.icon,
    required this.iconColor,
    required this.iconBg,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(16),
      elevation: 2,
      shadowColor: Colors.black12,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: iconColor, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: Color(0xFF1A1A2E),
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Color(0xFF6B7280),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              const Icon(Icons.chevron_right, color: Color(0xFFCBD5E1)),
            ],
          ),
        ),
      ),
    );
  }
}
