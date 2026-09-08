/// Toute la configuration serveur de l'application.
///
/// C'est le seul fichier a modifier si une adresse change : l'utilisateur
/// n'a jamais a saisir d'URL de serveur dans l'application.
class AppConfig {
  /// Serveur Jellyfin. Sans slash final.
  static const String jellyfinUrl = 'https://jellyfin.fantesia.fr';

  /// Jellyseerr : demandes de films et series.
  static const String jellyseerrUrl = 'https://seer.fantesia.fr';

  /// JFA-GO : creation de compte par invitation, mot de passe oublie.
  static const String jfaGoUrl = 'https://jfa.fantesia.fr';

  /// Identite envoyee a Jellyfin (visible dans Tableau de bord > Appareils).
  static const String clientName = 'Fantesia';
  static const String clientVersion = '1.0.0';
}
