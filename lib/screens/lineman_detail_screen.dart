import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'fault_detail_screen.dart';

class LinemanDetailScreen extends StatefulWidget {
  final Map<String, dynamic> lineman;

  const LinemanDetailScreen({Key? key, required this.lineman}) : super(key: key);

  @override
  State<LinemanDetailScreen> createState() => _LinemanDetailScreenState();
}

class _LinemanDetailScreenState extends State<LinemanDetailScreen> {
  bool _isLoading = true;
  
  // Statistics
  int _totalResolved = 0;
  int _totalActive = 0;
  String _avgResponseTime = 'N/A';
  double _performanceScore = 0.0;
  
  // Faults data
  List<Map<String, dynamic>> _resolvedFaults = [];
  List<Map<String, dynamic>> _activeFaults = [];

  @override
  void initState() {
    super.initState();
    _loadLinemanData();
  }

  Future<void> _loadLinemanData() async {
    setState(() => _isLoading = true);

    try {
      await Future.wait([
        _loadStatistics(),
        _loadResolvedFaults(),
        _loadActiveFaults(),
      ]);
      
      _calculatePerformance();
    } catch (e) {
      print('Error loading lineman data: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _loadStatistics() async {
    try {
      // Get total resolved count
      final resolvedCount = await Supabase.instance.client
          .from('faults')
          .select('id')
          .eq('assigned_to', widget.lineman['id'])
          .eq('status', 'resolved');

      _totalResolved = resolvedCount.data?.length ?? 0;

      // Get active faults count
      final activeCount = await Supabase.instance.client
          .from('faults')
          .select('id')
          .eq('assigned_to', widget.lineman['id'])
          .inFilter('status', ['open', 'assigned']);

      _totalActive = activeCount.data?.length ?? 0;

      // Calculate average response time
      final resolvedWithTime = await Supabase.instance.client
          .from('faults')
          .select('created_at, resolved_at')
          .eq('assigned_to', widget.lineman['id'])
          .eq('status', 'resolved')
          .not('resolved_at', 'is', null);

      if (resolvedWithTime.data != null && resolvedWithTime.data!.isNotEmpty) {
        double totalMinutes = 0;
        int validCount = 0;

        for (var fault in resolvedWithTime.data!) {
          try {
            final created = DateTime.parse(fault['created_at']);
            final resolved = DateTime.parse(fault['resolved_at']);
            totalMinutes += resolved.difference(created).inMinutes;
            validCount++;
          } catch (e) {
            print('Error parsing dates: $e');
          }
        }

        if (validCount > 0) {
          final avgMinutes = (totalMinutes / validCount).round();
          _avgResponseTime = '$avgMinutes min';
        }
      }

      setState(() {});
    } catch (e) {
      print('Error loading statistics: $e');
    }
  }

  Future<void> _loadResolvedFaults() async {
    try {
      final response = await Supabase.instance.client
          .from('faults')
          .select('*, poles(pole_number, location_name, latitude, longitude)')
          .eq('assigned_to', widget.lineman['id'])
          .eq('status', 'resolved')
          .order('resolved_at', ascending: false)
          .limit(10);

      if (response.data != null) {
        setState(() {
          _resolvedFaults = List<Map<String, dynamic>>.from(response.data);
        });
      }
    } catch (e) {
      print('Error loading resolved faults: $e');
    }
  }

  Future<void> _loadActiveFaults() async {
    try {
      final response = await Supabase.instance.client
          .from('faults')
          .select('*, poles(pole_number, location_name, latitude, longitude)')
          .eq('assigned_to', widget.lineman['id'])
          .inFilter('status', ['open', 'assigned'])
          .order('created_at', ascending: false);

      if (response.data != null) {
        setState(() {
          _activeFaults = List<Map<String, dynamic>>.from(response.data);
        });
      }
    } catch (e) {
      print('Error loading active faults: $e');
    }
  }

  void _calculatePerformance() {
    // Performance score calculation (0-100)
    double score = 50.0; // Base score

    // Factor 1: Resolution rate (40 points max)
    if (_totalResolved > 0) {
      score += (_totalResolved * 2).clamp(0, 40).toDouble();
    }

    // Factor 2: Response time (30 points max)
    if (_avgResponseTime != 'N/A') {
      final avgMin = int.tryParse(_avgResponseTime.replaceAll(' min', '')) ?? 60;
      if (avgMin <= 5) score += 30;
      else if (avgMin <= 10) score += 25;
      else if (avgMin <= 15) score += 20;
      else if (avgMin <= 30) score += 15;
      else score += 5;
    }

    // Factor 3: Active workload (10 points - lower is better)
    if (_totalActive == 0) score += 10;
    else if (_totalActive <= 2) score += 7;
    else if (_totalActive <= 5) score += 4;

    _performanceScore = score.clamp(0, 100);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.lineman['name'] ?? 'Lineman Details'),
        backgroundColor: Colors.blue[700],
        elevation: 0,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _loadLinemanData,
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    // Header Card
                    _buildHeaderCard(),
                    
                    // Statistics Cards
                    _buildStatsGrid(),
                    
                    // Performance Card
                    _buildPerformanceCard(),
                    
                    // Active Faults Section
                    _buildActiveFaultsSection(),
                    
                    // Resolved Faults Section
                    _buildResolvedFaultsSection(),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildHeaderCard() {
    final status = widget.lineman['availability_status'] ?? 'available';
    final isAvailable = status == 'available';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [Colors.blue[700]!, Colors.blue[500]!],
        ),
      ),
      child: Column(
        children: [
          CircleAvatar(
            radius: 50,
            backgroundColor: Colors.white,
            child: Icon(
              Icons.person,
              size: 60,
              color: Colors.blue[700],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.lineman['name'] ?? 'Unknown',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'ID: ${widget.lineman['employee_id'] ?? 'N/A'}',
            style: const TextStyle(
              fontSize: 16,
              color: Colors.white70,
            ),
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isAvailable ? Colors.green : Colors.orange,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  isAvailable ? Icons.check_circle : Icons.work,
                  color: Colors.white,
                  size: 18,
                ),
                const SizedBox(width: 6),
                Text(
                  isAvailable ? 'AVAILABLE' : 'BUSY',
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsGrid() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Expanded(
            child: _buildStatCard(
              'Total Resolved',
              _totalResolved.toString(),
              Icons.check_circle,
              Colors.green,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Active Faults',
              _totalActive.toString(),
              Icons.warning_amber_rounded,
              Colors.orange,
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: _buildStatCard(
              'Avg Response',
              _avgResponseTime,
              Icons.access_time_rounded,
              Colors.blue,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatCard(String label, String value, IconData icon, Color color) {
    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, color: color, size: 32),
            const SizedBox(height: 8),
            Text(
              value,
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: color,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 11,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPerformanceCard() {
    Color scoreColor;
    String scoreLabel;

    if (_performanceScore >= 80) {
      scoreColor = Colors.green;
      scoreLabel = 'Excellent';
    } else if (_performanceScore >= 60) {
      scoreColor = Colors.blue;
      scoreLabel = 'Good';
    } else if (_performanceScore >= 40) {
      scoreColor = Colors.orange;
      scoreLabel = 'Average';
    } else {
      scoreColor = Colors.red;
      scoreLabel = 'Needs Improvement';
    }

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.trending_up, color: scoreColor),
              const SizedBox(width: 8),
              const Text(
                'Performance Score',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${_performanceScore.toStringAsFixed(0)}/100',
                      style: TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.bold,
                        color: scoreColor,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      scoreLabel,
                      style: TextStyle(
                        fontSize: 16,
                        color: scoreColor,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: 100,
                height: 100,
                child: Stack(
                  children: [
                    Center(
                      child: SizedBox(
                        width: 100,
                        height: 100,
                        child: CircularProgressIndicator(
                          value: _performanceScore / 100,
                          strokeWidth: 10,
                          backgroundColor: Colors.grey[200],
                          valueColor: AlwaysStoppedAnimation<Color>(scoreColor),
                        ),
                      ),
                    ),
                    Center(
                      child: Icon(
                        _performanceScore >= 80
                            ? Icons.star
                            : _performanceScore >= 60
                                ? Icons.thumb_up
                                : Icons.trending_up,
                        color: scoreColor,
                        size: 40,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          _buildPerformanceMetric('Resolution Rate', _totalResolved > 0 ? 'High' : 'Low'),
          _buildPerformanceMetric('Response Time', _getResponseRating()),
          _buildPerformanceMetric('Workload', _totalActive <= 2 ? 'Optimal' : 'Heavy'),
        ],
      ),
    );
  }

  Widget _buildPerformanceMetric(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.grey[700],
              fontSize: 14,
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
        ],
      ),
    );
  }

  String _getResponseRating() {
    if (_avgResponseTime == 'N/A') return 'No data';
    final avgMin = int.tryParse(_avgResponseTime.replaceAll(' min', '')) ?? 60;
    if (avgMin <= 5) return 'Excellent';
    if (avgMin <= 10) return 'Good';
    if (avgMin <= 15) return 'Average';
    return 'Slow';
  }

  Widget _buildActiveFaultsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.warning_amber_rounded, color: Colors.orange[700]),
              const SizedBox(width: 8),
              const Text(
                'Active Faults',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.orange[100],
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _totalActive.toString(),
                  style: TextStyle(
                    color: Colors.orange[900],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _activeFaults.isEmpty
              ? _buildEmptyState('No active faults', Icons.check_circle, Colors.green)
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _activeFaults.length,
                  itemBuilder: (context, index) {
                    return _buildFaultCard(_activeFaults[index], true);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildResolvedFaultsSection() {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle, color: Colors.green[700]),
              const SizedBox(width: 8),
              const Text(
                'Recently Resolved',
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _resolvedFaults.isEmpty
              ? _buildEmptyState('No resolved faults yet', Icons.history, Colors.grey)
              : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: _resolvedFaults.length,
                  itemBuilder: (context, index) {
                    return _buildFaultCard(_resolvedFaults[index], false);
                  },
                ),
        ],
      ),
    );
  }

  Widget _buildFaultCard(Map<String, dynamic> fault, bool isActive) {
    final pole = fault['poles'];
    final poleNumber = pole?['pole_number'] ?? 'Unknown';
    final location = pole?['location_name'] ?? 'Unknown location';
    final priority = fault['priority_score'] ?? 5;
    final faultType = _formatFaultType(fault['fault_type']);

    Color priorityColor = priority >= 9
        ? Colors.red
        : priority >= 7
            ? Colors.orange
            : Colors.yellow[700]!;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: isActive
            ? () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => FaultDetailScreen(fault: fault),
                  ),
                ).then((value) {
                  if (value == true) _loadLinemanData();
                });
              }
            : null,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: priorityColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Icon(
                      isActive ? Icons.warning_amber_rounded : Icons.check_circle,
                      color: isActive ? priorityColor : Colors.green,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          poleNumber,
                          style: const TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Icon(Icons.location_on, size: 14, color: Colors.grey[600]),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                location,
                                style: TextStyle(
                                  color: Colors.grey[600],
                                  fontSize: 13,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  if (isActive)
                    Icon(Icons.chevron_right, color: Colors.grey[400]),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  _buildChip('Priority: $priority/10', priorityColor),
                  const SizedBox(width: 8),
                  _buildChip(faultType, Colors.blue[700]!),
                ],
              ),
              if (!isActive && fault['resolved_at'] != null) ...[
                const SizedBox(height: 8),
                Text(
                  'Resolved: ${_formatDateTime(fault['resolved_at'])}',
                  style: TextStyle(
                    color: Colors.green[700],
                    fontSize: 12,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildChip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildEmptyState(String message, IconData icon, Color color) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          children: [
            Icon(icon, size: 64, color: color.withOpacity(0.5)),
            const SizedBox(height: 16),
            Text(
              message,
              style: TextStyle(
                color: Colors.grey[600],
                fontSize: 16,
              ),
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
      'current_leakage': 'Current Leak',
      'wire_break': 'Wire Break',
      'overload': 'Overload',
    };
    return types[type] ?? type;
  }

  String _formatDateTime(String? dateTime) {
    if (dateTime == null) return 'Unknown';
    try {
      final date = DateTime.parse(dateTime);
      return DateFormat('MMM dd, hh:mm a').format(date);
    } catch (e) {
      return 'Unknown';
    }
  }
}