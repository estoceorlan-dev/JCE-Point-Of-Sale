import 'organization_access.dart';

class AppUser {
  const AppUser({
    required this.firebaseUid,
    required this.email,
    required this.displayName,
    required this.organizations,
  });

  final String firebaseUid;
  String get identityId => firebaseUid;
  final String email;
  final String displayName;
  final List<OrganizationAccess> organizations;

  OrganizationAccess? organizationById(String organizationId) {
    for (final organization in organizations) {
      if (organization.organization.id == organizationId) {
        return organization;
      }
    }
    return null;
  }
}
