#include "raylib.h"
#include "rules.h"

#include <math.h>
#include <stdbool.h>
#include <stdio.h>
#include <string.h>

#define W 960
#define H 540
#define TOP 76
#define PI2 6.28318530718f
#define ARRAY_LEN(a) ((int)(sizeof(a) / sizeof((a)[0])))

typedef enum { MENU, PLAY, RESULT } Screen;
typedef enum {
    COURIER,
    BREAKER,
    TAP_PATROL,
    SKY_DODGE,
    NEON_DASH,
    KOFUN_ORBIT,
    SNAKE,
    GAME_COUNT
} GameId;

static const char *NAMES[GAME_COUNT] = {
    "COURIER", "BREAKER", "TAP PATROL", "SKY DODGE",
    "NEON DASH", "KOFUN ORBIT", "SNAKE"
};
static const char *SUBTITLES[GAME_COUNT] = {
    "Collect 8 relics in 45 seconds", "Clear the 5 x 10 wall",
    "Tag 12 targets in 30 seconds", "Flap through 10 gates",
    "Survive the skyline for 30 seconds", "Pulse back the swarm for 30 seconds",
    "Gather 15 golden fruit"
};
static const Color ACCENTS[GAME_COUNT] = {
    {66, 230, 188, 255}, {255, 91, 132, 255}, {255, 203, 92, 255},
    {104, 184, 255, 255}, {227, 95, 255, 255}, {104, 244, 247, 255},
    {158, 242, 100, 255}
};
static const Color BG = {10, 14, 29, 255};
static const Color PANEL = {20, 27, 49, 255};
static const Color INK = {235, 242, 255, 255};
static const Color MUTED = {140, 157, 188, 255};

typedef struct {
    Vector2 player;
    Vector2 relic[8];
    bool got[8];
    Vector2 enemy[4];
    Vector2 enemyV[4];
    int score;
    float time;
} CourierState;

typedef struct {
    Rectangle paddle;
    Vector2 ball, velocity;
    bool launched;
    bool bricks[50];
    int remaining, lives;
} BreakerState;

typedef struct {
    Vector2 target, decoy;
    float targetR, decoyR, time, pulse;
    int score, misses;
} TapState;

typedef struct {
    float birdY, birdV;
    float gateX[4], gapY[4];
    bool counted[4];
    int passed;
} SkyState;

typedef struct {
    float y, vy, time, spawn;
    Rectangle obstacle[5];
    int active[5], dodged;
} DashState;

typedef struct {
    Vector2 player;
    Vector2 enemy[10], vel[10];
    int count, pulses;
    float time, cooldown, spawn;
} OrbitState;

typedef struct { int x, y; } Cell;
typedef struct {
    Cell body[450], food;
    int length, score;
    Cell dir, nextDir;
    float tick;
} SnakeState;

typedef struct {
    Screen screen;
    GameId selected, current;
    bool won;
    float worldTime, flash;
    CourierState courier;
    BreakerState breaker;
    TapState tap;
    SkyState sky;
    DashState dash;
    OrbitState orbit;
    SnakeState snake;
} App;

static float clampf(float v, float lo, float hi) {
    return v < lo ? lo : (v > hi ? hi : v);
}
static Vector2 add(Vector2 a, Vector2 b) { return (Vector2){a.x + b.x, a.y + b.y}; }
static Vector2 sub(Vector2 a, Vector2 b) { return (Vector2){a.x - b.x, a.y - b.y}; }
static Vector2 scale(Vector2 a, float s) { return (Vector2){a.x * s, a.y * s}; }
static float len(Vector2 a) { return sqrtf(a.x * a.x + a.y * a.y); }
static Vector2 norm(Vector2 a) {
    float l = len(a);
    return l > 0.001f ? scale(a, 1.0f / l) : (Vector2){0, 0};
}
static bool circle_hit(Vector2 a, float ar, Vector2 b, float br) {
    return len(sub(a, b)) < ar + br;
}
static float frand(float lo, float hi) {
    return lo + (hi - lo) * ((float)GetRandomValue(0, 10000) / 10000.0f);
}
static bool pointer_pressed(Vector2 *position) {
    static bool touchWasDown = false;
    bool touchDown = GetTouchPointCount() > 0;
    bool newTouch = touchDown && !touchWasDown;
    touchWasDown = touchDown;
    if (IsMouseButtonPressed(MOUSE_BUTTON_LEFT)) {
        *position = GetMousePosition();
        return true;
    }
    if (newTouch) {
        *position = GetTouchPosition(0);
        return true;
    }
    return false;
}
static void centered(const char *text, int y, int size, Color color) {
    DrawText(text, W / 2 - MeasureText(text, size) / 2, y, size, color);
}
static void panel(Rectangle r, Color edge) {
    DrawRectangleRounded(r, 0.12f, 8, PANEL);
    DrawRectangleRoundedLinesEx(r, 0.12f, 8, 2.0f, Fade(edge, 0.55f));
}
static void end_game(App *app, bool won) {
    app->won = won;
    app->screen = RESULT;
    app->flash = 0.25f;
}
static void draw_backdrop(const App *app) {
    ClearBackground(BG);
    for (int i = 0; i < 22; ++i) {
        float x = fmodf(i * 157.0f + app->worldTime * (9.0f + i % 3), W + 60.0f) - 30.0f;
        float y = 24.0f + (float)((i * 83) % (H - 42));
        DrawCircleV((Vector2){x, y}, i % 5 == 0 ? 2.0f : 1.0f, Fade(MUTED, 0.35f));
    }
    for (int y = TOP; y < H; y += 32) DrawLine(0, y, W, y, Fade(MUTED, 0.055f));
    for (int x = 0; x < W; x += 32) DrawLine(x, TOP, x, H, Fade(MUTED, 0.04f));
}
static void draw_header(const App *app, const char *left, const char *right) {
    Color a = ACCENTS[app->current];
    DrawRectangle(0, 0, W, TOP, (Color){14, 20, 38, 255});
    DrawRectangle(0, TOP - 3, W, 3, a);
    DrawText(NAMES[app->current], 24, 15, 27, INK);
    DrawText(left, 25, 48, 16, a);
    int rw = MeasureText(right, 21);
    DrawText(right, W - rw - 24, 27, 21, INK);
}
static void draw_help(const char *s) {
    int w = MeasureText(s, 15);
    DrawRectangleRounded((Rectangle){W / 2.0f - w / 2.0f - 12, H - 32, w + 24.0f, 24}, .45f, 8,
                         Fade(PANEL, .92f));
    DrawText(s, W / 2 - w / 2, H - 27, 15, MUTED);
}

