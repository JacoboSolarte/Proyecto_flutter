class UserProfile {
  final String id;
  final String? fullName;
  final String? phone;
  final String? organization;
  final String? department;
  final String? role;
  final String? jobTitle;
  final String? documentId;
  final String? address;
  final String? avatarUrl;
  final String? bio;
  final DateTime? updatedAt;

  UserProfile({
    required this.id,
    this.fullName,
    this.phone,
    this.organization,
    this.department,
    this.role,
    this.jobTitle,
    this.documentId,
    this.address,
    this.avatarUrl,
    this.bio,
    this.updatedAt,
  });

  factory UserProfile.fromMap(Map<String, dynamic> map) {
    DateTime? parseDate(dynamic v) {
      if (v == null) return null;
      if (v is DateTime) return v;
      return DateTime.tryParse(v.toString());
    }
    return UserProfile(
      id: map['id']?.toString() ?? '',
      fullName: map['full_name']?.toString(),
      phone: map['phone']?.toString(),
      organization: map['organization']?.toString(),
      department: map['department']?.toString(),
      role: map['role']?.toString(),
      jobTitle: map['job_title']?.toString(),
      documentId: map['document_id']?.toString(),
      address: map['address']?.toString(),
      avatarUrl: map['avatar_url']?.toString(),
      bio: map['bio']?.toString(),
      updatedAt: parseDate(map['updated_at']),
    );
  }

  Map<String, dynamic> toUpsertMap() {
    return {
      'id': id,
      'full_name': fullName,
      'phone': phone,
      'organization': organization,
      'department': department,
      'role': role,
      'job_title': jobTitle,
      'document_id': documentId,
      'address': address,
      'avatar_url': avatarUrl,
      'bio': bio,
      'updated_at': DateTime.now().toIso8601String(),
    }..removeWhere((key, value) => value == null);
  }
}