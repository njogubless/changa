import '../../../../core/constants/api_constants.dart';
import '../../../../core/network/api_client.dart';
import '../models/payment_models.dart';

class PaymentsRepository {
  final ApiClient _api;
  PaymentsRepository(this._api);

  Future<ContributionModel> contributeMpesa({
    required String projectId,
    required double amount,
    required String phone,
  }) async {
    final response = await _api.post(
      ApiConstants.contributeMpesa,
      data: {
        'project_id': projectId,
        'amount': amount,
        'phone': phone,
      },
    );
    return ContributionModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ContributionModel> contributeAirtel({
    required String projectId,
    required double amount,
    required String phone,
  }) async {
    final response = await _api.post(
      ApiConstants.contributeAirtel,
      data: {
        'project_id': projectId,
        'amount': amount,
        'phone': phone,
      },
    );
    return ContributionModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<ContributionStatusModel> getStatus(String reference) async {
    final response =
        await _api.get(ApiConstants.contributionStatus(reference));
    return ContributionStatusModel.fromJson(
        response.data as Map<String, dynamic>);
  }

  Future<List<ContributionModel>> getMyContributions() async {
    final response = await _api.get(ApiConstants.myContributions);
    return (response.data as List)
        .map((e) => ContributionModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }
}
