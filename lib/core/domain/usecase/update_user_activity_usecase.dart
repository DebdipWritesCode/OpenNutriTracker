import 'package:opennutritracker/core/data/repository/user_activity_repository.dart';
import 'package:opennutritracker/core/domain/entity/user_activity_entity.dart';
import 'package:opennutritracker/core/domain/usecase/get_user_usecase.dart';
import 'package:opennutritracker/core/utils/calc/met_calc.dart';

class UpdateUserActivityUsecase {
  final UserActivityRepository _userActivityRepository;
  final GetUserUsecase _getUserUsecase;

  UpdateUserActivityUsecase(
    this._userActivityRepository,
    this._getUserUsecase,
  );

  Future<UserActivityEntity?> updateUserActivity(
    UserActivityEntity activity,
    double newDuration,
  ) async {
    final user = await _getUserUsecase.getUserData();
    final newBurnedKcal = METCalc.getTotalBurnedKcal(
      user,
      activity.physicalActivityEntity,
      newDuration,
    );
    return _userActivityRepository.updateUserActivity(
      activity.id,
      newDuration,
      newBurnedKcal,
    );
  }
}
