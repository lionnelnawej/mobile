class Task {
  final int id;
  final int? stationId;
  final String title;
  final String? description;
  final String priority;
  final String status;
  final bool isGlobal;
  final DateTime? startDate;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final double progress;
  final bool isOverdue;
  final List<Subtask> subtasks;
  final Station? station;

  Task({
    required this.id,
    this.stationId,
    required this.title,
    this.description,
    required this.priority,
    required this.status,
    required this.isGlobal,
    this.startDate,
    this.dueDate,
    this.completedAt,
    required this.progress,
    required this.isOverdue,
    required this.subtasks,
    this.station,
  });

  factory Task.fromJson(Map<String, dynamic> json) {
    double progressValue = (json['progress'] ?? 0).toDouble();
    // Si le backend renvoie un pourcentage (ex: 50) au lieu d'une fraction (ex: 0.5)
    if (progressValue > 1.0) {
      progressValue = progressValue / 100.0;
    }

    return Task(
      id: json['id'],
      stationId: json['station_id'],
      title: json['title'] ?? '',
      description: json['description'],
      priority: json['priority'] ?? 'medium',
      status: json['status'] ?? 'pending',
      isGlobal: json['is_global'] ?? false,
      startDate: json['start_date'] != null ? DateTime.parse(json['start_date']) : null,
      dueDate: json['due_date'] != null ? DateTime.parse(json['due_date']) : null,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
      progress: progressValue,
      isOverdue: json['is_overdue'] ?? false,
      subtasks: (json['subtasks'] as List? ?? []).map((e) => Subtask.fromJson(e)).toList(),
      station: json['station'] != null ? Station.fromJson(json['station']) : null,
    );
  }
}

class Subtask {
  final int id;
  final int taskId;
  final String title;
  final bool isCompleted;
  final DateTime? completedAt;

  Subtask({
    required this.id,
    required this.taskId,
    required this.title,
    required this.isCompleted,
    this.completedAt,
  });

  factory Subtask.fromJson(Map<String, dynamic> json) {
    return Subtask(
      id: json['id'],
      taskId: json['task_id'],
      title: json['title'] ?? '',
      isCompleted: json['is_completed'] ?? false,
      completedAt: json['completed_at'] != null ? DateTime.parse(json['completed_at']) : null,
    );
  }
}

class Station {
  final int id;
  final String name;
  final String code;
  final String? type;
  final String? adresse;
  final String? phone;
  final String status;

  Station({
    required this.id,
    required this.name,
    required this.code,
    this.type,
    this.adresse,
    this.phone,
    required this.status,
  });

  factory Station.fromJson(Map<String, dynamic> json) {
    return Station(
      id: json['id'],
      name: json['name'] ?? '',
      code: json['code'] ?? '',
      type: json['type'],
      adresse: json['adresse'],
      phone: json['phone'],
      status: json['status'] ?? 'actif',
    );
  }
}
