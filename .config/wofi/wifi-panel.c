#include <gtk/gtk.h>
#include <stdio.h>
#include <stdlib.h>

/* Stable GTK layer-shell ABI, supplied by the installed runtime library. */
void gtk_layer_init_for_window(GtkWindow *);
void gtk_layer_set_layer(GtkWindow *, int);
void gtk_layer_set_anchor(GtkWindow *, int, gboolean);
void gtk_layer_set_margin(GtkWindow *, int, int);
void gtk_layer_set_keyboard_mode(GtkWindow *, int);
void gtk_layer_set_namespace(GtkWindow *, const char *);

static void free_action(gpointer data, GClosure *closure) {
    (void)closure; g_free(data);
}
static void selected(GtkButton *button, gpointer data) {
    (void)button;
    printf("%s\n", (char *)data);
    fflush(stdout);
    gtk_main_quit();
}
static void submit_password(GtkWidget *widget, gpointer data) {
    (void)widget;
    const char *password = gtk_entry_get_text(GTK_ENTRY(data));
    if (!*password) return;
    printf("%s\n", password);
    fflush(stdout);
    gtk_main_quit();
}
static gboolean key(GtkWidget *widget, GdkEventKey *event, gpointer data) {
    (void)widget; (void)data;
    if (event->keyval == GDK_KEY_Escape) gtk_main_quit();
    return FALSE;
}
static gboolean dismiss(GtkWidget *widget, GdkEvent *event, gpointer data) {
    (void)widget; (void)event; (void)data;
    gtk_main_quit();
    return TRUE;
}
static GtkWidget *panel_window, *panel_scroll;
static GtkWidget *panel_icon(const char *name, int size) {
    const char *asset = NULL;
    const char *directory = "waybar/icons";
    if (g_str_equal(name, "network-wireless-symbolic")) asset = "wifi";
    else if (g_str_equal(name, "bluetooth-symbolic")) asset = "bluetooth";
    else {
        directory = "wofi/icons";
        if (g_str_equal(name, "system-lock-screen-symbolic")) asset = "lock";
        else if (g_str_equal(name, "weather-clear-night-symbolic")) asset = "suspend";
        else if (g_str_equal(name, "system-log-out-symbolic")) asset = "logout";
        else if (g_str_equal(name, "system-reboot-symbolic")) asset = "reboot";
        else if (g_str_equal(name, "system-shutdown-symbolic")) asset = "power";
    }
    if (!asset) return gtk_image_new_from_icon_name(name, GTK_ICON_SIZE_BUTTON);
    gchar *file = g_strdup_printf("%s/%s/%s.svg", g_get_user_config_dir(), directory, asset);
    GdkPixbuf *pixbuf = gdk_pixbuf_new_from_file_at_scale(file, size * 2, size * 2, TRUE, NULL);
    g_free(file);
    if (!pixbuf) return gtk_image_new_from_icon_name(name, GTK_ICON_SIZE_BUTTON);
    cairo_surface_t *surface = gdk_cairo_surface_create_from_pixbuf(pixbuf, 2, NULL);
    GtkWidget *image = gtk_image_new_from_surface(surface);
    cairo_surface_destroy(surface);
    g_object_unref(pixbuf);
    return image;
}
static void update_card_state(GtkWidget *card, const char *detail) {
    GtkStyleContext *style = gtk_widget_get_style_context(card);
    if (detail && g_str_has_prefix(detail, "Connected"))
        gtk_style_context_add_class(style, "connected");
    else gtk_style_context_remove_class(style, "connected");
}
static void populate(GtkWidget *list, FILE *input);
static gint64 animation_start;
static gboolean entrance(GtkWidget *widget, GdkFrameClock *clock, gpointer unused) {
    (void)unused;
    gint64 now = gdk_frame_clock_get_frame_time(clock);
    if (!animation_start) animation_start = now;
    double t = MIN(1.0, (now - animation_start) / 100000.0);
    double eased = 1.0 - (1.0-t)*(1.0-t)*(1.0-t);
    gtk_layer_set_margin(GTK_WINDOW(widget), 1, -16 + (int)(6 * eased + 0.5));
    return t < 1.0;
}
static GtkWidget *network_list;
static const char *radio_icon = "network-wireless-symbolic";
static gboolean power_mode;
static char *backend, *device, *last_rows;
static gboolean refresh_pending, wifi_mode;
static GtkWidget *refresh_button;
static void rows_ready(GObject *source, GAsyncResult *result, gpointer unused) {
    (void)unused;
    gchar *output = NULL;
    GError *error = NULL;
    gboolean ok = g_subprocess_communicate_utf8_finish(G_SUBPROCESS(source), result,
                                                       &output, NULL, &error);
    refresh_pending = FALSE;
    if (refresh_button) {
        gtk_button_set_label(GTK_BUTTON(refresh_button), "Refresh");
        gtk_widget_set_sensitive(refresh_button, TRUE);
        gtk_widget_set_tooltip_text(refresh_button,
            ok && g_subprocess_get_successful(G_SUBPROCESS(source)) ? NULL : "Scan failed. Try Refresh again.");
    }
    if (ok && g_subprocess_get_successful(G_SUBPROCESS(source)) &&
        g_strcmp0(output, last_rows) != 0) {
        FILE *input = fmemopen(output, strlen(output), "r");
        if (input) { populate(network_list, input); fclose(input); }
        gtk_widget_show_all(network_list);
        if (panel_window) gtk_window_resize(GTK_WINDOW(panel_window), 400, 1);
        g_free(last_rows);
        last_rows = g_strdup(output);
    }
    g_clear_error(&error);
    g_free(output);
    g_object_unref(source);
}
static void start_refresh(gboolean scan) {
    if (refresh_pending) return;
    GError *error = NULL;
    GSubprocess *process = g_subprocess_new(
        G_SUBPROCESS_FLAGS_STDOUT_PIPE | G_SUBPROCESS_FLAGS_STDERR_SILENCE,
        &error, "/bin/bash", backend, scan ? "--panel-refresh" : "--panel-rows", device, NULL);
    if (!process) { g_clear_error(&error); return; }
    refresh_pending = TRUE;
    if (scan) {
        gtk_button_set_label(GTK_BUTTON(refresh_button), "Scanning…");
        gtk_widget_set_sensitive(refresh_button, FALSE);
    }
    g_subprocess_communicate_utf8_async(process, NULL, NULL, rows_ready, NULL);
}
static gboolean refresh_rows(gpointer unused) {
    (void)unused;
    start_refresh(FALSE);
    return G_SOURCE_CONTINUE;
}
static void scan_clicked(GtkButton *button, gpointer unused) {
    (void)button; (void)unused;
    start_refresh(TRUE);
}

