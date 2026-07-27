import 'package:hive_ce/hive.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:opennutritracker/core/data/dbo/intake_type_dbo.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/core/domain/entity/intake_entity.dart';

part 'intake_dbo.g.dart';

@HiveType(typeId: 0)
@JsonSerializable()
class IntakeDBO extends HiveObject {
  @HiveField(0)
  String id;
  @HiveField(1)
  String unit;
  @HiveField(2)
  double amount;
  @HiveField(3)
  IntakeTypeDBO type;

  @HiveField(4)
  MealDBO meal;

  @HiveField(5)
  DateTime dateTime;

  /// Optional AI meal grouping metadata. Fields are appended so existing Hive
  /// rows remain readable without a migration.
  @HiveField(6)
  String? aiMealGroupId;

  @HiveField(7)
  DateTime? aiMealSavedAt;

  IntakeDBO({
    required this.id,
    required this.unit,
    required this.amount,
    required this.type,
    required this.meal,
    required this.dateTime,
    this.aiMealGroupId,
    this.aiMealSavedAt,
  });

  factory IntakeDBO.fromIntakeEntity(IntakeEntity entity) {
    return IntakeDBO(
      id: entity.id,
      unit: entity.unit,
      amount: entity.amount,
      type: IntakeTypeDBO.fromIntakeTypeEntity(entity.type),
      meal: MealDBO.fromMealEntity(entity.meal),
      dateTime: entity.dateTime,
      aiMealGroupId: entity.aiMealGroupId,
      aiMealSavedAt: entity.aiMealSavedAt,
    );
  }

  factory IntakeDBO.fromJson(Map<String, dynamic> json) =>
      _$IntakeDBOFromJson(json);

  Map<String, dynamic> toJson() => _$IntakeDBOToJson(this);
}
