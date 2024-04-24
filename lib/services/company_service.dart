import 'package:kendamanomics_mobile/mixins/logger_mixin.dart';
import 'package:kendamanomics_mobile/models/company.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class CompanyService with LoggerMixin {
  final _supabase = Supabase.instance.client;
  final _companies = <Company>[];
  bool _fetched = false;

  List<Company> get companies => _companies;

  CompanyService() {
    fetchCompanies();
  }

  void fetchCompanies() async {
    try {
      if (_fetched) return;
      final data = await _supabase.rpc('fetch_all_companies');
      _companies.clear();

      for (final map in data) {
        _companies.add(Company.fromJson(json: map));
      }
      _fetched = true;
    } catch (e) {
      logE('error fetching companies ${e.toString()}');
    }
  }

  @override
  String get className => 'CompanyService';
}
