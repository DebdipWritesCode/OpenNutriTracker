import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/data/dbo/physical_activity_dbo.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';

part 'user_activity_dbo.g.dart';

@HiveType(typeId: 10)
@JsonSerializable()
class UserActivityDBO extends HiveObject {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final double duration;
  @HiveField(2)
  final double burnedKcal;
  @HiveField(3)
  final DateTime date;

  @HiveField(4)
  final PhysicalActivityDBO physicalActivityDBO;

  /// Direct kcal value entered by the user for a Custom-type activity.
  /// When non-null this takes precedence over the MET-computed value: the
  /// aggregation layer keeps reading [burnedKcal], which is set to match
  /// [userKcal] at save time so existing daily totals stay consistent.
  /// Older diary entries written before this field existed simply carry
  /// `null` here and behave exactly as they did before.
  @HiveField(5)
  final double? userKcal;

  /// Optional version-tolerant JSON metadata for structured workout details.
  @HiveField(6)
  final String? detailsJson;

  UserActivityDBO(
    this.id,
    this.duration,
    this.burnedKcal,
    this.date,
    this.physicalActivityDBO, {
    this.userKcal,
    this.detailsJson,
  });

  factory UserActivityDBO.fromUserActivityEntity(
    UserActivityEntity userActivityEntity,
  ) {
    return UserActivityDBO(
      userActivityEntity.id,
      userActivityEntity.duration,
      userActivityEntity.burnedKcal,
      userActivityEntity.date,
      PhysicalActivityDBO.fromPhysicalActivityEntity(
        userActivityEntity.physicalActivityEntity,
      ),
      userKcal: userActivityEntity.userKcal,
      detailsJson: userActivityEntity.detailsJson,
    );
  }

  factory UserActivityDBO.fromJson(Map<String, dynamic> json) =>
      _$UserActivityDBOFromJson(json);

  Map<String, dynamic> toJson() => _$UserActivityDBOToJson(this);
}
