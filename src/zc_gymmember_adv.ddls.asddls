@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Gym Analytics Projection View'
@Metadata.allowExtensions: true
@Search.searchable: true
define root view entity ZC_GymMember_Adv
  provider contract transactional_query
  as projection on ZI_GymMember_Adv
{
  key member_id,
  @Search.defaultSearchElement: true
  @Search.fuzzinessThreshold: 0.8
  full_name,
  member_type,
  attendance_rate,
  last_visit_days,
  PredictionScore,
  StatusCriticality
}
