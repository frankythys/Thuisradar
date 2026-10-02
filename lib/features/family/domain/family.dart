class Family {
  const Family({required this.id, required this.name, required this.inviteCode});

  factory Family.fromJson(Map<String, dynamic> json) => Family(
    id: json['id'] as String,
    name: json['name'] as String,
    inviteCode: json['invite_code'] as String,
  );

  final String id;
  final String name;
  final String inviteCode;
}
