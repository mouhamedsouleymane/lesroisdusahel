import 'package:url_launcher/url_launcher.dart';

class ContactService {
  static const String schoolPhone = '+22790001122';
  static const String schoolWebsite = 'http://127.0.0.1:8000';

  /// Passer un appel téléphonique au secrétariat
  static Future<bool> callSchool() async {
    final url = Uri.parse('tel:$schoolPhone');
    if (await canLaunchUrl(url)) {
      return await launchUrl(url);
    }
    return false;
  }

  /// Ouvrir le portail web de l'école ou un document PDF officiel
  static Future<bool> openSchoolPortal({String path = ''}) async {
    final fullUrl = path.isEmpty ? schoolWebsite : '$schoolWebsite$path';
    final url = Uri.parse(fullUrl);
    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}
