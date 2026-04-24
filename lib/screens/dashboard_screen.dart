import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'fault_detail_screen.dart';
import 'login_screen.dart';
import '../services/notification_service.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'dart:async';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({Key? key}) : super(key: key);

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  String _linemanName = 'Loading...';
  String _employeeId = '';
  int _resolvedCount = 0;
  int _activeCount = 0;
  String _avgResponseTime = 'N/A';
  List<Map<String, dynamic>> _faults = [];
  bool _isLoading = true;
  Timer? _notificationTimer;

  @override
  void initState() {
    super.initState();
    _initializeNotifications();
    _loadDashboardData();
    _startNotificationPolling();
  }

  @override
  void dispose() {
    _notificationTimer?.cancel();
    super.dispose();
  }

  void _startNotificationPolling() {
    _notificationTimer = Timer.periodic(Duration(seconds: 10), (timer) {
      _checkForNotifications();
    });
  }

  Future<void> _checkForNotifications() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    final linemanResponse = await Supabase.instance.client
        .from('linemen')
        .select('id')
        .eq('auth_id', userId)
        .single();

    if (linemanResponse == null) return;

    final notifications = await Supabase.instance.client
        .rpc('get_pending_notifications', 
            params: {'p_lineman_id': linemanResponse['id']});

    if (notifications != null && notifications.isNotEmpty) {
      for (var notification in notifications) {
        _showNotificationDialog(
          notification['title'],
          notification['body'],
        );
      }
      
      // Refresh fault list
      _handleRefresh();
    }
  } catch (e) {
    print('Error checking notifications: $e');
  }
}

