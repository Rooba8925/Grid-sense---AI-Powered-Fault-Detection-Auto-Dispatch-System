import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/lineman.dart';
import '../models/fault.dart';

class SupabaseService {
  final SupabaseClient _client = Supabase.instance.client;

  // Get current lineman profile
  Future<Lineman?> getLinemanProfile() async {
    try {
      final userId = _client.auth.currentUser?.id;
      if (userId == null) return null;

      final response = await _client
          .from('linemen')
          .select()
          .eq('auth_id', userId)
          .single();

      return Lineman.fromJson(response);
    } catch (e) {
      print('Error fetching lineman profile: $e');
      return null;
    }
  }

  // Get faults assigned to current lineman
  Future<List<Fault>> getAssignedFaults(String linemanId) async {
    try {
      print('Fetching faults for lineman ID: $linemanId');
      
      final response = await _client
          .from('faults')
          .select('''
            id,
            pole_id,
            fault_type,
            priority_score,
            voltage_drop,
            current_spike,
            vibration_detected,
            status,
            detected_at,
            assigned_to,
            resolved_at,
            resolution_notes,
            poles!faults_pole_id_fkey (
              pole_number,
              location_name,
              latitude,
              longitude
            )
          ''')
          .eq('assigned_to', linemanId)
          .neq('status', 'resolved')
          .order('priority_score', ascending: false);

      print('Faults query response count: ${response.length}');
      
      final faultsList = (response as List)
          .map((fault) => Fault.fromJson(fault))
          .toList();
      
      print('Parsed ${faultsList.length} faults');
      
      return faultsList;
    } catch (e) {
      print('Error fetching assigned faults: $e');
      print('Error type: ${e.runtimeType}');
      return [];
    }
  }

  // Update lineman GPS location
  Future<bool> updateLocation(String linemanId, double lat, double lng) async {
    try {
      await _client
          .from('linemen')
          .update({
            'current_latitude': lat,
            'current_longitude': lng,
            'last_location_update': DateTime.now().toIso8601String(),
          })
          .eq('id', linemanId);
      return true;
    } catch (e) {
      print('Error updating location: $e');
      return false;
    }
  }

  // Update lineman availability status
  Future<bool> updateAvailability(String linemanId, String status) async {
    try {
      await _client
          .from('linemen')
          .update({'availability_status': status})
          .eq('id', linemanId);
      return true;
    } catch (e) {
      print('Error updating availability: $e');
      return false;
    }
  }

  // Mark fault as resolved (database trigger handles counter increment)
  Future<bool> markFaultResolved(
    String faultId,
    String notes,
  ) async {
    try {
      print('Marking fault $faultId as resolved');
      
      await _client
          .from('faults')
          .update({
            'status': 'resolved',
            'resolved_at': DateTime.now().toIso8601String(),
            'resolution_notes': notes,
          })
          .eq('id', faultId);
      
      print('Fault marked as resolved successfully');
      return true;
    } catch (e) {
      print('Error marking fault resolved: $e');
      return false;
    }
  }
}