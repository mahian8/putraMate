enum UserRole { student, counsellor, admin }

class UserProfile {
  UserProfile({
    required this.uid,
    required this.email,
    required this.displayName,
    required this.role,
    this.photoUrl,
    this.studentId,
    this.phoneNumber,
    this.dateOfBirth,
    this.gender,
    this.bloodType,
    this.allergies,
    this.medicalConditions,
    this.emergencyContact,
    this.emergencyContactPhone,
    this.counsellorId,
    this.designation,
    this.expertise,
    this.isActive = true,
    this.requirePasswordChange = false,
  });

  final String uid;
  final String email;
  final String displayName;
  final UserRole role;
  final String? photoUrl;
  
  // Student details
  final String? studentId;
  final String? phoneNumber;
  final String? dateOfBirth;
  final String? gender;
  
  // Medical information
  final String? bloodType;
  final String? allergies;
  final String? medicalConditions;
  final String? emergencyContact;
  final String? emergencyContactPhone;
  
  // Counsellor details
  final String? counsellorId;
  final String? designation;
  final String? expertise;
  
  // Account status
  final bool isActive;
  final bool requirePasswordChange;

  factory UserProfile.fromJson(Map<String, dynamic> json) {
    return UserProfile(
      uid: json['uid'] as String,
      email: json['email'] as String,
      displayName: json['displayName'] as String? ?? '',
      role: _roleFromString(json['role'] as String?),
      photoUrl: json['photoUrl'] as String?,
      studentId: json['studentId'] as String?,
      phoneNumber: json['phoneNumber'] as String?,
      dateOfBirth: json['dateOfBirth'] as String?,
      gender: json['gender'] as String?,
      bloodType: json['bloodType'] as String?,
      allergies: json['allergies'] as String?,
      medicalConditions: json['medicalConditions'] as String?,
      emergencyContact: json['emergencyContact'] as String?,
      emergencyContactPhone: json['emergencyContactPhone'] as String?,
      counsellorId: json['counsellorId'] as String?,
      designation: json['designation'] as String?,
      expertise: json['expertise'] as String?,
      isActive: json['isActive'] as bool? ?? true,
      requirePasswordChange: json['requirePasswordChange'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uid': uid,
      'email': email,
      'displayName': displayName,
      'role': role.name,
      'photoUrl': photoUrl,
      if (studentId != null) 'studentId': studentId,
      if (phoneNumber != null) 'phoneNumber': phoneNumber,
      if (dateOfBirth != null) 'dateOfBirth': dateOfBirth,
      if (gender != null) 'gender': gender,
      if (bloodType != null) 'bloodType': bloodType,
      if (allergies != null) 'allergies': allergies,
      if (medicalConditions != null) 'medicalConditions': medicalConditions,
      if (emergencyContact != null) 'emergencyContact': emergencyContact,
      if (emergencyContactPhone != null) 'emergencyContactPhone': emergencyContactPhone,
      if (counsellorId != null) 'counsellorId': counsellorId,
      if (designation != null) 'designation': designation,
      if (expertise != null) 'expertise': expertise,
      'isActive': isActive,
      'requirePasswordChange': requirePasswordChange,
    };
  }

  static UserRole _roleFromString(String? value) {
    switch (value) {
      case 'counsellor':
        return UserRole.counsellor;
      case 'admin':
        return UserRole.admin;
      case 'student':
      default:
        return UserRole.student;
    }
  }
}