static Vector2 spawn_clear_of(Vector2 from, float minDistance) {
    Vector2 p;
    do p = (Vector2){frand(55, W - 55), frand(TOP + 48, H - 52)};
    while (len(sub(p, from)) < minDistance);
    return p;
}

static void reset_courier(CourierState *s) {
    memset(s, 0, sizeof(*s));
    s->player = (Vector2){W / 2.0f, H / 2.0f};
    s->time = 45;
    for (int i = 0; i < 8; ++i) s->relic[i] = spawn_clear_of(s->player, 100);
    for (int i = 0; i < 4; ++i) {
        s->enemy[i] = spawn_clear_of(s->player, 190);
        float angle = frand(0, PI2);
        s->enemyV[i] = (Vector2){cosf(angle) * (85 + i * 10), sinf(angle) * (85 + i * 10)};
    }
}
static void update_courier(App *app, float dt) {
    CourierState *s = &app->courier;
    Vector2 input = {(float)(IsKeyDown(KEY_D) || IsKeyDown(KEY_RIGHT)) -
                         (float)(IsKeyDown(KEY_A) || IsKeyDown(KEY_LEFT)),
                     (float)(IsKeyDown(KEY_S) || IsKeyDown(KEY_DOWN)) -
                         (float)(IsKeyDown(KEY_W) || IsKeyDown(KEY_UP))};
    if (len(input) > 0) s->player = add(s->player, scale(norm(input), 235 * dt));
    s->player.x = clampf(s->player.x, 20, W - 20);
    s->player.y = clampf(s->player.y, TOP + 20, H - 40);
    s->time -= dt;
    for (int i = 0; i < 8; ++i) if (!s->got[i] && circle_hit(s->player, 14, s->relic[i], 11)) {
        s->got[i] = true; s->score++;
    }
    bool caught = false;
    for (int i = 0; i < 4; ++i) {
        float speed = 88.0f + i * 10.0f;
        Vector2 chase = scale(norm(sub(s->player, s->enemy[i])), 34.0f * dt);
        s->enemyV[i] = scale(norm(add(s->enemyV[i], chase)), speed);
        s->enemy[i] = add(s->enemy[i], scale(s->enemyV[i], dt));
        if (s->enemy[i].x < 16 || s->enemy[i].x > W - 16) s->enemyV[i].x *= -1;
        if (s->enemy[i].y < TOP + 16 || s->enemy[i].y > H - 38) s->enemyV[i].y *= -1;
        if (circle_hit(s->player, 14, s->enemy[i], 16)) {
            caught = true;
            break;
        }
    }
    KofunOutcome outcome = kofun_resolve_goal_after_hazard(caught, s->score == 8);
    if (outcome == KOFUN_OUTCOME_LOST) end_game(app, false);
    else if (outcome == KOFUN_OUTCOME_WON) end_game(app, true);
    else if (s->time <= 0) end_game(app, false);
}
static void draw_courier(const App *app) {
    const CourierState *s = &app->courier;
    char r[64]; snprintf(r, sizeof r, "RELICS %d/8    %02d", s->score, (int)ceilf(fmaxf(0, s->time)));
    draw_header(app, "Collect every gold relic", r);
    for (int i = 0; i < 8; ++i) if (!s->got[i]) {
        DrawPoly(s->relic[i], 6, 11, app->worldTime * 50 + i * 10, ACCENTS[COURIER]);
        DrawCircleLines((int)s->relic[i].x, (int)s->relic[i].y, 17 + sinf(app->worldTime * 4 + i) * 2,
                        Fade(ACCENTS[COURIER], .4f));
    }
    for (int i = 0; i < 4; ++i) {
        DrawPoly(s->enemy[i], 4, 17, 45 + app->worldTime * 24, (Color){255, 84, 111, 255});
        DrawCircleV(s->enemy[i], 5, BG);
    }
    DrawCircleV(s->player, 15, INK);
    DrawCircleV(s->player, 9, ACCENTS[COURIER]);
    DrawLineEx(s->player, add(s->player, (Vector2){0, -23}), 3, INK);
    draw_help("WASD / ARROWS move  |  R restart  |  ESC menu");
}

