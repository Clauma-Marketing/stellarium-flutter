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

/*
 * Star tracking module - Shows the path of a selected star across the sky
 * over a 24-hour period, similar to the "Visibility" feature in other
 * planetarium apps.
 *
 * Features:
 * - Draws the star's diurnal path as a dotted circle/ellipse on the sky
 * - Shows small dots at hourly intervals
 * - Shows time labels (00:00, 02:00, etc.) at 2-hour intervals
 * - Uses different opacity for above/below horizon portions
 * - Indicates current position of the star with a marker
 */

typedef struct star_track {
    obj_t       obj;
    bool        visible;           // Whether tracking is enabled

    // Cached path data - positions at different times
    struct {
        int     nb_points;         // Number of points in the path
        double  (*path_azalt)[2];  // Path positions in azimuth/altitude
        double  *hours;            // Hour of day for each point
    } cache;

} star_track_t;

#define PATH_POINTS 144            // One point every 10 minutes for smooth path
#define HOURS_PER_DAY 24.0

// Colors - matching the reference green color
static const double COLOR_PATH_ABOVE[4] = {0.3, 0.85, 0.5, 0.9};   // Bright green
static const double COLOR_PATH_BELOW[4] = {0.3, 0.85, 0.5, 0.4};   // Faded green
static const double COLOR_DOT[4] = {0.3, 0.85, 0.5, 1.0};          // Green dots
static const double COLOR_CURRENT[4] = {1.0, 1.0, 1.0, 1.0};       // White for current
static const double COLOR_TIME_LABEL[4] = {0.3, 0.85, 0.5, 1.0};   // Green labels

static int star_track_init(obj_t *obj, json_value *args)
{
    star_track_t *track = (void*)obj;
    track->visible = false;
    track->cache.nb_points = 0;
    track->cache.path_azalt = NULL;
    track->cache.hours = NULL;
    return 0;
}

static void star_track_del(obj_t *obj)
{
    star_track_t *track = (void*)obj;
    free(track->cache.path_azalt);
    free(track->cache.hours);
}

/*
 * Compute the star's azimuth and altitude for a given time offset.
 */
static void compute_azalt_at_time(const obj_t *selection,
                                   const observer_t *obs_base,
                                   double hours_offset,
                                   double *out_az,
                                   double *out_alt)
{
    observer_t obs = *obs_base;
    double pvo[2][4], pos_observed[4], az, alt;

    // Adjust observer time (hours to days)
    obs.tt = obs_base->tt + hours_offset / 24.0;
    observer_update(&obs, false);

    // Get object position at this time in ICRF
    obj_get_pvo(selection, &obs, pvo);
    vec3_normalize(pvo[0], pvo[0]);

    // Convert to observed (horizontal) frame
    convert_frame(&obs, FRAME_ICRF, FRAME_OBSERVED, true, pvo[0], pos_observed);

    // Convert Cartesian to spherical (azimuth, altitude)
    eraC2s(pos_observed, &az, &alt);

    *out_az = az;
    *out_alt = alt;
}

/*
 * Update the cached path data for the selected object.
 * Computes positions at fixed clock hours (0:00, 0:10, 0:20, etc.)
 * to prevent flickering of labels when time changes.
 */
static void update_path_cache(star_track_t *track, const obj_t *selection,
                              const observer_t *obs)
{
    int i;

    // Allocate or reallocate cache arrays if needed
    if (track->cache.nb_points != PATH_POINTS) {
        free(track->cache.path_azalt);
        free(track->cache.hours);
        track->cache.path_azalt = calloc(PATH_POINTS, sizeof(double[2]));
        track->cache.hours = calloc(PATH_POINTS, sizeof(double));
        track->cache.nb_points = PATH_POINTS;
    }

    // Get current hour as decimal
    double current_hour = fmod(obs->utc, 1.0) * 24.0;

    // Compute positions for a full 24-hour cycle at fixed clock times
    // Each point represents a fixed time: 0:00, 0:10, 0:20, ..., 23:50
    for (i = 0; i < PATH_POINTS; i++) {
        // Fixed clock hour for this point (0.0, 0.167, 0.333, ..., 23.833)
        double clock_hour = (double)i * (HOURS_PER_DAY / PATH_POINTS);

        track->cache.hours[i] = clock_hour;

        // Compute hours offset from current time to reach this clock hour
        double hours_offset = clock_hour - current_hour;

        compute_azalt_at_time(selection, obs, hours_offset,
                              &track->cache.path_azalt[i][0],
                              &track->cache.path_azalt[i][1]);
    }
}

/*
 * Convert azimuth/altitude to view frame position.
 */
static void azalt_to_view(const observer_t *obs, const projection_t *proj,
                          double az, double alt, double out_view[3])
{
    double pos_observed[4], pos_icrf[4];

    // Convert spherical (az, alt) to Cartesian in observed frame
    eraS2c(az, alt, pos_observed);
    pos_observed[3] = 0;

    // Convert from observed frame to ICRF
    convert_frame(obs, FRAME_OBSERVED, FRAME_ICRF, true, pos_observed, pos_icrf);

    // Convert from ICRF to view frame
    convert_frame(obs, FRAME_ICRF, FRAME_VIEW, true, pos_icrf, out_view);
}

/*
 * Draw a small filled circle (dot) at the given position.
 */
static void draw_dot(const painter_t *painter, const double win_pos[2],
                     double radius, const double color[4])
{
    painter_t p = *painter;
    vec4_copy(color, p.color);
    p.lines.width = 1;
    p.lines.dash_length = 0;

    // Draw filled circle by drawing multiple concentric circles
    double pos[3] = {win_pos[0], win_pos[1], 0};
    paint_2d_ellipse(&p, NULL, 0, pos, VEC(radius, radius), NULL);
}

