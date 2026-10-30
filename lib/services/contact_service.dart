import 'package:url_launcher/url_launcher.dart';

class ContactService {
  static const String schoolPhone = '+22790001122';
  static const String schoolWhatsapp = '22790001122';
  static const String schoolWebsite = 'http://127.0.0.1:8000';

  /// Ouvrir une discussion WhatsApp avec le secrétariat de l'école
  static Future<bool> openWhatsApp({String message = 'Bonjour CSP Les Rois du Sahel, j\'ai une question concernant la scolarité.'}) async {
    final encodedMsg = Uri.encodeComponent(message);
    final url = Uri.parse('https://wa.me/$schoolWhatsapp?text=$encodedMsg');
    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Passer un appel téléphonique au secrétariat
  static Future<bool> callSchool() async {
    final url = Uri.parse('tel:$schoolPhone');
    if (await canLaunchUrl(url)) {
      return await launchUrl(url);
    }
    return false;
  }

  /// Ouvrir le portail web de l'école
  static Future<bool> openSchoolPortal() async {
    final url = Uri.parse(schoolWebsite);
    if (await canLaunchUrl(url)) {
      return await launchUrl(url, mode: LaunchMode.externalApplication);
    }
    return false;
  }
}

