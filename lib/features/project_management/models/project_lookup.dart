part of 'project_management_models.dart';

/// Lightweight project row for the project-picker dropdown.
class ProjectLookup {
  final int? projectId;
  final String projectName;
  final String projectDocumentNo;
  final String projectStatus;

  const ProjectLookup({
    required this.projectId,
    required this.projectName,
    required this.projectDocumentNo,
    required this.projectStatus,
  });

  String get label {
    if (projectName.isEmpty && projectDocumentNo.isEmpty) return '—';
    if (projectDocumentNo.isEmpty) return projectName;
    if (projectName.isEmpty) return projectDocumentNo;
    return '$projectName · $projectDocumentNo';
  }

  factory ProjectLookup.fromJson(Map<String, dynamic> j) => ProjectLookup(
        projectId: _toIntOrNull(j['project_id']),
        projectName: _toStr(j['project_name']),
        projectDocumentNo: _toStr(j['project_documentno']),
        projectStatus: _toStr(j['project_status']),
      );
}