/*
 * Draw a time label at the given position.
 */
static void draw_time_label(const painter_t *painter,
                            const double win_pos[2],
                            int hour)
{
    char label[8];

    // Format as hour with 'h' suffix (e.g., "0h", "2h", "14h", "22h")
    snprintf(label, sizeof(label), "%dh", hour);

    painter_t p = *painter;
    vec4_copy(COLOR_TIME_LABEL, p.color);

    // Offset the label slightly from the dot
    double label_pos[2] = {win_pos[0], win_pos[1] - 12};

    paint_text(&p, label, label_pos, NULL,
               ALIGN_CENTER | ALIGN_BOTTOM, TEXT_SMALL_CAP,
               FONT_SIZE_BASE - 4, 0);
}

/*
 * Render the star tracking path.
 */
static int star_track_render(obj_t *obj, const painter_t *painter_)
{
    star_track_t *track = (void*)obj;
    obj_t *selection = core->selection;
    painter_t painter = *painter_;
    int i;
    double p1_view[3], p2_view[3];
    double p1_win[3], p2_win[3];
    double current_win[3];

    if (!track->visible) return 0;
    if (!selection) return 0;

    // Update the path cache
    update_path_cache(track, selection, painter.obs);

    if (track->cache.nb_points < 2) return 0;

    // Render the path as dotted line segments
    painter.lines.width = 1.5;
    painter.lines.dash_length = 4;
    painter.lines.dash_ratio = 0.5;

    for (i = 0; i < track->cache.nb_points; i++) {
        int next = (i + 1) % track->cache.nb_points;
        double az1 = track->cache.path_azalt[i][0];
        double alt1 = track->cache.path_azalt[i][1];
        double az2 = track->cache.path_azalt[next][0];
        double alt2 = track->cache.path_azalt[next][1];

        // Convert azalt to view frame
        azalt_to_view(painter.obs, painter.proj, az1, alt1, p1_view);
        azalt_to_view(painter.obs, painter.proj, az2, alt2, p2_view);

        // Project to screen
        if (!project_to_win(painter.proj, p1_view, p1_win)) continue;
        if (!project_to_win(painter.proj, p2_view, p2_win)) continue;

        // Check if segment wraps around screen (skip if too far apart)
        double dx = p2_win[0] - p1_win[0];
        double dy = p2_win[1] - p1_win[1];
        if (dx * dx + dy * dy > core->win_size[0] * core->win_size[0] / 4) {
            continue;
        }

        // Set color based on whether segment is above or below horizon
        bool above = (alt1 > 0 || alt2 > 0);
        if (above) {
            vec4_copy(COLOR_PATH_ABOVE, painter.color);
        } else {
            vec4_copy(COLOR_PATH_BELOW, painter.color);
        }

        // Draw dotted line segment
        paint_2d_line(&painter, NULL,
                      (double[]){p1_win[0], p1_win[1]},
                      (double[]){p2_win[0], p2_win[1]});
    }

    // Render dots and time labels at hourly intervals
    for (i = 0; i < track->cache.nb_points; i++) {
        double hour = track->cache.hours[i];
        double az = track->cache.path_azalt[i][0];
        double alt = track->cache.path_azalt[i][1];
        double pos_view[3];
        double win_pos[3];

        // Check if this is close to an hour mark
        double hour_frac = hour - floor(hour);
        bool is_hour = (hour_frac < 0.1 || hour_frac > 0.9);

        if (!is_hour) continue;

        azalt_to_view(painter.obs, painter.proj, az, alt, pos_view);
        if (!project_to_win(painter.proj, pos_view, win_pos)) continue;

        // Skip if off screen
        if (win_pos[0] < 0 || win_pos[0] > core->win_size[0] ||
            win_pos[1] < 0 || win_pos[1] > core->win_size[1]) {
            continue;
        }

        // Choose color based on altitude
        const double *dot_color = (alt > 0) ? COLOR_DOT : COLOR_PATH_BELOW;

        // Draw small dot at each hour
        draw_dot(&painter, win_pos, 3, dot_color);

        // Draw time label at even hours (00:00, 02:00, 04:00, etc.)
        int rounded_hour = (int)(hour + 0.5) % 24;
        if (rounded_hour % 2 == 0) {
            draw_time_label(&painter, win_pos, rounded_hour);
        }
    }

    // Draw a marker at the current position of the star
    {
        double pvo[2][4], current_view[3];

        obj_get_pvo(selection, painter.obs, pvo);
        vec3_normalize(pvo[0], pvo[0]);
        convert_frame(painter.obs, FRAME_ICRF, FRAME_VIEW, true, pvo[0], current_view);

        if (project_to_win(painter.proj, current_view, current_win)) {
            // Draw a small white filled dot at current position
            draw_dot(&painter, current_win, 4, COLOR_CURRENT);

            // Draw a slightly larger ring around it
            painter_t ring_painter = painter;
            vec4_copy(COLOR_CURRENT, ring_painter.color);
            ring_painter.lines.width = 1.5;
            ring_painter.lines.dash_length = 0;
            paint_2d_ellipse(&ring_painter, NULL, 0, current_win, VEC(7, 7), NULL);
        }
    }

    return 0;
}

/*
 * Meta class declarations.
 */

static obj_klass_t star_track_klass = {
    .id = "star_track",
    .size = sizeof(star_track_t),
    .flags = OBJ_IN_JSON_TREE | OBJ_MODULE,
    .init = star_track_init,
    .del = star_track_del,
    .render = star_track_render,
    .render_order = 45,  // After stars but before pointer
    .attributes = (attribute_t[]) {
        PROPERTY(visible, TYPE_BOOL, MEMBER(star_track_t, visible)),
        {}
    },
};

OBJ_REGISTER(star_track_klass)
