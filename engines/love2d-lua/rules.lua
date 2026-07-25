local rules = {}

function rules.goal_after_hazard(hit_hazard, reached_goal)
  if hit_hazard then return false end
  if reached_goal then return true end
  return nil
end

return rules