static void reset_breaker(BreakerState *s) {
    memset(s, 0, sizeof(*s));
    s->paddle = (Rectangle){W / 2.0f - 55, H - 58, 110, 13};
    s->ball = (Vector2){W / 2.0f, H - 76};
    s->velocity = (Vector2){210, -260};
    s->lives = 3; s->remaining = 50;
    for (int i = 0; i < 50; ++i) s->bricks[i] = true;
}
static Rectangle brick_rect(int i) {
    int col = i % 10, row = i / 10;
    return (Rectangle){56 + col * 85.0f, TOP + 34 + row * 31.0f, 76, 20};
}
static void update_breaker(App *app, float dt) {
    BreakerState *s = &app->breaker;
    float move = ((float)(IsKeyDown(KEY_D) || IsKeyDown(KEY_RIGHT)) -
                  (float)(IsKeyDown(KEY_A) || IsKeyDown(KEY_LEFT))) * 390 * dt;
    s->paddle.x = clampf(s->paddle.x + move, 16, W - s->paddle.width - 16);
    if (!s->launched) {
        s->ball = (Vector2){s->paddle.x + s->paddle.width / 2, s->paddle.y - 11};
        if (IsKeyPressed(KEY_SPACE) || IsKeyPressed(KEY_ENTER)) s->launched = true;
        return;
    }
    Vector2 previous = s->ball;
    s->ball = add(s->ball, scale(s->velocity, dt));
    if (s->ball.x < 10) { s->ball.x = 10; s->velocity.x = fabsf(s->velocity.x); }
    if (s->ball.x > W - 10) { s->ball.x = W - 10; s->velocity.x = -fabsf(s->velocity.x); }
    if (s->ball.y < TOP + 8) { s->ball.y = TOP + 8; s->velocity.y = fabsf(s->velocity.y); }
    Rectangle ballRect = {s->ball.x - 7, s->ball.y - 7, 14, 14};
    if (s->velocity.y > 0 && CheckCollisionCircleRec(s->ball, 8, s->paddle)) {
        float ratio = (s->ball.x - (s->paddle.x + s->paddle.width / 2)) / (s->paddle.width / 2);
        s->velocity.x = ratio * 340; s->velocity.y = -fabsf(s->velocity.y);
        s->ball.y = s->paddle.y - 9;
    }
    for (int i = 0; i < 50; ++i) if (s->bricks[i] && CheckCollisionRecs(ballRect, brick_rect(i))) {
        Rectangle b = brick_rect(i); s->bricks[i] = false; s->remaining--;
        if (previous.y <= b.y || previous.y >= b.y + b.height) s->velocity.y *= -1;
        else s->velocity.x *= -1;
        s->velocity = scale(norm(s->velocity), fminf(430.0f, len(s->velocity) + 4));
        if (!s->remaining) { end_game(app, true); return; }
        break;
    }
    if (s->ball.y > H + 15) {
        s->lives--; app->flash = .15f;
        if (!s->lives) { end_game(app, false); return; }
        s->launched = false; s->velocity = (Vector2){frand(-220, 220), -280};
    }
}
static void draw_breaker(const App *app) {
    const BreakerState *s = &app->breaker;
    char r[64]; snprintf(r, sizeof r, "BLOCKS %d/50    LIVES %d", 50 - s->remaining, s->lives);
    draw_header(app, "Break the complete wall", r);
    for (int i = 0; i < 50; ++i) if (s->bricks[i]) {
        Rectangle b = brick_rect(i);
        Color c = ColorLerp(ACCENTS[BREAKER], ACCENTS[TAP_PATROL], (i / 10) / 5.0f);
        DrawRectangleRounded(b, .2f, 4, c);
        DrawRectangle((int)b.x + 4, (int)b.y + 3, (int)b.width - 8, 3, Fade(WHITE, .28f));
    }
    DrawRectangleRounded(s->paddle, .5f, 8, INK);
    DrawCircleV(s->ball, 8, ACCENTS[BREAKER]);
    DrawCircleV(s->ball, 3, WHITE);
    if (!s->launched) centered("SPACE TO LAUNCH", H - 112, 17, ACCENTS[BREAKER]);
    draw_help("A / D or ARROWS paddle  |  SPACE launch  |  R restart  |  ESC menu");
}

