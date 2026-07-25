#ifndef KOFUN_RULES_H
#define KOFUN_RULES_H

#include <stdbool.h>

typedef enum {
    KOFUN_OUTCOME_PENDING,
    KOFUN_OUTCOME_WON,
    KOFUN_OUTCOME_LOST
} KofunOutcome;

KofunOutcome kofun_resolve_goal_after_hazard(bool hit_hazard, bool reached_goal);

#endif
