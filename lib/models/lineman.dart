class Lineman {
  final String id;
  final String authId;
  final String name;
  final String phone;
  final String employeeId;
  final double? currentLatitude;
  final double? currentLongitude;
  final String availabilityStatus;
  final int totalFaultsResolved;
  final int? avgResponseTime;

  Lineman({
    required this.id,
    required this.authId,
    required this.name,
    required this.phone,
    required this.employeeId,
    this.currentLatitude,
    this.currentLongitude,
    required this.availabilityStatus,
    required this.totalFaultsResolved,
    this.avgResponseTime,
  });

  factory Lineman.fromJson(Map<String, dynamic> json) {
    return Lineman(
      id: json['id'] as String,
      authId: json['auth_id'] as String,
      name: json['name'] as String,
      phone: json['phone'] as String,
      employeeId: json['employee_id'] as String,
      currentLatitude: json['current_latitude'] as double?,
      currentLongitude: json['current_longitude'] as double?,
      availabilityStatus: json['availability_status'] as String,
      totalFaultsResolved: json['total_faults_resolved'] as int,
      avgResponseTime: json['avg_response_time'] as int?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'auth_id': authId,
      'name': name,
      'phone': phone,
      'employee_id': employeeId,
      'current_latitude': currentLatitude,
      'current_longitude': currentLongitude,
      'availability_status': availabilityStatus,
      'total_faults_resolved': totalFaultsResolved,
      'avg_response_time': avgResponseTime,
    };
  }
}