static void new_tap_pair(TapState *s) {
    s->target = (Vector2){frand(80, W - 80), frand(TOP + 80, H - 70)};
    do s->decoy = (Vector2){frand(80, W - 80), frand(TOP + 80, H - 70)};
    while (len(sub(s->target, s->decoy)) < 150);
    s->targetR = frand(24, 36); s->decoyR = s->targetR + frand(-4, 6);
    s->pulse = 0;
}
static void reset_tap(TapState *s) {
    memset(s, 0, sizeof(*s)); s->time = 30; new_tap_pair(s);
}
static void update_tap(App *app, float dt) {
    TapState *s = &app->tap; s->time -= dt; s->pulse += dt;
    Vector2 m;
    if (pointer_pressed(&m)) {
        if (circle_hit(m, 1, s->target, s->targetR)) {
            s->score++;
            if (s->score >= 12) { end_game(app, true); return; }
            new_tap_pair(s);
        } else if (circle_hit(m, 1, s->decoy, s->decoyR)) {
            s->time -= 3; s->misses++; app->flash = .16f; new_tap_pair(s);
        }
    }
    if (s->time <= 0) end_game(app, false);
}
static void draw_tap(const App *app) {
    const TapState *s = &app->tap;
    char r[64]; snprintf(r, sizeof r, "TARGETS %d/12    PENALTIES %d    %02d", s->score, s->misses, (int)ceilf(s->time));
    draw_header(app, "Click solid targets - striped decoys cost 3 seconds", r);
    float pulse = sinf(s->pulse * 6) * 3;
    DrawCircleV(s->target, s->targetR + pulse, ACCENTS[TAP_PATROL]);
    DrawCircleV(s->target, s->targetR * .56f, PANEL);
    DrawCircleV(s->target, s->targetR * .30f, ACCENTS[TAP_PATROL]);
    DrawCircleLines((int)s->target.x, (int)s->target.y, s->targetR + 9 + pulse, Fade(WHITE, .3f));
    DrawCircleV(s->decoy, s->decoyR, (Color){255, 91, 132, 255});
    for (int y = (int)(s->decoy.y - s->decoyR); y < s->decoy.y + s->decoyR; y += 8) {
        float half = sqrtf(fmaxf(0, s->decoyR * s->decoyR - (y - s->decoy.y) * (y - s->decoy.y)));
        DrawLine((int)(s->decoy.x - half), y, (int)(s->decoy.x + half), y, BG);
    }
    DrawText("TARGET", (int)s->target.x - 27, (int)s->target.y + (int)s->targetR + 13, 13, MUTED);
    DrawText("-3 SEC", (int)s->decoy.x - 23, (int)s->decoy.y + (int)s->decoyR + 13, 13, ACCENTS[BREAKER]);
    draw_help("CLICK / TAP solid target  |  R restart  |  ESC menu");
}

static void reset_sky(SkyState *s) {
    memset(s, 0, sizeof(*s)); s->birdY = H / 2.0f;
    for (int i = 0; i < 4; ++i) { s->gateX[i] = W + 90 + i * 245; s->gapY[i] = frand(175, H - 150); }
}
static void update_sky(App *app, float dt) {
    SkyState *s = &app->sky;
    Vector2 pointer;
    if (IsKeyPressed(KEY_SPACE) || IsKeyPressed(KEY_UP) || pointer_pressed(&pointer)) s->birdV = -330;
    s->birdV += 890 * dt; s->birdY += s->birdV * dt;
    Rectangle bird = {165, s->birdY - 12, 28, 24};
    bool hit = s->birdY < TOP + 12 || s->birdY > H - 48;
    for (int i = 0; i < 4; ++i) {
        s->gateX[i] -= 180 * dt;
        if (!s->counted[i] && s->gateX[i] + 62 < 165) {
            s->counted[i] = true; s->passed++;
        }
        if (s->gateX[i] < -80) {
            float maxX = s->gateX[0];
            for (int j = 1; j < 4; ++j) if (s->gateX[j] > maxX) maxX = s->gateX[j];
            s->gateX[i] = maxX + 245; s->gapY[i] = frand(175, H - 150); s->counted[i] = false;
        }
        Rectangle top = {s->gateX[i], TOP, 62, s->gapY[i] - 67 - TOP};
        Rectangle bottom = {s->gateX[i], s->gapY[i] + 67, 62, H - s->gapY[i] - 67 - 35};
        if (CheckCollisionRecs(bird, top) || CheckCollisionRecs(bird, bottom)) hit = true;
    }
    KofunOutcome outcome = kofun_resolve_goal_after_hazard(hit, s->passed >= 10);
    if (outcome == KOFUN_OUTCOME_LOST) end_game(app, false);
    else if (outcome == KOFUN_OUTCOME_WON) end_game(app, true);
}
static void draw_sky(const App *app) {
    const SkyState *s = &app->sky;
    char r[64]; snprintf(r, sizeof r, "GATES %d/10", s->passed);
    draw_header(app, "Thread the glowing gates", r);
    for (int i = 0; i < 4; ++i) {
        Rectangle top = {s->gateX[i], TOP, 62, s->gapY[i] - 67 - TOP};
        Rectangle bot = {s->gateX[i], s->gapY[i] + 67, 62, H - s->gapY[i] - 67 - 35};
        DrawRectangleRec(top, (Color){38, 89, 133, 255}); DrawRectangleRec(bot, (Color){38, 89, 133, 255});
        DrawRectangle((int)s->gateX[i] - 6, (int)(s->gapY[i] - 75), 74, 10, ACCENTS[SKY_DODGE]);
        DrawRectangle((int)s->gateX[i] - 6, (int)(s->gapY[i] + 65), 74, 10, ACCENTS[SKY_DODGE]);
    }
    Vector2 bird = {179, s->birdY};
    DrawPoly(bird, 3, 19, 90, ACCENTS[SKY_DODGE]);
    DrawCircleV((Vector2){172, s->birdY - 2}, 7, INK);
    DrawCircleV((Vector2){174, s->birdY - 3}, 2, BG);
    draw_help("SPACE / UP / CLICK / TAP flap  |  R restart  |  ESC menu");
}

