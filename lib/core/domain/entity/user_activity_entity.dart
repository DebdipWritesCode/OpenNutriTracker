import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/domain/entity/activity_log_details.dart';
import 'package:opennutritracker/core/domain/entity/physical_activity_entity.dart';

class UserActivityEntity extends Equatable {
  final String id;
  final double duration;
  final double burnedKcal;
  final DateTime date;

  final PhysicalActivityEntity physicalActivityEntity;

  /// Optional direct kcal value entered by the user for a Custom activity.
  /// When set, this is the source of truth and [burnedKcal] mirrors it so
  /// the aggregation layer (which sums [burnedKcal] across the day) keeps
  /// working unchanged. See `UserActivityDBO.userKcal` for the persistence
  /// reasoning.
  final double? userKcal;
  final String? detailsJson;

  const UserActivityEntity(
    this.id,
    this.duration,
    this.burnedKcal,
    this.date,
    this.physicalActivityEntity, {
    this.userKcal,
    this.detailsJson,
  });

  factory UserActivityEntity.fromUserActivityDBO(UserActivityDBO activityDBO) {
    return UserActivityEntity(
      activityDBO.id,
      activityDBO.duration,
      activityDBO.burnedKcal,
      activityDBO.date,
      PhysicalActivityEntity.fromPhysicalActivityDBO(
        activityDBO.physicalActivityDBO,
      ),
      userKcal: activityDBO.userKcal,
      detailsJson: activityDBO.detailsJson,
    );
  }

  /// The kcal value to display and aggregate for this activity. Prefers
  /// the user-entered value when one is present (Custom activities),
  /// otherwise falls back to the MET-computed [burnedKcal].
  double get effectiveBurnedKcal => userKcal ?? burnedKcal;
  ActivityLogDetails? get details => ActivityLogDetails.tryParse(detailsJson);

  @override
  List<Object?> get props => [
    id,
    duration,
    burnedKcal,
    date,
    userKcal,
    detailsJson,
  ];

  static IconData getIconData() => Icons.directions_run_outlined;
}
