#include "rules.h"

KofunOutcome kofun_resolve_goal_after_hazard(bool hit_hazard, bool reached_goal) {
    if (hit_hazard) return KOFUN_OUTCOME_LOST;
    if (reached_goal) return KOFUN_OUTCOME_WON;
    return KOFUN_OUTCOME_PENDING;
}