static void reset_dash(DashState *s) {
    memset(s, 0, sizeof(*s)); s->y = H - 73; s->time = 30; s->spawn = .8f;
}
static void dash_spawn(DashState *s) {
    for (int i = 0; i < 5; ++i) if (!s->active[i]) {
        float h = frand(34, 70);
        s->obstacle[i] = (Rectangle){W + 20, H - 45 - h, frand(25, 42), h};
        s->active[i] = 1; return;
    }
}
static void update_dash(App *app, float dt) {
    DashState *s = &app->dash;
    Vector2 pointer;
    bool jump = IsKeyPressed(KEY_SPACE) || IsKeyPressed(KEY_UP) || pointer_pressed(&pointer);
    if (jump && s->y >= H - 74) s->vy = -430;
    s->vy += 1100 * dt; s->y += s->vy * dt;
    if (s->y > H - 73) { s->y = H - 73; s->vy = 0; }
    s->time -= dt; s->spawn -= dt;
    if (s->spawn <= 0) { dash_spawn(s); s->spawn = frand(.75f, 1.35f); }
    Rectangle p = {150, s->y - 31, 30, 31};
    for (int i = 0; i < 5; ++i) if (s->active[i]) {
        s->obstacle[i].x -= (260 + (30 - s->time) * 2.4f) * dt;
        if (s->obstacle[i].x + s->obstacle[i].width < 0) { s->active[i] = 0; s->dodged++; }
        else if (CheckCollisionRecs(p, s->obstacle[i])) { end_game(app, false); return; }
    }
    if (s->time <= 0) end_game(app, true);
}
static void draw_dash(const App *app) {
    const DashState *s = &app->dash;
    char r[64]; snprintf(r, sizeof r, "DODGED %d    %02d", s->dodged, (int)ceilf(fmaxf(0, s->time)));
    draw_header(app, "Keep running until the clock expires", r);
    for (int x = -80; x < W + 80; x += 120) {
        float px = fmodf(x - app->worldTime * 120, W + 160) - 80;
        float h = 60 + (float)(((x + 400) * 7) % 90);
        DrawRectangle((int)px, H - 45 - (int)h, 75, (int)h, (Color){24, 35, 64, 255});
        DrawRectangle((int)px + 12, H - 62 - (int)h / 2, 7, 7, ACCENTS[NEON_DASH]);
    }
    DrawRectangle(0, H - 45, W, 4, ACCENTS[NEON_DASH]);
    for (int i = 0; i < 5; ++i) if (s->active[i]) {
        DrawRectangleRounded(s->obstacle[i], .15f, 4, (Color){255, 85, 122, 255});
        DrawTriangle((Vector2){s->obstacle[i].x, s->obstacle[i].y},
                     (Vector2){s->obstacle[i].x + s->obstacle[i].width / 2, s->obstacle[i].y - 12},
                     (Vector2){s->obstacle[i].x + s->obstacle[i].width, s->obstacle[i].y}, (Color){255, 85, 122, 255});
    }
    DrawRectangleRounded((Rectangle){150, s->y - 31, 30, 31}, .35f, 6, INK);
    DrawCircle(158, (int)s->y, 6, ACCENTS[NEON_DASH]); DrawCircle(174, (int)s->y, 6, ACCENTS[NEON_DASH]);
    draw_help("SPACE / UP / CLICK / TAP jump  |  R restart  |  ESC menu");
}

