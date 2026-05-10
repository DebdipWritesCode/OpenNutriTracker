import 'package:opennutritracker/core/data/data_source/remote_search_cache_data_source.dart';
import 'package:opennutritracker/core/data/data_source/custom_meal_data_source.dart';
import 'package:opennutritracker/core/data/dbo/meal_dbo.dart';
import 'package:opennutritracker/features/add_meal/data/repository/products_repository.dart';
import 'package:opennutritracker/features/add_meal/domain/entity/meal_entity.dart';

class SearchProductByBarcodeUseCase {
  final ProductsRepository _productsRepository;
  final CustomMealDataSource _customMealDataSource;
  final RemoteSearchCacheDataSource _cachedOffMealDataSource;

  SearchProductByBarcodeUseCase(
    this._productsRepository,
    this._customMealDataSource,
    this._cachedOffMealDataSource,
  );

  /// Resolution order:
  ///   1. User's own custom meals — they take priority over remote data
  ///      because the user explicitly created/imported them
  ///   2. Cached OFF lookup from a previous successful network hit —
  ///      makes repeat scans instant and works offline
  ///   3. Live OFF API call — only when nothing local matches; the
  ///      successful result is then written to the cache for next time
  Future<MealEntity> searchProductByBarcode(String barcode) async {
    final customMatch = _customMealDataSource
        .getAllCustomMeals()
        .where((dbo) => dbo.code != null && dbo.code == barcode)
        .firstOrNull;
    if (customMatch != null) {
      return MealEntity.fromMealDBO(customMatch);
    }

    final cachedMatch = _cachedOffMealDataSource.getByBarcode(barcode);
    if (cachedMatch != null) {
      return MealEntity.fromMealDBO(cachedMatch);
    }

    final remote = await _productsRepository.getOFFProductByBarcode(barcode);
    await _cachedOffMealDataSource.cache(MealDBO.fromMealEntity(remote));
    return remote;
  }
}
