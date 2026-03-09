class SmsJob {
  final int id;
  final String phone;
  final String message;

  SmsJob({
    required this.id,
    required this.phone,
    required this.message,
  });

  factory SmsJob.fromJson(Map<String, dynamic> json) {
    return SmsJob(
      id: json['id'],
      phone: json['phone'],
      message: json['message'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'phone': phone,
      'message': message,
    };
  }
}
