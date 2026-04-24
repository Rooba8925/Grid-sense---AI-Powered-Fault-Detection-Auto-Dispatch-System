import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:intl/intl.dart';

class FaultDetailScreen extends StatefulWidget {
  final Map<String, dynamic> fault;

  const FaultDetailScreen({Key? key, required this.fault}) : super(key: key);

  @override
  State<FaultDetailScreen> createState() => _FaultDetailScreenState();
}

class _FaultDetailScreenState extends State<FaultDetailScreen> {
  final _notesController = TextEditingController();
  bool _isResolving = false;
  
  // Pole details
  String _poleNumber = 'Loading...';
  String _locationName = 'Loading...';
  double? _latitude;
  double? _longitude;

  @override
  void initState() {
    super.initState();
    _loadPoleDetails();
  }

  @override
  void dispose() {
    _notesController.dispose();
    super.dispose();
  }

  // Load pole details from database
  Future<void> _loadPoleDetails() async {
    try {
      final response = await Supabase.instance.client
          .from('poles')
          .select('pole_number, location_name, latitude, longitude')
          .eq('id', widget.fault['pole_id'])
          .single();

      setState(() {
        _poleNumber = response['pole_number'] ?? 'Unknown';
        _locationName = response['location_name'] ?? 'Unknown Location';
        _latitude = response['latitude'];
        _longitude = response['longitude'];
      });
    } catch (e) {
      print('Error loading pole details: $e');
    }
  }

  // Format fault type for display
  String _formatFaultType(String? type) {
    if (type == null) return 'Unknown';
    
    final types = {
      'voltage_drop': 'Voltage Drop',
      'current_leakage': 'Current Leakage',
      'wire_break': 'Wire Break',
      'overload': 'Overload',
      'transformer_fault': 'Transformer Fault',
    };
    
    return types[type] ?? type;
  }

  // Get priority badge color
  Color _getPriorityColor(int priority) {
    if (priority >= 9) return Colors.red;
    if (priority >= 7) return Colors.orange;
    if (priority >= 5) return Colors.yellow[700]!;
    return Colors.green;
  }

  // Get priority label
  String _getPriorityLabel(int priority) {
    if (priority >= 9) return 'CRITICAL';
    if (priority >= 7) return 'HIGH';
    if (priority >= 5) return 'MEDIUM';
    return 'LOW';
  }

  // Navigate to fault location
  Future<void> _navigateToLocation() async {
    if (_latitude == null || _longitude == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Location coordinates not available')),
      );
      return;
    }

