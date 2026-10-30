enum UserRole {
  admin('Direction & Administration', 'ADMIN'),
  teacher('Enseignant', 'TEACHER'),
  parent('Parent d\'Élève', 'PARENT'),
  student('Élève', 'STUDENT'),
  unknown('Utilisateur', 'USER');

  final String label;
  final String code;
  const UserRole(this.label, this.code);
}

class UserModel {
  final int id;
  final String name;
  final String email;
  final UserRole role;
  final String? matricule;
  final String? avatarUrl;
  final String? phone;

  UserModel({
    required this.id,
    required this.name,
    required this.email,
    required this.role,
    this.matricule,
    this.avatarUrl,
    this.phone,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    final rawRole = (json['role'] ?? json['type'] ?? json['role_name'] ?? '').toString().toUpperCase();
    UserRole parsedRole = UserRole.unknown;

    if (rawRole.contains('ADMIN') || rawRole.contains('DIRECTION') || rawRole.contains('PROVISEUR')) {
      parsedRole = UserRole.admin;
    } else if (rawRole.contains('TEACHER') || rawRole.contains('ENSEIGNANT') || rawRole.contains('PROF')) {
      parsedRole = UserRole.teacher;
    } else if (rawRole.contains('PARENT') || rawRole.contains('TUTEUR') || rawRole.contains('GUARDIAN')) {
      parsedRole = UserRole.parent;
    } else if (rawRole.contains('STUDENT') || rawRole.contains('ELEVE')) {
      parsedRole = UserRole.student;
    }

    return UserModel(
      id: json['id'] is int ? json['id'] : int.tryParse(json['id']?.toString() ?? '0') ?? 0,
      name: json['name']?.toString() ?? '',
      email: json['email']?.toString() ?? '',
      role: parsedRole,
      matricule: json['matricule']?.toString(),
      avatarUrl: json['avatar_url']?.toString(),
      phone: json['phone']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'email': email,
    'role': role.code,
    'matricule': matricule,
    'avatar_url': avatarUrl,
    'phone': phone,
  };
}

