local rules = require("rules")

assert(rules.goal_after_hazard(true, true) == false)
assert(rules.goal_after_hazard(false, true) == true)
assert(rules.goal_after_hazard(false, false) == nil)

print("LOVE rules: hazard loss wins over a simultaneous goal")
