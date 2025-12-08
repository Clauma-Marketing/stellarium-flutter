/* Stellarium Web Engine - Copyright (c) 2022 - Stellarium Labs SRL
 *
 * This program is licensed under the terms of the GNU AGPL v3, or
 * alternatively under a commercial licence.
 *
 * The terms of the AGPL v3 license can be found in the main directory of this
 * repository.
 */

#include "swe.h"
#include <math.h>

// Render a pointer around the selected object.
// This is convenient to put this as a module, because it has to be rendered
// Before the UI.

typedef struct pointer {
    obj_t           obj;
    bool            visible;
} pointer_t;

static int pointer_init(obj_t *obj, json_value *args)
{
    pointer_t *pointer = (void*)obj;
    pointer->visible = true;
    return 0;
}

// Amber/gold color palette (matching the React design)
// Amber-400: #fbbf24 = (0.984, 0.749, 0.141)
// Amber-500: #f59e0b = (0.961, 0.620, 0.043)
// Amber-100: #fef3c7 = (0.996, 0.953, 0.780)

// Render a sophisticated direction arrow with glow effects
static void render_direction_arrow(const painter_t *painter_,
                                   double center_x, double center_y,
                                   double angle_rad)
{
    painter_t painter = *painter_;
    double transf[3][3];
    double t = sys_get_unix_time();
    int i;

    // Animation phases
    double pulse_slow = 0.85 + 0.15 * sin(t * 2.0);       // Slow breathing
    double arrow_bob = sin(t * 3.0) * 3.0;                // Arrow bobbing

    // =========================================
    // 1. OUTER GLOW - Multiple soft circles
    // =========================================
    double glow_base_r = 90.0 * pulse_slow;
    for (i = 0; i < 5; i++) {
        double glow_r = glow_base_r + i * 15;
        double alpha = 0.15 - i * 0.025;
        if (alpha <= 0) break;
        vec4_set(painter.color, 0.984, 0.749, 0.141, alpha);
        painter.lines.width = 8 - i;
        paint_2d_ellipse(&painter, NULL, 0,
                         (double[]){center_x, center_y},
                         VEC(glow_r, glow_r), NULL);
    }

    // =========================================
    // 2. PULSING RIPPLE RINGS (3 rings with staggered animation)
    // =========================================
    for (i = 0; i < 3; i++) {
        double phase = fmod(t + i * 1.0, 3.0) / 3.0;  // 0 to 1, staggered
        double ripple_r = 70.0 + phase * 50.0;
        double ripple_alpha = 0.5 * (1.0 - phase);  // Fade out as it expands
        vec4_set(painter.color, 0.984, 0.749, 0.141, ripple_alpha);
        painter.lines.width = 2;
        paint_2d_ellipse(&painter, NULL, 0,
                         (double[]){center_x, center_y},
                         VEC(ripple_r, ripple_r), NULL);
    }

    // =========================================
    // 3. MAIN CIRCLE - Thick golden ring with gradient effect
    // =========================================
    double main_r = 65.0;

    // Outer edge glow (lighter)
    vec4_set(painter.color, 0.996, 0.953, 0.780, 0.6);
    painter.lines.width = 8;
    paint_2d_ellipse(&painter, NULL, 0,
                     (double[]){center_x, center_y},
                     VEC(main_r + 2, main_r + 2), NULL);

    // Main golden ring
    vec4_set(painter.color, 0.984, 0.749, 0.141, 1.0);
    painter.lines.width = 5;
    paint_2d_ellipse(&painter, NULL, 0,
                     (double[]){center_x, center_y},
                     VEC(main_r, main_r), NULL);

    // Inner edge (darker amber)
    vec4_set(painter.color, 0.961, 0.620, 0.043, 0.8);
    painter.lines.width = 2;
    paint_2d_ellipse(&painter, NULL, 0,
                     (double[]){center_x, center_y},
                     VEC(main_r - 4, main_r - 4), NULL);

    // =========================================
    // 4. INNER HIGHLIGHT (subtle shine on top-left)
    // =========================================
    vec4_set(painter.color, 0.996, 0.953, 0.780, 0.15);
    painter.lines.width = 3;
    // Draw arc segment for highlight effect (partial ellipse)
    paint_2d_ellipse(&painter, NULL, M_PI * 0.4,
                     (double[]){center_x - 15, center_y - 15},
                     VEC(35, 35), NULL);

    // =========================================
    // 5. BOLD ARROW - With gradient from amber to white
    // =========================================
    mat3_set_identity(transf);
    mat3_itranslate(transf, center_x, center_y);
    mat3_rz(angle_rad, transf, transf);

    // Arrow dimensions
    double arrow_length = 38.0 + arrow_bob;
    double head_size = 16.0;
    double tip_y = -arrow_length;

    // Arrow shaft - multiple overlapping lines for thickness and glow
    // Outer glow layer
    vec4_set(painter.color, 0.984, 0.749, 0.141, 0.4);
    painter.lines.width = 10;
    paint_2d_line(&painter, transf, VEC(0, 5), VEC(0, tip_y + head_size * 0.3));

    // Mid layer (amber)
    vec4_set(painter.color, 0.984, 0.749, 0.141, 0.9);
    painter.lines.width = 6;
    paint_2d_line(&painter, transf, VEC(0, 5), VEC(0, tip_y + head_size * 0.3));

    // Core (bright)
    vec4_set(painter.color, 0.996, 0.953, 0.780, 1.0);
    painter.lines.width = 3;
    paint_2d_line(&painter, transf, VEC(0, 5), VEC(0, tip_y + head_size * 0.3));

    // =========================================
    // 6. ARROW HEAD - Closed triangle
    // =========================================
    // Arrow head - glow layer
    vec4_set(painter.color, 0.984, 0.749, 0.141, 0.5);
    painter.lines.width = 8;
    paint_2d_line(&painter, transf,
                  VEC(-head_size, tip_y + head_size),
                  VEC(0, tip_y));
    paint_2d_line(&painter, transf,
                  VEC(head_size, tip_y + head_size),
                  VEC(0, tip_y));
    paint_2d_line(&painter, transf,
                  VEC(-head_size, tip_y + head_size),
                  VEC(head_size, tip_y + head_size));

    // Arrow head - main layer
    vec4_set(painter.color, 0.984, 0.749, 0.141, 1.0);
    painter.lines.width = 5;
    paint_2d_line(&painter, transf,
                  VEC(-head_size, tip_y + head_size),
                  VEC(0, tip_y));
    paint_2d_line(&painter, transf,
                  VEC(head_size, tip_y + head_size),
                  VEC(0, tip_y));
    paint_2d_line(&painter, transf,
                  VEC(-head_size, tip_y + head_size),
                  VEC(head_size, tip_y + head_size));

    // Arrow head - bright core layer (all lines meet at the same tip)
    vec4_set(painter.color, 0.996, 0.953, 0.780, 1.0);
    painter.lines.width = 2;
    paint_2d_line(&painter, transf,
                  VEC(-head_size * 0.8, tip_y + head_size * 0.8),
                  VEC(0, tip_y));
    paint_2d_line(&painter, transf,
                  VEC(head_size * 0.8, tip_y + head_size * 0.8),
                  VEC(0, tip_y));
    paint_2d_line(&painter, transf,
                  VEC(-head_size * 0.8, tip_y + head_size * 0.8),
                  VEC(head_size * 0.8, tip_y + head_size * 0.8));

    // =========================================
    // 7. DECORATIVE CORNER ACCENTS
    // =========================================
    vec4_set(painter.color, 0.984, 0.749, 0.141, 0.4);
    painter.lines.width = 2;
    for (i = 0; i < 4; i++) {
        double corner_angle = angle_rad + i * M_PI / 2.0 + M_PI / 4.0;
        double corner_r = main_r + 8;
        double cx = center_x + sin(corner_angle) * corner_r;
        double cy = center_y - cos(corner_angle) * corner_r;
        paint_2d_ellipse(&painter, NULL, M_PI * 0.2,
                         (double[]){cx, cy},
                         VEC(6, 6), NULL);
    }
}