static void orbit_spawn(OrbitState *s) {
    if (s->count >= 10) return;
    int edge = GetRandomValue(0, 3); Vector2 p;
    if (edge == 0) p = (Vector2){-20, frand(TOP + 20, H - 30)};
    else if (edge == 1) p = (Vector2){W + 20, frand(TOP + 20, H - 30)};
    else if (edge == 2) p = (Vector2){frand(20, W - 20), TOP - 20};
    else p = (Vector2){frand(20, W - 20), H + 20};
    s->enemy[s->count] = p; s->vel[s->count] = (Vector2){0, 0}; s->count++;
}
static void reset_orbit(OrbitState *s) {
    memset(s, 0, sizeof(*s)); s->player = (Vector2){W / 2.0f, H / 2.0f}; s->time = 30; s->spawn = .2f;
}
static void update_orbit(App *app, float dt) {
    OrbitState *s = &app->orbit;
    Vector2 input = {(float)(IsKeyDown(KEY_D) || IsKeyDown(KEY_RIGHT)) -
                         (float)(IsKeyDown(KEY_A) || IsKeyDown(KEY_LEFT)),
                     (float)(IsKeyDown(KEY_S) || IsKeyDown(KEY_DOWN)) -
                         (float)(IsKeyDown(KEY_W) || IsKeyDown(KEY_UP))};
    s->player = add(s->player, scale(norm(input), 220 * dt));
    s->player.x = clampf(s->player.x, 24, W - 24); s->player.y = clampf(s->player.y, TOP + 24, H - 40);
    s->time -= dt; s->spawn -= dt; s->cooldown -= dt;
    if (s->spawn <= 0) { orbit_spawn(s); s->spawn = fmaxf(.38f, .85f - (30 - s->time) * .012f); }
    bool pulse = IsKeyPressed(KEY_SPACE) && s->cooldown <= 0;
    if (pulse) { s->cooldown = 1.05f; s->pulses++; }
    for (int i = 0; i < s->count; ++i) {
        Vector2 toward = norm(sub(s->player, s->enemy[i]));
        s->vel[i] = add(scale(s->vel[i], powf(.16f, dt)), scale(toward, (55 + (30 - s->time) * 1.8f) * dt));
        if (pulse) {
            float d = len(sub(s->enemy[i], s->player));
            if (d < 155) s->vel[i] = add(s->vel[i], scale(norm(sub(s->enemy[i], s->player)), (170 - d) * 3.5f));
        }
        s->enemy[i] = add(s->enemy[i], scale(add(scale(toward, 65), s->vel[i]), dt));
        if (circle_hit(s->player, 15, s->enemy[i], 13)) { end_game(app, false); return; }
    }
    if (s->time <= 0) end_game(app, true);
}
static void draw_orbit(const App *app) {
    const OrbitState *s = &app->orbit;
    char r[80]; snprintf(r, sizeof r, "PULSES %d    %02d", s->pulses, (int)ceilf(fmaxf(0, s->time)));
    draw_header(app, "Survive - pulse nearby enemies away", r);
    float ready = clampf(1 - s->cooldown / 1.05f, 0, 1);
    DrawCircleLines((int)s->player.x, (int)s->player.y, 32 + ready * 10, Fade(ACCENTS[KOFUN_ORBIT], .35f));
    if (s->cooldown > .72f) DrawCircleLines((int)s->player.x, (int)s->player.y,
                                            40 + (1.05f - s->cooldown) * 380, ACCENTS[KOFUN_ORBIT]);
    for (int i = 0; i < s->count; ++i) {
        float a = atan2f(s->player.y - s->enemy[i].y, s->player.x - s->enemy[i].x) * RAD2DEG;
        DrawPoly(s->enemy[i], 3, 16, a + 90, (Color){255, 92, 127, 255});
        DrawCircleV(s->enemy[i], 4, BG);
    }
    DrawCircleV(s->player, 17, INK); DrawCircleV(s->player, 10, ACCENTS[KOFUN_ORBIT]);
    DrawCircleV(s->player, 4, BG);
    DrawRectangleRounded((Rectangle){24, H - 63, 150, 10}, .5f, 6, PANEL);
    DrawRectangleRounded((Rectangle){24, H - 63, 150 * ready, 10}, .5f, 6, ACCENTS[KOFUN_ORBIT]);
    draw_help("WASD / ARROWS move  |  SPACE pulse  |  R restart  |  ESC menu");
}