int main(int argc, char **argv) {
    gtk_init(&argc, &argv);
    gboolean password_mode = argc >= 4 && g_str_equal(argv[2], "--password");
    power_mode = argc >= 3 && g_str_equal(argv[2], "--power");
    gboolean bluetooth = argc >= 5 && g_str_equal(argv[4], "Bluetooth");
    wifi_mode = argc >= 4 && !password_mode && !power_mode && !bluetooth;
    if (bluetooth) radio_icon = "bluetooth-symbolic";
    GtkWidget *window = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    panel_window = window;
    gtk_widget_set_name(window, "wifi-panel");
    GdkVisual *panel_visual = gdk_screen_get_rgba_visual(gtk_widget_get_screen(window));
    if (panel_visual) gtk_widget_set_visual(window, panel_visual);
    gtk_container_set_border_width(GTK_CONTAINER(window), 18);
    gtk_window_set_default_size(GTK_WINDOW(window), 400, -1);
    gtk_widget_set_size_request(window, 400, -1);
    gtk_layer_init_for_window(GTK_WINDOW(window));
    gtk_layer_set_namespace(GTK_WINDOW(window), power_mode ? "power-panel" : bluetooth ? "bluetooth-panel" : "wifi-panel");
    gtk_layer_set_layer(GTK_WINDOW(window), 2);
    gtk_layer_set_anchor(GTK_WINDOW(window), 1, TRUE);
    gtk_layer_set_anchor(GTK_WINDOW(window), 2, TRUE);
    gtk_layer_set_margin(GTK_WINDOW(window), 1, -10);
    gtk_layer_set_margin(GTK_WINDOW(window), 2, -14);
    gtk_layer_set_keyboard_mode(GTK_WINDOW(window), 2);
    GtkCssProvider *css = gtk_css_provider_new();
    GError *error = NULL;
    if (argc < 2 || !gtk_css_provider_load_from_path(css, argv[1], &error)) {
        fprintf(stderr, "Wi-Fi CSS: %s\n", error ? error->message : "missing path");
        return 1;
    }
    gtk_style_context_add_provider_for_screen(gdk_screen_get_default(),
        GTK_STYLE_PROVIDER(css), GTK_STYLE_PROVIDER_PRIORITY_USER);
    /* A transparent input surface catches clicks even on empty desktop space. */
    GtkWidget *backdrop = gtk_window_new(GTK_WINDOW_TOPLEVEL);
    gtk_widget_set_name(backdrop, "wifi-backdrop");
    GdkVisual *visual = gdk_screen_get_rgba_visual(gtk_widget_get_screen(backdrop));
    if (visual) gtk_widget_set_visual(backdrop, visual);
    gtk_layer_init_for_window(GTK_WINDOW(backdrop));
    gtk_layer_set_namespace(GTK_WINDOW(backdrop), power_mode ? "power-panel-backdrop" : bluetooth ? "bluetooth-panel-backdrop" : "wifi-panel-backdrop");
    gtk_layer_set_layer(GTK_WINDOW(backdrop), 2);
    for (int edge = 0; edge < 4; edge++) gtk_layer_set_anchor(GTK_WINDOW(backdrop), edge, TRUE);
    gtk_layer_set_keyboard_mode(GTK_WINDOW(backdrop), 0);
    gtk_widget_add_events(backdrop, GDK_BUTTON_PRESS_MASK);
    g_signal_connect(backdrop, "button-press-event", G_CALLBACK(dismiss), NULL);
    GtkWidget *box = gtk_box_new(GTK_ORIENTATION_VERTICAL, 0);
    gtk_container_set_border_width(GTK_CONTAINER(box), 0);
    gtk_widget_set_name(box, "panel-surface");
    gtk_container_add(GTK_CONTAINER(window), box);
    GtkWidget *header = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
    gtk_widget_set_name(header, "header");
    GtkWidget *title = gtk_label_new(power_mode ? "Power" : password_mode ? "Wi-Fi password" : bluetooth ? "Bluetooth" : "Wi-Fi");
    gtk_widget_set_name(title, "title");
    gtk_box_pack_start(GTK_BOX(header), title, FALSE, FALSE, 0);
    if (password_mode) {
        gtk_box_pack_start(GTK_BOX(box), header, FALSE, FALSE, 0);
        GtkWidget *network = gtk_label_new(argv[3]);
        gtk_label_set_xalign(GTK_LABEL(network), 0);
        gtk_label_set_ellipsize(GTK_LABEL(network), PANGO_ELLIPSIZE_END);
        gtk_style_context_add_class(gtk_widget_get_style_context(network), "detail");
        gtk_box_pack_start(GTK_BOX(box), network, FALSE, FALSE, 6);
        GtkWidget *entry = gtk_entry_new();
        gtk_entry_set_visibility(GTK_ENTRY(entry), FALSE);
        gtk_entry_set_input_purpose(GTK_ENTRY(entry), GTK_INPUT_PURPOSE_PASSWORD);
        gtk_entry_set_placeholder_text(GTK_ENTRY(entry), "Enter network password");
        gtk_box_pack_start(GTK_BOX(box), entry, FALSE, FALSE, 6);
        GtkWidget *actions = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 8);
        GtkWidget *cancel = gtk_button_new_with_label("Cancel");
        GtkWidget *connect = gtk_button_new_with_label("Connect");
        g_signal_connect(cancel, "clicked", G_CALLBACK(selected), "");
        g_signal_connect(connect, "clicked", G_CALLBACK(submit_password), entry);
        g_signal_connect(entry, "activate", G_CALLBACK(submit_password), entry);
        gtk_box_pack_end(GTK_BOX(actions), connect, FALSE, FALSE, 0);
        gtk_box_pack_end(GTK_BOX(actions), cancel, FALSE, FALSE, 0);
        gtk_box_pack_start(GTK_BOX(box), actions, FALSE, FALSE, 6);
        gtk_widget_grab_focus(entry);
    } else {
    if (!power_mode) {
    GtkWidget *toggle = gtk_button_new();
    gtk_container_add(GTK_CONTAINER(toggle), panel_icon(radio_icon, 16));
    gtk_style_context_add_class(gtk_widget_get_style_context(toggle), "radio-toggle");
    gtk_widget_set_tooltip_text(toggle, bluetooth ? "Toggle Bluetooth" : "Toggle Wi-Fi");
    g_signal_connect(toggle, "clicked", G_CALLBACK(selected), "toggle");
    gtk_box_pack_start(GTK_BOX(header), toggle, FALSE, FALSE, 0);
    GtkWidget *refresh = gtk_button_new_with_label("Refresh");
    if (wifi_mode) {
        refresh_button = refresh;
        g_signal_connect(refresh, "clicked", G_CALLBACK(scan_clicked), NULL);
    } else {
        g_signal_connect(refresh, "clicked", G_CALLBACK(selected), "refresh");
    }
    gtk_box_pack_end(GTK_BOX(header), refresh, FALSE, FALSE, 0);
    }
    gtk_box_pack_start(GTK_BOX(box), header, FALSE, FALSE, 0);
    GtkWidget *scroll = gtk_scrolled_window_new(NULL, NULL);
    panel_scroll = scroll;
    gtk_scrolled_window_set_policy(GTK_SCROLLED_WINDOW(scroll), GTK_POLICY_NEVER, GTK_POLICY_AUTOMATIC);
    gtk_scrolled_window_set_propagate_natural_height(GTK_SCROLLED_WINDOW(scroll), TRUE);
    gtk_scrolled_window_set_min_content_height(GTK_SCROLLED_WINDOW(scroll), 64);
    gtk_scrolled_window_set_max_content_height(GTK_SCROLLED_WINDOW(scroll), 440);
    gtk_box_pack_start(GTK_BOX(box), scroll, TRUE, TRUE, 0);
    GtkWidget *list = gtk_box_new(GTK_ORIENTATION_VERTICAL, 7);
    gtk_container_add(GTK_CONTAINER(scroll), list);
    populate(list, stdin);
    if (argc >= 4 && !power_mode) {
        network_list = list; backend = argv[2]; device = argv[3];
        g_timeout_add(wifi_mode ? 5000 : 1500, refresh_rows, NULL);
    }
    }
    g_signal_connect(window, "destroy", G_CALLBACK(gtk_main_quit), NULL);
    g_signal_connect(window, "key-press-event", G_CALLBACK(key), NULL);
    g_signal_connect(window, "focus-out-event", G_CALLBACK(dismiss), NULL);
    gtk_widget_show_all(backdrop);
    gtk_widget_show_all(window);
    gtk_widget_add_tick_callback(window, entrance, NULL, NULL);
    gtk_main();
    return 0;
}
static void populate(GtkWidget *list, FILE *input) {
    GHashTable *cards = g_object_get_data(G_OBJECT(list), "cards");
    if (!cards) {
        cards = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, NULL);
        g_object_set_data_full(G_OBJECT(list), "cards", cards, (GDestroyNotify)g_hash_table_unref);
    }
    GHashTable *seen = g_hash_table_new_full(g_str_hash, g_str_equal, g_free, NULL);
    char *line = NULL; size_t capacity = 0; int index = 0;
    while (getline(&line, &capacity, input) >= 0) {
        g_strchomp(line);
        if (!*line) continue;
        gchar **parts = g_strsplit(line, "\t", 4);
        guint count = g_strv_length(parts);
        gchar *row_id = count >= 3 ? g_strdup(parts[2]) : g_strdup_printf("%d", index++);
        g_hash_table_add(seen, g_strdup(row_id));
        GtkWidget *existing = g_hash_table_lookup(cards, row_id);
        if (existing) {
            gtk_label_set_text(GTK_LABEL(g_object_get_data(G_OBJECT(existing), "name")), parts[0]);
            gtk_label_set_text(GTK_LABEL(g_object_get_data(G_OBJECT(existing), "detail")), count >= 2 ? parts[1] : "");
            update_card_state(existing, count >= 2 ? parts[1] : "");
            GtkWidget *forget = g_object_get_data(G_OBJECT(existing), "forget");
            gtk_widget_set_visible(forget, count >= 4 && g_str_equal(parts[3], "saved"));
            g_free(row_id);
            g_strfreev(parts);
            continue;
        }
        GtkWidget *card = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 0);
        gtk_style_context_add_class(gtk_widget_get_style_context(card), "network-card");
        update_card_state(card, count >= 2 ? parts[1] : "");
        if (power_mode && g_str_equal(row_id, "shutdown"))
            gtk_style_context_add_class(gtk_widget_get_style_context(card), "destructive");
        GtkWidget *button = gtk_button_new();
        gtk_style_context_add_class(gtk_widget_get_style_context(button), "network-connect");
        GtkWidget *row = gtk_box_new(GTK_ORIENTATION_HORIZONTAL, 12);
        const char *icon_name = power_mode && g_strv_length(parts) >= 4 ? parts[3] : radio_icon;
        GtkWidget *icon = panel_icon(icon_name, 20);
        gtk_box_pack_start(GTK_BOX(row), icon, FALSE, FALSE, 0);
        GtkWidget *labels = gtk_box_new(GTK_ORIENTATION_VERTICAL, 2);
        GtkWidget *name = gtk_label_new(parts[0]);
        gtk_label_set_xalign(GTK_LABEL(name), 0);
        gtk_label_set_ellipsize(GTK_LABEL(name), PANGO_ELLIPSIZE_END);
        gtk_label_set_max_width_chars(GTK_LABEL(name), 27);
        gtk_style_context_add_class(gtk_widget_get_style_context(name), "network-name");
        gtk_box_pack_start(GTK_BOX(labels), name, FALSE, FALSE, 0);
        g_object_set_data(G_OBJECT(card), "name", name);
        {
            GtkWidget *detail = gtk_label_new(count >= 2 ? parts[1] : "");
            g_object_set_data(G_OBJECT(card), "detail", detail);
            gtk_label_set_xalign(GTK_LABEL(detail), 0);
            gtk_label_set_ellipsize(GTK_LABEL(detail), PANGO_ELLIPSIZE_END);
            gtk_label_set_max_width_chars(GTK_LABEL(detail), 32);
            gtk_style_context_add_class(gtk_widget_get_style_context(detail), "detail");
            gtk_box_pack_start(GTK_BOX(labels), detail, FALSE, FALSE, 0);
        }
        gtk_box_pack_start(GTK_BOX(row), labels, TRUE, TRUE, 0);
        gtk_container_add(GTK_CONTAINER(button), row);
        g_hash_table_insert(cards, row_id, card);
        char *id = g_strdup(row_id);
        g_signal_connect_data(button, "clicked", G_CALLBACK(selected), id,
                              free_action, 0);
        gtk_box_pack_start(GTK_BOX(card), button, TRUE, TRUE, 0);
        {
            GtkWidget *forget = gtk_button_new_with_label("Forget");
            gtk_style_context_add_class(gtk_widget_get_style_context(forget), "forget-button");
            char *forget_id = g_strdup_printf("forget:%s", row_id);
            g_signal_connect_data(forget, "clicked", G_CALLBACK(selected), forget_id,
                                  free_action, 0);
            g_object_set_data(G_OBJECT(card), "forget", forget);
            gtk_widget_set_no_show_all(forget, TRUE);
            gtk_widget_set_visible(forget, count >= 4 && g_str_equal(parts[3], "saved"));
            gtk_widget_set_valign(forget, GTK_ALIGN_CENTER);
            gtk_widget_set_tooltip_text(forget, "Forget saved network");
            gtk_box_pack_end(GTK_BOX(card), forget, FALSE, FALSE, 0);
        }
        gtk_box_pack_start(GTK_BOX(list), card, FALSE, FALSE, 0);
        g_strfreev(parts);
    }
    free(line);
    GHashTableIter iter;
    gpointer id, card;
    g_hash_table_iter_init(&iter, cards);
    while (g_hash_table_iter_next(&iter, &id, &card)) {
        if (!g_hash_table_contains(seen, id)) {
            gtk_widget_destroy(GTK_WIDGET(card));
            g_hash_table_iter_remove(&iter);
        }
    }
    g_hash_table_unref(seen);
    if (panel_scroll) {
        gint natural = 0;
        gtk_widget_show_all(list);
        gtk_widget_get_preferred_height(list, NULL, &natural);
        gtk_scrolled_window_set_min_content_height(GTK_SCROLLED_WINDOW(panel_scroll), CLAMP(natural, 64, 440));
    }
}
