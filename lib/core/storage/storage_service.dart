import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class PersonalDetailsModel {
  final String firstName;
  final String lastName;
  final String email;
  final String phone;
  final String location;
  final String education;
  final String experience;
  final String skills;

  PersonalDetailsModel({
    required this.firstName,
    required this.lastName,
    required this.email,
    required this.phone,
    required this.location,
    required this.education,
    required this.experience,
    required this.skills,
  });

  Map<String, dynamic> toJson() => {
    'firstName': firstName,
    'lastName': lastName,
    'email': email,
    'phone': phone,
    'location': location,
    'education': education,
    'experience': experience,
    'skills': skills,
  };

  factory PersonalDetailsModel.fromJson(Map<String, dynamic> json) => PersonalDetailsModel(
    firstName: json['firstName'] ?? '',
    lastName: json['lastName'] ?? '',
    email: json['email'] ?? '',
    phone: json['phone'] ?? '',
    location: json['location'] ?? '',
    education: json['education'] ?? '',
    experience: json['experience'] ?? '',
    skills: json['skills'] ?? '',
  );
}

class StorageService {
  static const String _detailsKey = 'personal_details';
  static const String _tokenKey = 'auth_token';

  Future<void> saveDetails(PersonalDetailsModel details) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_detailsKey, jsonEncode(details.toJson()));
  }

  Future<PersonalDetailsModel?> getDetails() async {
    final prefs = await SharedPreferences.getInstance();
    final data = prefs.getString(_detailsKey);
    if (data == null) return null;
    return PersonalDetailsModel.fromJson(jsonDecode(data));
  }

  Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_tokenKey, token);
  }

  Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_tokenKey);
  }

  Future<void> clearAuth() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_tokenKey);
  }
}