// Check if position is on screen (with margin)
static bool is_on_screen(double x, double y, double w, double h, double margin)
{
    return x >= margin && x <= w - margin &&
           y >= margin && y <= h - margin;
}

static int pointer_render(obj_t *obj, const painter_t *painter_)
{
    int i;
    double win_pos[2], win_size[2], angle;
    const double T = 2.0;    // Animation period.
    double r, transf[3][3];
    bool skip_top_bar = false;
    const pointer_t *pointer = (const pointer_t*)obj;
    obj_t *selection = core->selection;
    painter_t painter = *painter_;

    if (!pointer->visible) return 0;
    vec4_set(painter.color, 1, 1, 1, 1);
    if (!selection) return 0;

    // Get selection screen position
    obj_get_2d_ellipse(selection, painter.obs, painter.proj,
                       win_pos, win_size, &angle);

    // Gyroscope mode: render direction arrow if selection is off-screen
    if (core->gyroscope_mode) {
        double screen_w = core->win_size[0];
        double screen_h = core->win_size[1];
        double center_x = screen_w / 2.0;
        double center_y = screen_h / 2.0;
        double margin = 50.0;

        // Check if selection is off-screen
        if (!is_on_screen(win_pos[0], win_pos[1], screen_w, screen_h, margin)) {
            // Calculate direction angle from screen center to selection
            double dx = win_pos[0] - center_x;
            double dy = win_pos[1] - center_y;
            // atan2 gives angle from positive X axis, we want from negative Y
            // (pointing up), so we swap and negate appropriately
            double dir_angle = atan2(dx, -dy);

            render_direction_arrow(painter_, center_x, center_y, dir_angle);

            // In gyroscope mode with off-screen selection, don't draw the
            // standard pointer strokes
            return 0;
        }
        // If on-screen in gyroscope mode, draw a golden highlight
        double t = sys_get_unix_time();
        double pulse = 0.85 + 0.15 * sin(t * 3.0);
        double indicator_r = fmax(win_size[0], win_size[1]) + 20;
        indicator_r = fmax(indicator_r, 30);

        // Outer glow
        vec4_set(painter.color, 0.984, 0.749, 0.141, 0.2);
        painter.lines.width = 6;
        paint_2d_ellipse(&painter, NULL, 0, win_pos,
                         VEC(indicator_r + 12, indicator_r + 12), NULL);

        // Middle ring
        vec4_set(painter.color, 0.984, 0.749, 0.141, 0.6 * pulse);
        painter.lines.width = 3;
        paint_2d_ellipse(&painter, NULL, 0, win_pos,
                         VEC(indicator_r + 5, indicator_r + 5), NULL);

        // Inner bright ring
        vec4_set(painter.color, 0.996, 0.953, 0.780, 0.9);
        painter.lines.width = 2;
        paint_2d_ellipse(&painter, NULL, 0, win_pos,
                         VEC(indicator_r, indicator_r), NULL);

        // Corner accent dots
        int j;
        for (j = 0; j < 4; j++) {
            double angle = j * M_PI / 2.0 + t * 0.5;
            double ax = win_pos[0] + cos(angle) * (indicator_r + 15);
            double ay = win_pos[1] + sin(angle) * (indicator_r + 15);
            vec4_set(painter.color, 1.0, 1.0, 1.0, 0.8 * pulse);
            painter.lines.width = 2;
            paint_2d_ellipse(&painter, NULL, 0,
                             (double[]){ax, ay}, VEC(3, 3), NULL);
        }
        return 0;
    }

    // Standard pointer rendering (non-gyroscope mode)
    // If the selection has a custom rendering method, we use it.
    if (selection->klass->render_pointer) {
        selection->klass->render_pointer(selection, &painter);
        return 0;
    }

    r = fmax(win_size[0], win_size[1]);
    r += 5;

    // Draw four strokes around the object.
    // Skip the upper stroke if the selection has a label on top.
    skip_top_bar = labels_has_obj(selection);

    for (i = 0; i < 4; i++) {
        if (skip_top_bar && i == 3) continue;
        r = fmax(r, 8);
        r += 0.4 * (sin(sys_get_unix_time() / T * 2 * M_PI) + 1.1);
        mat3_set_identity(transf);
        mat3_itranslate(transf, win_pos[0], win_pos[1]);
        mat3_rz(i * 90 * DD2R, transf, transf);
        mat3_itranslate(transf, r, 0);
        mat3_iscale(transf, 8, 1, 1);
        painter.lines.width = 3;
        paint_2d_line(&painter, transf, VEC(0, 0), VEC(1, 0));
    }
    return 0;
}

/*
 * Meta class declarations.
 */

static obj_klass_t pointer_klass = {
    .id = "pointer",
    .size = sizeof(pointer_t),
    .flags = OBJ_IN_JSON_TREE | OBJ_MODULE,
    .init = pointer_init,
    .render = pointer_render,
    .render_order = 199, // Just before the ui.
    .attributes = (attribute_t[]) {
        PROPERTY(visible, TYPE_BOOL, MEMBER(pointer_t, visible)),
        {}
    },
};

OBJ_REGISTER(pointer_klass)