    // Google Maps URL
    final url = 'https://www.google.com/maps/dir/?api=1&destination=$_latitude,$_longitude';

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else {
        throw 'Could not launch maps';
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error opening maps: $e')),
      );
    }
  }

  // Mark fault as resolved
  Future<void> _markAsResolved() async {
  // Show confirmation dialog
  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: const Text('Mark as Resolved'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Are you sure the fault has been fixed?'),
          const SizedBox(height: 15),
          TextField(
            controller: _notesController,
            decoration: const InputDecoration(
              labelText: 'Resolution Notes (Optional)',
              border: OutlineInputBorder(),
            ),
            maxLines: 3,
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
          child: const Text('Confirm Resolved'),
        ),
      ],
    ),
  );

  if (confirmed != true) return;

  setState(() => _isResolving = true);

  try {
    // ✅ CRITICAL: Get current timestamp in ISO format
    final now = DateTime.now().toUtc().toIso8601String();

    // ✅ UPDATE FAULT STATUS
    await Supabase.instance.client
        .from('faults')
        .update({
          'status': 'resolved',
          'resolved_at': now,
          'resolution_notes': _notesController.text.trim().isEmpty
              ? 'Fault resolved by lineman'
              : _notesController.text.trim(),
        })
        .eq('id', widget.fault['id']);

    // ✅ FORCE DATABASE TRIGGER TO COMPLETE
    await Future.delayed(const Duration(milliseconds: 500));

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('✅ Fault marked as resolved!'),
          backgroundColor: Colors.green,
        ),
      );

      // ✅ CRITICAL: triggers dashboard refresh
      Navigator.pop(context, true);
    }
  } catch (e) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  } finally {
    if (mounted) {
      setState(() => _isResolving = false);
    }
  }
}

  @override
  Widget build(BuildContext context) {
    final priority = widget.fault['priority_score'] ?? 5;
    final createdAt = widget.fault['created_at'];
    final formattedTime = createdAt != null
        ? DateFormat('MMM dd, yyyy • hh:mm a').format(DateTime.parse(createdAt))
        : 'Unknown time';

    return Scaffold(
      appBar: AppBar(
        title: Text(_poleNumber),
        backgroundColor: Colors.blue[700],
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Priority Banner
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: _getPriorityColor(priority),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                children: [
                  const Icon(Icons.warning_amber, size: 50, color: Colors.white),
                  const SizedBox(height: 10),
                  Text(
                    _getPriorityLabel(priority),
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                  Text(
                    _formatFaultType(widget.fault['fault_type']),
                    style: const TextStyle(
                      fontSize: 18,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // Fault Details
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Location Card
                  _buildInfoCard(
                    icon: Icons.location_on,
                    title: 'Location',
                    value: _locationName,
                    color: Colors.blue,
                  ),
                  const SizedBox(height: 12),

                  // Pole Number Card
                  _buildInfoCard(
                    icon: Icons.electrical_services,
                    title: 'Pole Number',
                    value: _poleNumber,
                    color: Colors.green,
                  ),
                  const SizedBox(height: 12),

                  // Time Card
                  _buildInfoCard(
                    icon: Icons.access_time,
                    title: 'Detected At',
                    value: formattedTime,
                    color: Colors.orange,
                  ),
                  const SizedBox(height: 12),

                  // Priority Score
                  _buildInfoCard(
                    icon: Icons.priority_high,
                    title: 'Priority Score',
                    value: '$priority/10',
                    color: _getPriorityColor(priority),
                  ),

                  // Technical Details
                  if (widget.fault['voltage_drop'] != null ||
                      widget.fault['current_spike'] != null)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const SizedBox(height: 20),
                        const Text(
                          'Technical Details',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(color: Colors.grey[300]!),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (widget.fault['voltage_drop'] != null)
                                _buildTechnicalRow(
                                  'Voltage Drop:',
                                  '${widget.fault['voltage_drop'].toStringAsFixed(1)} V',
                                ),
                              if (widget.fault['current_spike'] != null)
                                _buildTechnicalRow(
                                  'Current Spike:',
                                  '${widget.fault['current_spike'].toStringAsFixed(2)} A',
                                ),
                              if (widget.fault['vibration_detected'] != null)
                                _buildTechnicalRow(
                                  'Vibration:',
                                  widget.fault['vibration_detected'] == true
                                      ? 'Detected'
                                      : 'None',
                                ),
                              if (widget.fault['weather_condition'] != null)
                                _buildTechnicalRow(
                                  'Weather:',
                                  widget.fault['weather_condition'].toString().toUpperCase(),
                                ),
                            ],
                          ),
                        ),
                      ],
                    ),

                  const SizedBox(height: 30),

                  // Action Buttons
                  ElevatedButton.icon(
                    onPressed: _navigateToLocation,
                    icon: const Icon(Icons.navigation, size: 24),
                    label: const Text(
                      'Navigate to Location',
                      style: TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue[700],
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  ElevatedButton.icon(
                    onPressed: _isResolving ? null : _markAsResolved,
                    icon: _isResolving
                        ? const SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Icon(Icons.check_circle, size: 24),
                    label: Text(
                      _isResolving ? 'Resolving...' : 'Mark as Resolved',
                      style: const TextStyle(fontSize: 16),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.green,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  // Build info card widget
  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String value,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 28),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Build technical detail row
  Widget _buildTechnicalRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.black87,
            ),
          ),
          Text(
            value,
            style: TextStyle(
              color: Colors.grey[700],
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }
}