#include "rules.h"

#include <assert.h>

int main(void) {
    assert(kofun_resolve_goal_after_hazard(true, true) == KOFUN_OUTCOME_LOST);
    assert(kofun_resolve_goal_after_hazard(false, true) == KOFUN_OUTCOME_WON);
    assert(kofun_resolve_goal_after_hazard(false, false) == KOFUN_OUTCOME_PENDING);
    return 0;
}
