class CameraRegisterInput {
  final String displayName;
  final String host;
  final int port;
  final String path;
  final String username;
  final String password;
  final String? petId;

  const CameraRegisterInput({
    required this.displayName,
    required this.host,
    this.port = 554,
    this.path = 'stream1',
    required this.username,
    required this.password,
    this.petId,
  });

  Map<String, dynamic> toJson() => {
        'display_name': displayName,
        'host': host,
        'port': port,
        'path': path,
        'username': username,
        'password': password,
        if (petId != null) 'pet_id': petId,
      };
}