void _showNotificationDialog(String title, String body) {
  showDialog(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Text(body),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: Text('Dismiss'),
        ),
        ElevatedButton(
          onPressed: () {
            Navigator.pop(context);
            // Fault list already refreshed
          },
          child: Text('View Faults'),
        ),
      ],
    ),
  );
}

  Future<void> _initializeNotifications() async {
  await NotificationService.initialize();

  // Handle notification taps when app is in foreground
  FirebaseMessaging.onMessage.listen((RemoteMessage message) {
    if (message.notification != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                message.notification!.title ?? 'New Notification',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
              ),
              SizedBox(height: 4),
              Text(message.notification!.body ?? ''),
            ],
          ),
          backgroundColor: Colors.red,
          duration: Duration(seconds: 5),
          action: SnackBarAction(
            label: 'View',
            textColor: Colors.white,
            onPressed: () => _handleRefresh(),
          ),
        ),
      );

      // Auto-refresh fault list
      _handleRefresh();
    }
  });

  // Handle notification tap when app is in background/terminated
  FirebaseMessaging.onMessageOpenedApp.listen((RemoteMessage message) {
    print('Notification caused app to open');
    _handleRefresh();
  });
}

  Future<void> _loadDashboardData() async {
    setState(() => _isLoading = true);
    try {
      await Future.wait([
        _loadLinemanInfo(),
        _loadFaults(),
      ]);
    } catch (e) {
      print('Error loading dashboard: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadLinemanInfo() async {
  try {
    final userId = Supabase.instance.client.auth.currentUser?.id;
    if (userId == null) return;

    // Get lineman basic info
    final response = await Supabase.instance.client
        .from('linemen')
        .select('id, name, employee_id, total_faults_resolved, availability_status')
        .eq('auth_id', userId)
        .single();

    if (response != null) {
      final linemanId = response['id'];
      
      setState(() {
        _linemanName = response['name'] ?? 'Lineman';
        _employeeId = response['employee_id'] ?? '';
        _resolvedCount = response['total_faults_resolved'] ?? 0;
      });

      // Calculate average response time
      await _calculateAvgResponseTime(linemanId);
    }
  } catch (e) {
    print('Error loading lineman info: $e');
  }
}

Future<void> _calculateAvgResponseTime(String linemanId) async {
  try {
    // Get all resolved faults for this lineman
    final resolvedFaults = await Supabase.instance.client
        .from('faults')
        .select('created_at, resolved_at')
        .eq('assigned_to', linemanId)
        .eq('status', 'resolved')
        .not('resolved_at', 'is', null);

    if (resolvedFaults== null || resolvedFaults!.isEmpty) {
      setState(() {
        _avgResponseTime = '0 min';
      });
      return;
    }

    // Calculate response times
    double totalMinutes = 0;
    int validCount = 0;

    for (var fault in resolvedFaults!) {
      if (fault['created_at'] != null && fault['resolved_at'] != null) {
        try {
          final createdAt = DateTime.parse(fault['created_at']);
          final resolvedAt = DateTime.parse(fault['resolved_at']);
          final diff = resolvedAt.difference(createdAt);
          totalMinutes += diff.inMinutes;
          validCount++;
        } catch (e) {
          print('Error parsing dates: $e');
        }
      }
    }

    if (validCount > 0) {
      final avgMinutes = (totalMinutes / validCount).round();
      setState(() {
        _avgResponseTime = '$avgMinutes min';
      });
    } else {
      setState(() {
        _avgResponseTime = '0 min';
      });
    }
  } catch (e) {
    print('Error calculating avg response time: $e');
    setState(() {
      _avgResponseTime = 'N/A';
    });
  }
}

  Future<void> _loadFaults() async {
    try {
      final userId = Supabase.instance.client.auth.currentUser?.id;
      if (userId == null) return;

      final linemanResponse = await Supabase.instance.client
          .from('linemen')
          .select('id')
          .eq('auth_id', userId)
          .single();

      if (linemanResponse == null) return;
      final linemanId = linemanResponse['id'];

      final faultsResponse = await Supabase.instance.client
          .from('faults')
          .select('*')
          .eq('assigned_to', linemanId)
          .inFilter('status', ['open', 'assigned'])  // FIXED!
          .order('priority_score', ascending: false);

      if (faultsResponse != null) {
        setState(() {
          _faults = List<Map<String, dynamic>>.from(faultsResponse);
          _activeCount = _faults.length;
        });
      }
    } catch (e) {
      print('Error loading faults: $e');
    }
  }

  Future<void> _handleRefresh() async {
  // Show loading indicator
  setState(() => _isLoading = true);
  
  // Wait a moment for database trigger to complete
  await Future.delayed(Duration(milliseconds: 300));
  
  // Reload everything
  await _loadDashboardData();
  
  // Hide loading indicator
  setState(() => _isLoading = false);
  
  // Show confirmation
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text('✅ Refreshed!'),
      duration: Duration(seconds: 1),
      backgroundColor: Colors.green,
    ),
  );
}

  Future<void> _handleSignOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('Sign Out'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (context) => const LoginScreen()),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: const Text('Dashboard'),
        backgroundColor: Colors.blue[700],
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _handleRefresh,
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.account_circle, size: 32),
            onSelected: (value) {
              if (value == 'logout') {
                _handleSignOut();
              }
            },
            itemBuilder: (BuildContext context) => <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                enabled: false,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _linemanName,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    Text(
                      _employeeId,
                      style: const TextStyle(color: Colors.grey, fontSize: 12),
                    ),
                  ],
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Row(
                  children: [
                    Icon(Icons.exit_to_app, color: Colors.red),
                    SizedBox(width: 10),
                    Text('Sign Out', style: TextStyle(color: Colors.red)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _handleRefresh,
        child: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          colors: [Colors.blue[700]!, Colors.blue[500]!],
                        ),
                      ),
                      child: Column(
                        children: [
                          const CircleAvatar(
                            radius: 40,
                            backgroundColor: Colors.white,
                            child: Icon(Icons.person, size: 50, color: Colors.blue),
                          ),
                          const SizedBox(height: 10),
                          Text(
                            _linemanName,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                          Text(
                            'ID: $_employeeId',
                            style: const TextStyle(
                              fontSize: 14,
                              color: Colors.white70,
                            ),
                          ),
                          const SizedBox(height: 10),
                          // ✅ UPDATED STATUS BADGE - Dynamic based on active faults
Container(
  padding: const EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  ),
  decoration: BoxDecoration(
    color: _activeCount > 0 ? Colors.orange : Colors.green,
    borderRadius: BorderRadius.circular(20),
  ),
  child: Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(
        _activeCount > 0 ? Icons.work : Icons.check_circle,
        size: 16,
        color: Colors.white,
      ),
      const SizedBox(width: 6),
      Text(
        _activeCount > 0 ? 'BUSY' : 'AVAILABLE',
        style: const TextStyle(
          color: Colors.white,
          fontWeight: FontWeight.bold,
          fontSize: 12,
        ),
      ),
    ],
  ),
),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _buildStatCard(
                              'Resolved',
                              _resolvedCount.toString(),
                              Icons.check_circle,
                              Colors.green,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Active',
                              _activeCount.toString(),
                              Icons.warning,
                              Colors.orange,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _buildStatCard(
                              'Avg Time',
                              _avgResponseTime,
                              Icons.timer,
                              Colors.blue,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Active Faults',
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          const SizedBox(height: 12),
                          _faults.isEmpty
                              ? _buildEmptyState()
                              : ListView.builder(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _faults.length,
                                  itemBuilder: (context, index) {
                                    return _buildFaultCard(_faults[index]);
                                  },
                                ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            Text(
              title,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFaultCard(Map<String, dynamic> fault) {
    final priority = fault['priority_score'] ?? 5;
    final color = priority >= 9
        ? Colors.red
        : priority >= 7
            ? Colors.orange
            : Colors.yellow[700]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => FaultDetailScreen(fault: fault),
            ),
          );
          if (result == true) _handleRefresh();
        },
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.warning_amber, color: color, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _formatFaultType(fault['fault_type']),
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Priority: $priority/10',
                      style: TextStyle(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: Colors.grey[400]),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(Icons.check_circle_outline, size: 80, color: Colors.grey[400]),
            const SizedBox(height: 16),
            const Text(
              'No Active Faults',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'You have no assigned faults at the moment',
              style: TextStyle(color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  String _formatFaultType(String? type) {
    if (type == null) return 'Unknown';
    final types = {
      'voltage_drop': 'Voltage Drop',
      'current_leakage': 'Current Leakage',
      'wire_break': 'Wire Break',
      'overload': 'Overload',
    };
    return types[type] ?? type;
  }
}