#define GRID_X 120
#define GRID_Y 105
#define CELL 24
#define COLS 30
#define ROWS 16
static bool same_cell(Cell a, Cell b) { return a.x == b.x && a.y == b.y; }
static void snake_food(SnakeState *s) {
    bool occupied;
    do {
        occupied = false; s->food = (Cell){GetRandomValue(0, COLS - 1), GetRandomValue(0, ROWS - 1)};
        for (int i = 0; i < s->length; ++i) if (same_cell(s->food, s->body[i])) occupied = true;
    } while (occupied);
}
static void reset_snake(SnakeState *s) {
    memset(s, 0, sizeof(*s)); s->length = 4; s->dir = (Cell){1, 0}; s->nextDir = s->dir; s->tick = .12f;
    for (int i = 0; i < s->length; ++i) s->body[i] = (Cell){COLS / 2 - i, ROWS / 2};
    snake_food(s);
}
static void update_snake(App *app, float dt) {
    SnakeState *s = &app->snake;
    if ((IsKeyPressed(KEY_UP) || IsKeyPressed(KEY_W)) && s->dir.y == 0) s->nextDir = (Cell){0, -1};
    if ((IsKeyPressed(KEY_DOWN) || IsKeyPressed(KEY_S)) && s->dir.y == 0) s->nextDir = (Cell){0, 1};
    if ((IsKeyPressed(KEY_LEFT) || IsKeyPressed(KEY_A)) && s->dir.x == 0) s->nextDir = (Cell){-1, 0};
    if ((IsKeyPressed(KEY_RIGHT) || IsKeyPressed(KEY_D)) && s->dir.x == 0) s->nextDir = (Cell){1, 0};
    s->tick -= dt; if (s->tick > 0) return;
    s->tick += fmaxf(.062f, .115f - s->score * .0025f); s->dir = s->nextDir;
    Cell head = {s->body[0].x + s->dir.x, s->body[0].y + s->dir.y};
    bool eat = same_cell(head, s->food);
    if (head.x < 0 || head.x >= COLS || head.y < 0 || head.y >= ROWS) { end_game(app, false); return; }
    int solidLength = eat ? s->length : s->length - 1;
    for (int i = 0; i < solidLength; ++i) if (same_cell(head, s->body[i])) { end_game(app, false); return; }
    if (eat) {
        s->length++; s->score++;
        if (s->score >= 15) { end_game(app, true); return; }
    }
    for (int i = s->length - 1; i > 0; --i) s->body[i] = s->body[i - 1];
    s->body[0] = head; if (eat) snake_food(s);
}
static void draw_snake(const App *app) {
    const SnakeState *s = &app->snake;
    char r[64]; snprintf(r, sizeof r, "FRUIT %d/15    LENGTH %d", s->score, s->length);
    draw_header(app, "Fill the grid without biting your tail", r);
    DrawRectangle(GRID_X - 3, GRID_Y - 3, COLS * CELL + 6, ROWS * CELL + 6, Fade(ACCENTS[SNAKE], .35f));
    DrawRectangle(GRID_X, GRID_Y, COLS * CELL, ROWS * CELL, (Color){12, 20, 32, 255});
    for (int x = 0; x <= COLS; ++x) DrawLine(GRID_X + x * CELL, GRID_Y, GRID_X + x * CELL, GRID_Y + ROWS * CELL, Fade(MUTED, .08f));
    for (int y = 0; y <= ROWS; ++y) DrawLine(GRID_X, GRID_Y + y * CELL, GRID_X + COLS * CELL, GRID_Y + y * CELL, Fade(MUTED, .08f));
    Vector2 food = {GRID_X + s->food.x * CELL + CELL / 2, GRID_Y + s->food.y * CELL + CELL / 2};
    DrawPoly(food, 6, 9 + sinf(app->worldTime * 5) * 2, app->worldTime * 35, ACCENTS[TAP_PATROL]);
    for (int i = s->length - 1; i >= 0; --i) {
        Rectangle b = {GRID_X + s->body[i].x * CELL + 2, GRID_Y + s->body[i].y * CELL + 2, CELL - 4, CELL - 4};
        DrawRectangleRounded(b, .28f, 4, i == 0 ? INK : ColorLerp(ACCENTS[SNAKE], (Color){42, 151, 103, 255}, i / (float)s->length));
    }
    draw_help("WASD / ARROWS steer  |  R restart  |  ESC menu");
}

