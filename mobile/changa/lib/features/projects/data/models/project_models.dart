enum ProjectStatus { active, completed, cancelled, paused }

enum ProjectVisibility { public, private }

class ProjectModel {
  final String id;
  final String ownerId;
  final String title;
  final String? description;
  final String? coverImageUrl;
  final double targetAmount;
  final double raisedAmount;
  final String currency;
  final ProjectVisibility visibility;
  final ProjectStatus status;
  final bool isAnonymous;
  final DateTime? deadline;
  final double percentageFunded;
  final double deficit;
  final bool isFunded;
  final int contributorCount;
  final DateTime createdAt;

  const ProjectModel({
    required this.id,
    required this.ownerId,
    required this.title,
    this.description,
    this.coverImageUrl,
    required this.targetAmount,
    required this.raisedAmount,
    required this.currency,
    required this.visibility,
    required this.status,
    required this.isAnonymous,
    this.deadline,
    required this.percentageFunded,
    required this.deficit,
    required this.isFunded,
    required this.contributorCount,
    required this.createdAt,
  });

  factory ProjectModel.fromJson(Map<String, dynamic> json) => ProjectModel(
        id: json['id'] as String,
        ownerId: json['owner_id'] as String,
        title: json['title'] as String,
        description: json['description'] as String?,
        coverImageUrl: json['cover_image_url'] as String?,
        targetAmount: (json['target_amount'] as num).toDouble(),
        raisedAmount: (json['raised_amount'] as num).toDouble(),
        currency: json['currency'] as String? ?? 'KES',
        visibility: ProjectVisibility.values.firstWhere(
          (e) => e.name == json['visibility'],
          orElse: () => ProjectVisibility.public,
        ),
        status: ProjectStatus.values.firstWhere(
          (e) => e.name == json['status'],
          orElse: () => ProjectStatus.active,
        ),
        isAnonymous: json['is_anonymous'] as bool? ?? false,
        deadline: json['deadline'] != null
            ? DateTime.parse(json['deadline'] as String)
            : null,
        percentageFunded: (json['percentage_funded'] as num).toDouble(),
        deficit: (json['deficit'] as num).toDouble(),
        isFunded: json['is_funded'] as bool? ?? false,
        contributorCount: json['contributor_count'] as int? ?? 0,
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}

class ProjectListResponse {
  final List<ProjectModel> items;
  final int total;
  final int page;
  final int pages;

  const ProjectListResponse({
    required this.items,
    required this.total,
    required this.page,
    required this.pages,
  });

  factory ProjectListResponse.fromJson(Map<String, dynamic> json) =>
      ProjectListResponse(
        items: (json['items'] as List)
            .map((e) => ProjectModel.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
        page: json['page'] as int,
        pages: json['pages'] as int,
      );
}

class ContributorModel {
  final String userId;
  final String? fullName;
  final double total;
  final double percentage;

  const ContributorModel({
    required this.userId,
    this.fullName,
    required this.total,
    required this.percentage,
  });

  factory ContributorModel.fromJson(Map<String, dynamic> json) =>
      ContributorModel(
        userId: json['user_id'] as String,
        fullName: json['full_name'] as String?,
        total: (json['total'] as num).toDouble(),
        percentage: (json['percentage'] as num).toDouble(),
      );
}
