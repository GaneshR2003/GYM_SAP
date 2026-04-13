@AccessControl.authorizationCheck: #NOT_REQUIRED
@EndUserText.label: 'Gym Analytics Base Interface View'
define root view entity ZI_GymMember_Adv
  as select from zgym_members
{
  key member_id,
  full_name,
  member_type,
  attendance_rate,
  last_visit_days,
  
  retention_score as PredictionScore,
  criticality     as StatusCriticality
}