static void reset_current(App *app) {
    app->won = false; app->screen = PLAY; app->flash = 0;
    switch (app->current) {
        case COURIER: reset_courier(&app->courier); break;
        case BREAKER: reset_breaker(&app->breaker); break;
        case TAP_PATROL: reset_tap(&app->tap); break;
        case SKY_DODGE: reset_sky(&app->sky); break;
        case NEON_DASH: reset_dash(&app->dash); break;
        case KOFUN_ORBIT: reset_orbit(&app->orbit); break;
        case SNAKE: reset_snake(&app->snake); break;
        default: break;
    }
}
static void update_menu(App *app) {
    if (IsKeyPressed(KEY_UP)) app->selected = (GameId)((app->selected + GAME_COUNT - 1) % GAME_COUNT);
    if (IsKeyPressed(KEY_DOWN)) app->selected = (GameId)((app->selected + 1) % GAME_COUNT);
    for (int i = 0; i < GAME_COUNT; ++i) if (IsKeyPressed(KEY_ONE + i)) { app->selected = (GameId)i; app->current = app->selected; reset_current(app); }
    if (IsKeyPressed(KEY_ENTER) || IsKeyPressed(KEY_SPACE)) { app->current = app->selected; reset_current(app); }
}
static void update_play(App *app, float dt) {
    if (IsKeyPressed(KEY_ESCAPE)) { app->screen = MENU; return; }
    if (IsKeyPressed(KEY_R)) { reset_current(app); return; }
    switch (app->current) {
        case COURIER: update_courier(app, dt); break;
        case BREAKER: update_breaker(app, dt); break;
        case TAP_PATROL: update_tap(app, dt); break;
        case SKY_DODGE: update_sky(app, dt); break;
        case NEON_DASH: update_dash(app, dt); break;
        case KOFUN_ORBIT: update_orbit(app, dt); break;
        case SNAKE: update_snake(app, dt); break;
        default: break;
    }
}
static void draw_menu(const App *app) {
    centered("KOFUN ARCADE", 38, 46, INK);
    centered("RAYLIB / C11  |  SEVEN-GAME LAB", 91, 17, MUTED);
    for (int i = 0; i < GAME_COUNT; ++i) {
        Rectangle r = {154, 133 + i * 51.0f, 652, 42};
        bool selected = app->selected == (GameId)i;
        if (selected) {
            DrawRectangleRounded(r, .25f, 7, PANEL);
            DrawRectangleRoundedLinesEx(r, .25f, 7, 2, ACCENTS[i]);
            DrawRectangleRounded((Rectangle){r.x, r.y, 6, r.height}, .5f, 5, ACCENTS[i]);
        }
        char n[4]; snprintf(n, sizeof n, "%d", i + 1);
        DrawText(n, 175, (int)r.y + 10, 20, selected ? ACCENTS[i] : MUTED);
        DrawText(NAMES[i], 218, (int)r.y + 8, 22, selected ? INK : (Color){183, 196, 220, 255});
        int sw = MeasureText(SUBTITLES[i], 15);
        DrawText(SUBTITLES[i], 785 - sw, (int)r.y + 13, 15, MUTED);
    }
    centered("1-7 SELECT  |  UP/DOWN BROWSE  |  ENTER PLAY", 503, 17, MUTED);
}
static void draw_game(const App *app) {
    switch (app->current) {
        case COURIER: draw_courier(app); break;
        case BREAKER: draw_breaker(app); break;
        case TAP_PATROL: draw_tap(app); break;
        case SKY_DODGE: draw_sky(app); break;
        case NEON_DASH: draw_dash(app); break;
        case KOFUN_ORBIT: draw_orbit(app); break;
        case SNAKE: draw_snake(app); break;
        default: break;
    }
}
static void draw_result(const App *app) {
    draw_game(app);
    DrawRectangle(0, 0, W, H, Fade(BG, .79f));
    Rectangle card = {W / 2.0f - 250, 142, 500, 250};
    panel(card, app->won ? ACCENTS[app->current] : ACCENTS[BREAKER]);
    centered(app->won ? "MISSION COMPLETE" : "RUN ENDED", 188, 34, app->won ? ACCENTS[app->current] : ACCENTS[BREAKER]);
    centered(NAMES[app->current], 240, 21, INK);
    centered(app->won ? "Nice run. The kofun remembers." : "Read the pattern, then try again.", 282, 17, MUTED);
    centered("ENTER / R  RETRY", 330, 18, INK);
    centered("ESC  BACK TO ARCADE", 358, 15, MUTED);
}

int main(void) {
    SetConfigFlags(FLAG_VSYNC_HINT | FLAG_WINDOW_HIGHDPI);
    InitWindow(W, H, "Kofun Arcade - raylib");
    SetExitKey(KEY_NULL);
    SetTargetFPS(60);
    App app = {0};
    app.screen = MENU; app.selected = COURIER; app.current = COURIER;
    while (!WindowShouldClose()) {
        float dt = fminf(GetFrameTime(), 1.0f / 20.0f);
        app.worldTime += dt; app.flash -= dt;
        if (app.screen == MENU) update_menu(&app);
        else if (app.screen == PLAY) update_play(&app, dt);
        else {
            if (IsKeyPressed(KEY_ESCAPE)) app.screen = MENU;
            else if (IsKeyPressed(KEY_ENTER) || IsKeyPressed(KEY_R) || IsKeyPressed(KEY_SPACE)) reset_current(&app);
        }
        BeginDrawing();
        draw_backdrop(&app);
        if (app.screen == MENU) draw_menu(&app);
        else if (app.screen == PLAY) draw_game(&app);
        else draw_result(&app);
        if (app.flash > 0) DrawRectangle(0, 0, W, H, Fade(WHITE, app.flash * 1.8f));
        EndDrawing();
    }
    CloseWindow();
    return 0;
}
