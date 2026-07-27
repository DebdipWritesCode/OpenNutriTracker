import 'package:opennutritracker/core/data/data_source/user_activity_data_source.dart';
import 'package:opennutritracker/core/data/data_source/user_activity_dbo.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';

class UserActivityRepository {
  final UserActivityDataSource _userActivityDataSource;

  UserActivityRepository(this._userActivityDataSource);

  Future<void> addUserActivity(UserActivityEntity activityEntity) async {
    final activityDBO = UserActivityDBO.fromUserActivityEntity(activityEntity);

    await _userActivityDataSource.addUserActivity(activityDBO);
  }

  Future<void> addAllUserActivityDBOs(
    List<UserActivityDBO> userActivityDBOs,
  ) async {
    await _userActivityDataSource.addAllUserActivities(userActivityDBOs);
  }

  Future<UserActivityEntity?> updateUserActivity(
    String id,
    double newDuration,
    double newBurnedKcal, {
    double? userKcal,
    String? detailsJson,
  }) async {
    final dbo = await _userActivityDataSource.updateUserActivity(
      id,
      newDuration,
      newBurnedKcal,
      userKcal: userKcal,
      detailsJson: detailsJson,
    );
    return dbo == null ? null : UserActivityEntity.fromUserActivityDBO(dbo);
  }

  Future<void> deleteUserActivity(UserActivityEntity userActivityEntity) async {
    await _userActivityDataSource.deleteIntakeFromId(userActivityEntity.id);
  }

  Future<List<UserActivityDBO>> getAllUserActivityDBO() async {
    return await _userActivityDataSource.getAllUserActivities();
  }

  Future<List<UserActivityEntity>> getAllUserActivities() async {
    final activities = await _userActivityDataSource.getAllUserActivities();
    return activities
        .map(UserActivityEntity.fromUserActivityDBO)
        .toList(growable: false);
  }

  Future<List<UserActivityEntity>> getAllUserActivityByDate(
    DateTime dateTime, {
    int dayStartOffsetHours = 0,
    int dayStartOffsetMinutes = 0,
  }) async {
    final userActivityDBOList = await _userActivityDataSource
        .getAllUserActivitiesByDate(
          dateTime,
          dayStartOffsetHours: dayStartOffsetHours,
          dayStartOffsetMinutes: dayStartOffsetMinutes,
        );

    return userActivityDBOList
        .map(
          (userActivityDBO) =>
              UserActivityEntity.fromUserActivityDBO(userActivityDBO),
        )
        .toList();
  }

  Future<List<UserActivityEntity>> getRecentUserActivity() async {
    final userActivityDBOList = await _userActivityDataSource
        .getRecentlyAddedUserActivity();
    return userActivityDBOList
        .map(
          (userActivityDBO) =>
              UserActivityEntity.fromUserActivityDBO(userActivityDBO),
        )
        .toList();
  }
}
